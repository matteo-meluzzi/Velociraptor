import SwiftUI
import CoreLocation
import Combine

struct ContentView : View {
    @ObservedObject var speedViewModel: OneValueModel
    @ObservedObject var locationStatusViewModel: LocationStatusViewModel
    @ObservedObject var heartRateViewModel: HeartRateViewModel

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            HeartRateView(viewModel: heartRateViewModel)
            SpeedView(viewModel: speedViewModel)
                .fixedSize()
                .layoutPriority(1)
            LocationStatusView(viewModel: locationStatusViewModel)
            Spacer()
            Button(heartRateViewModel.buttonTitle) { heartRateViewModel.connectButtonTapped() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("heartRateMonitorButton")
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $heartRateViewModel.isPickerPresented, onDismiss: heartRateViewModel.pickerDismissed) {
            MonitorPickerView(viewModel: heartRateViewModel)
                .presentationDetents([.medium, .large])
        }
        .alert(
            heartRateViewModel.alertMessage ?? "",
            isPresented: Binding(
                get: { heartRateViewModel.alertMessage != nil },
                set: { if !$0 { heartRateViewModel.alertMessage = nil } }
            )
        ) {
            Button("OK") { heartRateViewModel.alertMessage = nil }
        }
    }
}

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: OneValueModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel
    @StateObject private var heartRateViewModel: HeartRateViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _speedViewModel = StateObject(wrappedValue: OneValueModel(LocationPublisher(behavior: MetersPerSecondToKmh(inner: NilToZero(inner: SpeedBehavior())))))
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(AuthorizationStatusPublisher()))
        _heartRateViewModel = StateObject(wrappedValue: HeartRateViewModel(service: BluetoothHeartRateService()))
        
        CLLocationManager().requestWhenInUseAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                speedViewModel: speedViewModel,
                locationStatusViewModel: locationStatusViewModel,
                heartRateViewModel: heartRateViewModel
            )
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { heartRateViewModel.sceneBecameActive() }
            }
        }
    }
}

final class MockLocationProvider<T>: LocationProviding {
    private let valueSubject: CurrentValueSubject<T, Never>

    var publisher: AnyPublisher<T, Never> { valueSubject.eraseToAnyPublisher() }

    init(initialValue: T) {
        valueSubject = CurrentValueSubject(initialValue)
    }

    func send(value: T) { valueSubject.send(value) }
}
final class MockAuthorizationProvider: AuthorizationProviding {
    private let subject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var publisher: AnyPublisher<CLAuthorizationStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(status: CLAuthorizationStatus) {
        subject = CurrentValueSubject(status)
    }

    func send(_ status: CLAuthorizationStatus) { subject.send(status) }
}
final class PreviewHeartRateService: HeartRateMonitorProviding {
    private let availabilitySubject = CurrentValueSubject<BluetoothAvailability, Never>(.available)
    private let stateSubject = CurrentValueSubject<MonitorConnectionState, Never>(.none)
    private let monitorsSubject = CurrentValueSubject<[DiscoveredMonitor], Never>([])
    private let measurementSubject = CurrentValueSubject<HeartRateMeasurement?, Never>(nil)
    private let failureSubject = PassthroughSubject<String, Never>()
    private let id = UUID()

    var availability: AnyPublisher<BluetoothAvailability, Never> { availabilitySubject.eraseToAnyPublisher() }
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { monitorsSubject.eraseToAnyPublisher() }
    /// Replays the last measurement and re-emits it every second, like a live monitor, so the reading never goes stale.
    var measurements: AnyPublisher<HeartRateMeasurement, Never> {
        let repeated = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .compactMap { [weak self] _ in self?.measurementSubject.value }
        return measurementSubject.compactMap { $0 }.merge(with: repeated).eraseToAnyPublisher()
    }
    var connectionFailures: AnyPublisher<String, Never> { failureSubject.eraseToAnyPublisher() }

    func startScanning() {
        monitorsSubject.send([DiscoveredMonitor(id: id, name: "Polar H10", rssi: -50, lastSeen: Date())])
    }
    func stopScanning() {}
    func connect(to monitorID: UUID) { stateSubject.send(.connecting(monitorID: monitorID, name: "Polar H10", origin: .user)) }
    func reconnectIfNeeded() {}

    static func connected(bpm: Int = 142) -> PreviewHeartRateService {
        let service = PreviewHeartRateService()
        service.measurementSubject.send(HeartRateMeasurement(bpm: bpm, contact: .detected))
        service.stateSubject.send(.connected(monitorID: service.id, name: "Polar H10"))
        return service
    }

    /// Shifts the reading by `delta` bpm, connecting first if needed so the reading is shown.
    func changeBPM(by delta: Int) {
        if case .connected = stateSubject.value {} else {
            stateSubject.send(.connected(monitorID: id, name: "Polar H10"))
        }
        let bpm = (measurementSubject.value?.bpm ?? 100) + delta
        measurementSubject.send(HeartRateMeasurement(bpm: bpm, contact: .detected))
    }

    func cycleState() {
        switch stateSubject.value {
        case .none: stateSubject.send(.connecting(monitorID: id, name: "Polar H10", origin: .user))
        case .connecting: stateSubject.send(.connected(monitorID: id, name: "Polar H10"))
            measurementSubject.send(HeartRateMeasurement(bpm: 142, contact: .detected))
        case .connected: stateSubject.send(.lost(monitorID: id, name: "Polar H10"))
        case .lost: stateSubject.send(.none)
        }
    }
}

#Preview {
    let speedModel = MockLocationProvider(initialValue: 0.0)
    var speed = 0.0
    let heartRateService = PreviewHeartRateService()
    VStack {
        ContentView(
            speedViewModel: OneValueModel(speedModel),
            locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)),
            heartRateViewModel: HeartRateViewModel(service: heartRateService)
        )
        
        VStack {
            HStack {
                Button("decelerate") {
                    speed -= 1
                    speedModel.send(value: speed)
                }
                Button("accelerate") {
                    speed += 1
                    speedModel.send(value: speed)
                }
            }
            HStack {
                Button("decrease bpm") { heartRateService.changeBPM(by: -5) }
                Button("increase bpm") { heartRateService.changeBPM(by: 5) }
            }
            Button("cycle heart rate state") { heartRateService.cycleState() }
        }
        .buttonStyle(.bordered)
    }
}

#Preview("Landscape, heart rate shown", traits: .landscapeLeft) {
    let heartRateService = PreviewHeartRateService.connected(bpm: 188)
    ContentView(
        speedViewModel: OneValueModel(MockLocationProvider(initialValue: 188.8)),
        locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)),
        heartRateViewModel: HeartRateViewModel(service: heartRateService)
    )
}
