import Combine
import CoreBluetooth
import Foundation

protocol TimeoutScheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> AnyCancellable
}

struct MainQueueScheduler: TimeoutScheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> AnyCancellable {
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
        return AnyCancellable { item.cancel() }
    }
}

/// Thin CoreBluetooth adapter: maps callbacks to `ConnectionEvent`s and runs the
/// `ConnectionEffect`s produced by `HeartRateConnectionMachine`.
final class BluetoothHeartRateService: NSObject, HeartRateMonitorProviding, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let serviceUUID = CBUUID(string: "180D")
    private static let characteristicUUID = CBUUID(string: "2A37")
    private static let pruneInterval: TimeInterval = 1

    private let store: LastMonitorStoring
    private let scheduler: TimeoutScheduling

    private var machine = HeartRateConnectionMachine()
    private let availabilitySubject = CurrentValueSubject<BluetoothAvailability, Never>(.notDetermined)
    private let stateSubject = CurrentValueSubject<MonitorConnectionState, Never>(.none)
    private let discoveredSubject = CurrentValueSubject<[DiscoveredMonitor], Never>([])
    private let measurementSubject = PassthroughSubject<HeartRateMeasurement, Never>()
    private let failureSubject = PassthroughSubject<String, Never>()

    private var central: CBCentralManager?
    private var targetPeripheral: CBPeripheral?
    /// Set when we cancel a connected peripheral, so the echoing `didDisconnect` is not mistaken for a failure.
    private var ignoreDisconnectFor: UUID?
    private var seen: [UUID: DiscoveredMonitor] = [:]
    private var wantsScan = false
    private var timeout: AnyCancellable?
    private var pruneTick: AnyCancellable?

    var availability: AnyPublisher<BluetoothAvailability, Never> { availabilitySubject.eraseToAnyPublisher() }
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { discoveredSubject.eraseToAnyPublisher() }
    var measurements: AnyPublisher<HeartRateMeasurement, Never> { measurementSubject.eraseToAnyPublisher() }
    var connectionFailures: AnyPublisher<String, Never> { failureSubject.eraseToAnyPublisher() }

    init(store: LastMonitorStoring = UserDefaultsLastMonitorStore(), scheduler: TimeoutScheduling = MainQueueScheduler()) {
        self.store = store
        self.scheduler = scheduler
        super.init()
        if CBManager.authorization == .allowedAlways {
            createCentralIfNeeded()
        }
        send(.launch(storedID: store.lastMonitorID, storedName: store.lastMonitorName))
    }

    // MARK: - Commands

    func startScanning() {
        wantsScan = true
        createCentralIfNeeded()
        startScanIfPossible()
    }

    func stopScanning() {
        wantsScan = false
        if central?.state == .poweredOn { central?.stopScan() }
        pruneTick = nil
        seen = [:]
        publishDiscovered()
    }

    func connect(to monitorID: UUID) {
        let current = stateSubject.value
        let knownName = current.monitorID == monitorID ? current.name : nil
        let name = seen[monitorID]?.name ?? knownName ?? DiscoveredMonitor.unnamedName
        send(.userSelected(id: monitorID, name: name))
    }

    func reconnectIfNeeded() {
        send(.sceneActive)
    }

    func disconnect() {
        send(.userDisconnected)
    }

    // MARK: - Machine plumbing

    private func createCentralIfNeeded() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    private func send(_ event: ConnectionEvent) {
        let effects = machine.handle(event)
        if stateSubject.value != machine.state { stateSubject.send(machine.state) }
        if availabilitySubject.value != machine.availability { availabilitySubject.send(machine.availability) }
        effects.forEach(run)
        publishDiscovered()
    }

    private func run(_ effect: ConnectionEffect) {
        switch effect {
        case .retrieveAndConnect(let id):
            retrieveAndConnect(id)
        case .connect(let id):
            if let target = targetPeripheral, target.identifier == id {
                central?.connect(target)
            } else {
                retrieveAndConnect(id)
            }
        case .cancel(let id):
            if let target = targetPeripheral, target.identifier == id {
                if target.state == .connected { ignoreDisconnectFor = id }
                central?.cancelPeripheralConnection(target)
                targetPeripheral = nil
            }
        case .startTimeout(let id):
            timeout = scheduler.schedule(after: HeartRateConnectionMachine.connectTimeout) { [weak self] in
                self?.send(.timeoutFired(id: id))
            }
        case .cancelTimeout:
            timeout = nil
        case .saveLastMonitor(let id, let name):
            store.lastMonitorID = id
            store.lastMonitorName = name
        case .forgetLastMonitor:
            store.lastMonitorID = nil
            store.lastMonitorName = nil
        case .emitFailure(let name):
            failureSubject.send(name)
        }
    }

    private func retrieveAndConnect(_ id: UUID) {
        guard let central, let peripheral = central.retrievePeripherals(withIdentifiers: [id]).first else {
            // Deferred so the failure never nests inside the effect loop that requested the retrieve.
            DispatchQueue.main.async { [weak self] in self?.send(.didFail(id: id)) }
            return
        }
        targetPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    private func isTarget(_ peripheral: CBPeripheral) -> Bool {
        targetPeripheral?.identifier == peripheral.identifier
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let newAvailability: BluetoothAvailability
        switch central.state {
        case .poweredOn: newAvailability = .available
        case .poweredOff: newAvailability = .poweredOff
        case .unauthorized: newAvailability = .denied
        case .unsupported: newAvailability = .unsupported
        case .unknown, .resetting: newAvailability = .pending
        @unknown default: newAvailability = .pending
        }
        if newAvailability != .available {
            targetPeripheral = nil
            ignoreDisconnectFor = nil
            seen = [:]
            pruneTick = nil
        }
        send(.availabilityChanged(newAvailability))
        if newAvailability == .available { startScanIfPossible() }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard isTarget(peripheral) else { return }
        send(.didConnect(id: peripheral.identifier))
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard isTarget(peripheral) else { return }
        send(.didFail(id: peripheral.identifier))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if ignoreDisconnectFor == peripheral.identifier {
            ignoreDisconnectFor = nil
            return
        }
        guard isTarget(peripheral) else { return }
        send(.didDisconnect(id: peripheral.identifier))
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = DiscoveredMonitor.displayName(
            advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            peripheralName: peripheral.name
        )
        seen[peripheral.identifier] = DiscoveredMonitor(id: peripheral.identifier, name: name, rssi: RSSI.intValue, lastSeen: Date())
        publishDiscovered()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard isTarget(peripheral) else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            send(.didFail(id: peripheral.identifier))
            return
        }
        peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard isTarget(peripheral) else { return }
        guard error == nil, let characteristic = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else {
            send(.didFail(id: peripheral.identifier))
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard isTarget(peripheral), characteristic.uuid == Self.characteristicUUID else { return }
        if error == nil && characteristic.isNotifying {
            send(.subscribed(id: peripheral.identifier))
        } else {
            send(.didFail(id: peripheral.identifier))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard isTarget(peripheral), characteristic.uuid == Self.characteristicUUID,
              error == nil, let data = characteristic.value,
              let measurement = HeartRateMeasurement.parse(data) else { return }
        measurementSubject.send(measurement)
    }

    // MARK: - Scanning

    private func startScanIfPossible() {
        guard wantsScan, let central, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        pruneTick = scheduleRepeatingPrune()
    }

    private func scheduleRepeatingPrune() -> AnyCancellable {
        Timer.publish(every: Self.pruneInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.publishDiscovered() }
    }

    private func publishDiscovered() {
        let connected: DiscoveredMonitor?
        if case .connected(let id, let name) = machine.state {
            connected = DiscoveredMonitor(id: id, name: name, rssi: 0, lastSeen: .distantPast)
        } else {
            connected = nil
        }
        let list = DiscoveredMonitor.visibleList(Array(seen.values), now: Date(), connected: connected)
        if list != discoveredSubject.value { discoveredSubject.send(list) }
    }
}
