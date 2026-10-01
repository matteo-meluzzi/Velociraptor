import Combine
import Foundation
import Testing
@testable import Velociraptor

@MainActor
final class Clock {
    var now = Date(timeIntervalSince1970: 0)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
struct HeartRateViewModelTests {
    let service = MockHeartRateService()
    let clock = Clock()
    let ticks = PassthroughSubject<Date, Never>()
    let monitorID = UUID()
    let otherID = UUID()
    let viewModel: HeartRateViewModel

    init() {
        let clock = clock
        viewModel = HeartRateViewModel(service: service, now: { clock.now }, ticks: ticks.eraseToAnyPublisher())
    }

    private var connectedState: MonitorConnectionState { .connected(monitorID: monitorID, name: "Polar H10") }

    private func measurement(_ bpm: Int, contact: SensorContact = .detected) -> HeartRateMeasurement {
        HeartRateMeasurement(bpm: bpm, contact: contact)
    }

    private func monitor(_ name: String = "Polar H10") -> DiscoveredMonitor {
        DiscoveredMonitor(id: monitorID, name: name, rssi: -50, lastSeen: clock.now)
    }

    // MARK: Monitor states

    @Test func noneHidesHeartRate() {
        #expect(viewModel.heartRateText == nil)
        #expect(!viewModel.showsUnit)
        #expect(viewModel.buttonTitle == "Connect heart rate monitor")
    }

    @Test func connectingShowsConnecting() {
        service.send(state: .connecting(monitorID: monitorID, name: "Polar H10", origin: .user))
        #expect(viewModel.heartRateText == "Connecting…")
        #expect(!viewModel.showsUnit)
        #expect(viewModel.buttonTitle == "Change heart rate monitor")
    }

    @Test func connectedWithoutReadingShowsDash() {
        service.send(state: connectedState)
        #expect(viewModel.heartRateText == "–")
        #expect(viewModel.showsUnit)
    }

    @Test func connectedValidReadingShowsValue() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        #expect(viewModel.heartRateText == "72")
        #expect(viewModel.showsUnit)
    }

    @Test func readingUpdates() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        service.send(measurement: measurement(75))
        #expect(viewModel.heartRateText == "75")
    }

    @Test func bpmExposedOnlyForCurrentReading() {
        #expect(viewModel.heartRateBPM == nil)
        service.send(state: connectedState)
        #expect(viewModel.heartRateBPM == nil)
        service.send(measurement: measurement(106))
        #expect(viewModel.heartRateBPM == 106)
        clock.advance(6)
        ticks.send(clock.now)
        #expect(viewModel.heartRateBPM == nil)
        service.send(measurement: measurement(110))
        service.send(state: .lost(monitorID: monitorID, name: "Polar H10"))
        #expect(viewModel.heartRateBPM == nil)
    }

    @Test func lostShowsDash() {
        service.send(state: .lost(monitorID: monitorID, name: "Polar H10"))
        #expect(viewModel.heartRateText == "–")
        #expect(viewModel.showsUnit)
        #expect(viewModel.buttonTitle == "Change heart rate monitor")
    }

    // MARK: Reading validity

    @Test func zeroBpmShowsDashImmediately() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        service.send(measurement: measurement(0, contact: .notSupported))
        #expect(viewModel.heartRateText == "–")
    }

    @Test func lostContactShowsDashImmediately() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        service.send(measurement: measurement(80, contact: .notDetected))
        #expect(viewModel.heartRateText == "–")
    }

    @Test func invalidMeasurementClearsPreviousReading() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        service.send(measurement: measurement(0, contact: .notSupported))
        #expect(viewModel.heartRateText == "–")
        viewModel.refresh()
        #expect(viewModel.heartRateText == "–")
    }

    @Test func readingGoesStaleAfterFiveSeconds() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        clock.advance(5)
        viewModel.refresh()
        #expect(viewModel.heartRateText == "72")
        clock.advance(0.1)
        viewModel.refresh()
        #expect(viewModel.heartRateText == "–")
    }

    @Test func tickTriggersRefresh() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        clock.advance(6)
        ticks.send(clock.now)
        #expect(viewModel.heartRateText == "–")
    }

    @Test func readingClearedWhenLeavingConnected() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        service.send(state: .lost(monitorID: monitorID, name: "Polar H10"))
        service.send(state: .connected(monitorID: otherID, name: "Other"))
        #expect(viewModel.heartRateText == "–")
    }

    @Test func measurementsIgnoredWhileNotConnected() {
        service.send(measurement: measurement(72))
        service.send(state: connectedState)
        #expect(viewModel.heartRateText == "–")
    }

    // MARK: Picker

    @Test func buttonTapPresentsPickerAndStartsScanning() {
        viewModel.connectButtonTapped()
        #expect(viewModel.isPickerPresented)
        #expect(service.startScanningCallCount == 1)
    }

    @Test func dismissStopsScanningAndKeepsState() {
        service.send(state: connectedState)
        service.send(measurement: measurement(72))
        viewModel.connectButtonTapped()
        viewModel.isPickerPresented = false
        viewModel.pickerDismissed()
        #expect(service.stopScanningCallCount == 1)
        #expect(viewModel.heartRateText == "72")
        #expect(viewModel.showsUnit)
    }

    @Test func selectConnectsAndClosesPicker() {
        service.send(availability: .available)
        viewModel.connectButtonTapped()
        viewModel.select(monitor())
        #expect(service.connectedIDs == [monitorID])
        #expect(!viewModel.isPickerPresented)
    }

    @Test func monitorsMirrorService() {
        let list = [monitor("B"), DiscoveredMonitor(id: otherID, name: "A", rssi: -80, lastSeen: clock.now)]
        service.send(monitors: list)
        #expect(viewModel.monitors == list)
    }

    @Test func searchingThenNoneFound() {
        service.send(availability: .available)
        viewModel.connectButtonTapped()
        #expect(viewModel.pickerMessage == .searching)
        clock.advance(5)
        viewModel.refresh()
        #expect(viewModel.pickerMessage == .noneFound)
        service.send(monitors: [monitor()])
        #expect(viewModel.pickerMessage == nil)
    }

    @Test func notDeterminedAndPendingShowSearching() {
        viewModel.connectButtonTapped()
        #expect(viewModel.pickerMessage == .searching)
        service.send(availability: .pending)
        #expect(viewModel.pickerMessage == .searching)
        clock.advance(10)
        viewModel.refresh()
        #expect(viewModel.pickerMessage == .searching)
    }

    @Test func bluetoothOffMessage() {
        viewModel.connectButtonTapped()
        service.send(availability: .poweredOff)
        #expect(viewModel.pickerMessage == .bluetoothOff)
    }

    @Test func bluetoothDeniedMessage() {
        viewModel.connectButtonTapped()
        service.send(availability: .denied)
        #expect(viewModel.pickerMessage == .bluetoothDenied)
    }

    @Test func bluetoothUnsupportedMessage() {
        viewModel.connectButtonTapped()
        service.send(availability: .unsupported)
        #expect(viewModel.pickerMessage == .bluetoothUnsupported)
    }

    @Test func bluetoothTurnedOnWhilePickerOpenShowsSearching() {
        service.send(availability: .poweredOff)
        viewModel.connectButtonTapped()
        clock.advance(20)
        service.send(availability: .available)
        #expect(viewModel.pickerMessage == .searching)
        clock.advance(4.9)
        viewModel.refresh()
        #expect(viewModel.pickerMessage == .searching)
        clock.advance(0.1)
        viewModel.refresh()
        #expect(viewModel.pickerMessage == .noneFound)
    }

    @Test func userConnectFailureShowsAlert() {
        service.sendFailure(name: "Polar H10")
        #expect(viewModel.alertMessage == "Couldn't connect to Polar H10")
    }

    @Test func sceneActiveRequestsReconnect() {
        viewModel.sceneBecameActive()
        #expect(service.reconnectIfNeededCallCount == 1)
    }

    // MARK: Speed independence (US2, FR-006)

    @Test func speedUnaffectedByHeartRateStates() {
        let provider = MockLocationProvider<Double>(initialValue: 0.0)
        let speed = OneValueModel(provider)
        var value = 0.0
        func step() {
            value += 1.5
            provider.send(value: value)
            #expect(speed.displayValue == String(format: "%.1f", value))
        }

        let states: [MonitorConnectionState] = [
            .none,
            .connecting(monitorID: monitorID, name: "M", origin: .user),
            connectedState,
            .lost(monitorID: monitorID, name: "M"),
        ]
        for state in states { service.send(state: state); step() }
        for availability in [BluetoothAvailability.notDetermined, .pending, .available, .poweredOff, .denied, .unsupported] {
            service.send(availability: availability); step()
        }
        service.send(state: connectedState)
        service.send(measurement: measurement(150)); step()
        service.sendFailure(name: "M"); step()
    }
}
