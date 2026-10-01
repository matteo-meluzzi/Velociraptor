import Combine
import Foundation
@testable import Velociraptor

final class MockHeartRateService: HeartRateMonitorProviding {
    private let availabilitySubject = CurrentValueSubject<BluetoothAvailability, Never>(.notDetermined)
    private let stateSubject = CurrentValueSubject<MonitorConnectionState, Never>(.none)
    private let monitorsSubject = CurrentValueSubject<[DiscoveredMonitor], Never>([])
    private let measurementSubject = PassthroughSubject<HeartRateMeasurement, Never>()
    private let failureSubject = PassthroughSubject<String, Never>()

    var availability: AnyPublisher<BluetoothAvailability, Never> { availabilitySubject.eraseToAnyPublisher() }
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { monitorsSubject.eraseToAnyPublisher() }
    var measurements: AnyPublisher<HeartRateMeasurement, Never> { measurementSubject.eraseToAnyPublisher() }
    var connectionFailures: AnyPublisher<String, Never> { failureSubject.eraseToAnyPublisher() }

    private(set) var startScanningCallCount = 0
    private(set) var stopScanningCallCount = 0
    private(set) var connectedIDs: [UUID] = []
    private(set) var reconnectIfNeededCallCount = 0

    func startScanning() { startScanningCallCount += 1 }
    func stopScanning() { stopScanningCallCount += 1 }
    func connect(to monitorID: UUID) { connectedIDs.append(monitorID) }
    func reconnectIfNeeded() { reconnectIfNeededCallCount += 1 }

    func send(availability: BluetoothAvailability) { availabilitySubject.send(availability) }
    func send(state: MonitorConnectionState) { stateSubject.send(state) }
    func send(monitors: [DiscoveredMonitor]) { monitorsSubject.send(monitors) }
    func send(measurement: HeartRateMeasurement) { measurementSubject.send(measurement) }
    func sendFailure(name: String) { failureSubject.send(name) }
}

final class InMemoryLastMonitorStore: LastMonitorStoring {
    var lastMonitorID: UUID?
    var lastMonitorName: String?
}
