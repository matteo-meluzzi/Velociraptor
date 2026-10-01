import Combine
import Foundation

enum BluetoothAvailability: Equatable {
    case notDetermined  // central not yet created (permission never asked)
    case pending        // .unknown / .resetting
    case available      // .poweredOn
    case poweredOff
    case denied         // .unauthorized
    case unsupported    // .unsupported (e.g. Simulator)
}

enum ConnectOrigin: Equatable {
    case user, automatic
}

enum MonitorConnectionState: Equatable {
    case none
    case connecting(monitorID: UUID, name: String, origin: ConnectOrigin)
    case connected(monitorID: UUID, name: String)
    case lost(monitorID: UUID, name: String)

    var monitorID: UUID? {
        switch self {
        case .none: return nil
        case .connecting(let id, _, _), .connected(let id, _), .lost(let id, _): return id
        }
    }

    var name: String? {
        switch self {
        case .none: return nil
        case .connecting(_, let name, _), .connected(_, let name), .lost(_, let name): return name
        }
    }
}

struct DiscoveredMonitor: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    let lastSeen: Date

    static let unnamedName = "Unnamed heart rate monitor"
    static let staleInterval: TimeInterval = 5

    static func displayName(advertisedName: String?, peripheralName: String?) -> String {
        if let advertisedName, !advertisedName.isEmpty { return advertisedName }
        if let peripheralName, !peripheralName.isEmpty { return peripheralName }
        return unnamedName
    }

    static func visibleList(_ monitors: [DiscoveredMonitor], now: Date, connected: DiscoveredMonitor?) -> [DiscoveredMonitor] {
        let fresh = monitors
            .filter { now.timeIntervalSince($0.lastSeen) <= staleInterval && $0.id != connected?.id }
            .sorted { lhs, rhs in
                if (lhs.rssi == 127) != (rhs.rssi == 127) { return rhs.rssi == 127 }
                return lhs.rssi > rhs.rssi
            }
        guard let connected else { return fresh }
        return [connected] + fresh
    }
}

protocol HeartRateMonitorProviding: AnyObject {
    /// Current value replayed on subscription.
    var availability: AnyPublisher<BluetoothAvailability, Never> { get }
    /// Current value replayed on subscription.
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { get }
    /// Sorted nearest first, pruned of stale entries; the connected monitor is pinned first.
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { get }
    /// Every parsed 0x2A37 value.
    var measurements: AnyPublisher<HeartRateMeasurement, Never> { get }
    /// Monitor name; emitted for user-initiated connection failures only.
    var connectionFailures: AnyPublisher<String, Never> { get }

    /// Creates the central if needed (may prompt for permission); scans once powered on.
    func startScanning()
    func stopScanning()
    /// User-initiated; disconnects any current or pending monitor first.
    func connect(to monitorID: UUID)
    /// Idempotent; called at launch and when the scene becomes active.
    func reconnectIfNeeded()
}

protocol LastMonitorStoring: AnyObject {
    var lastMonitorID: UUID? { get set }
    var lastMonitorName: String? { get set }
}

final class UserDefaultsLastMonitorStore: LastMonitorStoring {
    private static let idKey = "lastHeartRateMonitorID"
    private static let nameKey = "lastHeartRateMonitorName"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastMonitorID: UUID? {
        get { defaults.string(forKey: Self.idKey).flatMap(UUID.init(uuidString:)) }
        set {
            if let newValue { defaults.set(newValue.uuidString, forKey: Self.idKey) }
            else { defaults.removeObject(forKey: Self.idKey) }
        }
    }

    var lastMonitorName: String? {
        get { defaults.string(forKey: Self.nameKey) }
        set {
            if let newValue { defaults.set(newValue, forKey: Self.nameKey) }
            else { defaults.removeObject(forKey: Self.nameKey) }
        }
    }
}
