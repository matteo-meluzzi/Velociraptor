import Foundation

enum ConnectionEvent: Equatable {
    case launch(storedID: UUID?, storedName: String?)
    case userSelected(id: UUID, name: String)
    case didConnect(id: UUID)
    case subscribed(id: UUID)
    case didFail(id: UUID)
    case didDisconnect(id: UUID)
    case timeoutFired(id: UUID)
    case availabilityChanged(BluetoothAvailability)
    case sceneActive
}

enum ConnectionEffect: Equatable {
    case retrieveAndConnect(id: UUID)
    case connect(id: UUID)
    case cancel(id: UUID)
    case startTimeout(id: UUID)
    case cancelTimeout
    case saveLastMonitor(id: UUID, name: String)
    case emitFailure(name: String)
}

/// Pure implementation of the transitions table in data-model.md.
struct HeartRateConnectionMachine {
    static let connectTimeout: TimeInterval = 10

    private(set) var state: MonitorConnectionState = .none
    private(set) var availability: BluetoothAvailability = .notDetermined
    private(set) var hasPendingConnect = false
    private var pendingLaunch: (id: UUID, name: String)?

    mutating func handle(_ event: ConnectionEvent) -> [ConnectionEffect] {
        switch event {
        case .launch(let storedID, let storedName):
            if let storedID, let storedName {
                pendingLaunch = (storedID, storedName)
            }
            return consumeLaunchIfPossible()

        case .userSelected(let id, let name):
            return userSelected(id: id, name: name)

        case .didConnect:
            return []

        case .subscribed(let id):
            guard id == state.monitorID else { return [] }
            switch state {
            case .connecting(_, let name, _):
                state = .connected(monitorID: id, name: name)
                hasPendingConnect = false
                return [.cancelTimeout]
            case .lost(_, let name):
                state = .connected(monitorID: id, name: name)
                hasPendingConnect = false
                return []
            case .connected, .none:
                return []
            }

        case .didFail(let id):
            guard id == state.monitorID else { return [] }
            if case .lost = state {
                hasPendingConnect = false
                return []
            }
            return connectionEnded(id: id, cancelsTimeout: true)

        case .didDisconnect(let id):
            guard id == state.monitorID else { return [] }
            switch state {
            case .connecting:
                return connectionEnded(id: id, cancelsTimeout: true)
            case .connected(_, let name):
                state = .lost(monitorID: id, name: name)
                hasPendingConnect = true
                return [.connect(id: id)]
            case .lost:
                // A connect attempt died before subscribing (or echoes our own cancel).
                hasPendingConnect = false
                return []
            case .none:
                return []
            }

        case .timeoutFired(let id):
            guard id == state.monitorID, case .connecting = state else { return [] }
            return connectionEnded(id: id, cancelsTimeout: false)

        case .availabilityChanged(let newAvailability):
            availability = newAvailability
            return newAvailability == .available ? becameAvailable() : leftAvailable()

        case .sceneActive:
            guard availability == .available, !hasPendingConnect,
                  case .lost(let id, _) = state else { return [] }
            hasPendingConnect = true
            return [.retrieveAndConnect(id: id)]
        }
    }

    private mutating func userSelected(id: UUID, name: String) -> [ConnectionEffect] {
        switch state {
        case .connected(let current, _) where current == id: return []
        case .connecting(let current, _, .user) where current == id: return []
        default: break
        }
        var effects: [ConnectionEffect] = []
        if case .connecting = state { effects.append(.cancelTimeout) }
        if let old = state.monitorID { effects.append(.cancel(id: old)) }
        pendingLaunch = nil
        state = .connecting(monitorID: id, name: name, origin: .user)
        hasPendingConnect = true
        effects += [.saveLastMonitor(id: id, name: name), .connect(id: id), .startTimeout(id: id)]
        return effects
    }

    /// A failure, early disconnect or timeout while connecting.
    private mutating func connectionEnded(id: UUID, cancelsTimeout: Bool) -> [ConnectionEffect] {
        guard case .connecting(_, let name, let origin) = state else { return [] }
        var effects: [ConnectionEffect] = cancelsTimeout ? [.cancelTimeout] : []
        effects.append(.cancel(id: id))
        switch origin {
        case .user:
            state = .none
            hasPendingConnect = false
            effects.append(.emitFailure(name: name))
        case .automatic:
            state = .lost(monitorID: id, name: name)
            hasPendingConnect = true
            effects.append(.connect(id: id))
        }
        return effects
    }

    private mutating func becameAvailable() -> [ConnectionEffect] {
        let effects = consumeLaunchIfPossible()
        if !effects.isEmpty { return effects }
        if case .lost(let id, _) = state, !hasPendingConnect {
            hasPendingConnect = true
            return [.retrieveAndConnect(id: id)]
        }
        return []
    }

    private mutating func leftAvailable() -> [ConnectionEffect] {
        hasPendingConnect = false
        switch state {
        case .connecting(let id, let name, .user):
            state = .none
            return [.cancelTimeout, .cancel(id: id), .emitFailure(name: name)]
        case .connecting(let id, let name, .automatic):
            state = .lost(monitorID: id, name: name)
            return [.cancelTimeout]
        case .connected(let id, let name):
            state = .lost(monitorID: id, name: name)
            return []
        case .lost, .none:
            return []
        }
    }

    private mutating func consumeLaunchIfPossible() -> [ConnectionEffect] {
        guard availability == .available, case .none = state, let launch = pendingLaunch else { return [] }
        pendingLaunch = nil
        state = .connecting(monitorID: launch.id, name: launch.name, origin: .automatic)
        hasPendingConnect = true
        return [.retrieveAndConnect(id: launch.id), .startTimeout(id: launch.id)]
    }
}
