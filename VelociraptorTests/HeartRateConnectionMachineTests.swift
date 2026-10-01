import Foundation
import Testing
@testable import Velociraptor

struct HeartRateConnectionMachineTests {
    let m = UUID()
    let m2 = UUID()
    let name = "Polar H10"
    let name2 = "Wahoo TICKR"

    private func available() -> HeartRateConnectionMachine {
        var machine = HeartRateConnectionMachine()
        _ = machine.handle(.availabilityChanged(.available))
        return machine
    }

    private func connecting(origin: ConnectOrigin) -> HeartRateConnectionMachine {
        var machine = available()
        if origin == .user {
            _ = machine.handle(.userSelected(id: m, name: name))
        } else {
            _ = machine.handle(.launch(storedID: m, storedName: name))
        }
        return machine
    }

    private func connected() -> HeartRateConnectionMachine {
        var machine = connecting(origin: .user)
        _ = machine.handle(.subscribed(id: m))
        return machine
    }

    private func lost() -> HeartRateConnectionMachine {
        var machine = connected()
        _ = machine.handle(.didDisconnect(id: m))
        _ = machine.handle(.subscribed(id: m))
        _ = machine.handle(.availabilityChanged(.poweredOff))
        _ = machine.handle(.availabilityChanged(.available))
        _ = machine.handle(.didFail(id: m))  // retrieval failed: lost, nothing pending
        return machine
    }

    // MARK: User selection

    @Test func noneUserSelectsConnectsWithTimeout() {
        var machine = available()
        let effects = machine.handle(.userSelected(id: m, name: name))
        #expect(machine.state == .connecting(monitorID: m, name: name, origin: .user))
        #expect(effects == [.saveLastMonitor(id: m, name: name), .connect(id: m), .startTimeout(id: m)])
    }

    @Test func switchingCancelsPreviousMonitor() {
        var fromConnected = connected()
        var fromLost = lost()
        var fromConnecting = connecting(origin: .user)

        let tail: [ConnectionEffect] = [.saveLastMonitor(id: m2, name: name2), .connect(id: m2), .startTimeout(id: m2)]
        #expect(fromConnected.handle(.userSelected(id: m2, name: name2)) == [.cancel(id: m)] + tail)
        #expect(fromLost.handle(.userSelected(id: m2, name: name2)) == [.cancel(id: m)] + tail)
        #expect(fromConnecting.handle(.userSelected(id: m2, name: name2)) == [.cancelTimeout, .cancel(id: m)] + tail)
        for machine in [fromConnected, fromLost, fromConnecting] {
            #expect(machine.state == .connecting(monitorID: m2, name: name2, origin: .user))
        }
    }

    @Test func selectingConnectedMonitorIsNoOp() {
        var machine = connected()
        let before = machine.state
        #expect(machine.handle(.userSelected(id: m, name: name)) == [])
        #expect(machine.state == before)
    }

    @Test func selectingLostOrAutomaticMonitorBecomesUserConnect() {
        var fromLost = lost()
        var fromAutomatic = connecting(origin: .automatic)
        let tail: [ConnectionEffect] = [.cancel(id: m), .saveLastMonitor(id: m, name: name), .connect(id: m), .startTimeout(id: m)]
        #expect(fromLost.handle(.userSelected(id: m, name: name)) == tail)
        #expect(fromAutomatic.handle(.userSelected(id: m, name: name)) == [.cancelTimeout] + tail)
        #expect(fromLost.state == .connecting(monitorID: m, name: name, origin: .user))
        #expect(fromAutomatic.state == .connecting(monitorID: m, name: name, origin: .user))
    }

    // MARK: Launch and connecting outcomes

    @Test func launchWithoutStoredMonitorDoesNothing() {
        var machine = HeartRateConnectionMachine()
        #expect(machine.handle(.launch(storedID: nil, storedName: nil)) == [])
        #expect(machine.handle(.availabilityChanged(.available)) == [])
        #expect(machine.state == .none)
    }

    @Test func launchWaitsForFirstPoweredOn() {
        var machine = HeartRateConnectionMachine()
        #expect(machine.handle(.launch(storedID: m, storedName: name)) == [])
        #expect(machine.state == .none)
        #expect(machine.handle(.availabilityChanged(.pending)) == [])
        #expect(machine.state == .none)
        #expect(machine.handle(.availabilityChanged(.available)) == [.retrieveAndConnect(id: m), .startTimeout(id: m)])
        #expect(machine.state == .connecting(monitorID: m, name: name, origin: .automatic))
    }

    @Test func launchReconnectRunsOnceOnly() {
        var machine = connecting(origin: .automatic)
        _ = machine.handle(.subscribed(id: m))
        _ = machine.handle(.availabilityChanged(.poweredOff))
        _ = machine.handle(.availabilityChanged(.available))
        _ = machine.handle(.subscribed(id: m))
        _ = machine.handle(.userSelected(id: m2, name: name2))
        _ = machine.handle(.timeoutFired(id: m2))
        #expect(machine.state == .none)
        #expect(machine.handle(.availabilityChanged(.poweredOff)) == [])
        #expect(machine.handle(.availabilityChanged(.available)) == [])
        #expect(machine.state == .none)
    }

    @Test func userConnectSubscribedBecomesConnected() {
        var machine = connecting(origin: .user)
        #expect(machine.handle(.subscribed(id: m)) == [.cancelTimeout])
        #expect(machine.state == .connected(monitorID: m, name: name))
    }

    @Test func userConnectFailureGoesToNoneWithMessage() {
        let events: [(ConnectionEvent, Bool)] = [
            (.didFail(id: m), true), (.didDisconnect(id: m), true), (.timeoutFired(id: m), false),
        ]
        for (event, cancelsTimeout) in events {
            var machine = connecting(origin: .user)
            let effects = machine.handle(event)
            #expect(machine.state == .none)
            #expect(effects.contains(.cancel(id: m)))
            #expect(effects.contains(.emitFailure(name: name)))
            #expect(effects.contains(.cancelTimeout) == cancelsTimeout)
        }
    }

    @Test func userConnectCutByBluetoothOffFailsWithMessage() {
        var machine = connecting(origin: .user)
        let effects = machine.handle(.availabilityChanged(.poweredOff))
        #expect(machine.state == .none)
        #expect(effects.contains(.emitFailure(name: name)))
        #expect(effects.contains(.cancelTimeout))
    }

    @Test func automaticConnectSubscribedBecomesConnected() {
        var machine = connecting(origin: .automatic)
        #expect(machine.handle(.subscribed(id: m)) == [.cancelTimeout])
        #expect(machine.state == .connected(monitorID: m, name: name))
    }

    @Test func automaticConnectFailureGoesLostWithPendingConnect() {
        let events: [(ConnectionEvent, [ConnectionEffect])] = [
            (.didFail(id: m), [.cancelTimeout, .cancel(id: m), .connect(id: m)]),
            (.timeoutFired(id: m), [.cancel(id: m), .connect(id: m)]),
        ]
        for (event, expected) in events {
            var machine = connecting(origin: .automatic)
            #expect(machine.handle(event) == expected)
            #expect(machine.state == .lost(monitorID: m, name: name))
            #expect(machine.hasPendingConnect)
        }
    }

    @Test func retrievalFailureInLostLeavesLostWithoutPending() {
        var machine = connecting(origin: .automatic)
        _ = machine.handle(.didFail(id: m))
        #expect(machine.handle(.didFail(id: m)) == [])
        #expect(machine.state == .lost(monitorID: m, name: name))
        #expect(!machine.hasPendingConnect)
    }

    // MARK: Connected, lost, availability, scene

    @Test func connectedDisconnectGoesLostAndReconnects() {
        var machine = connected()
        #expect(machine.handle(.didDisconnect(id: m)) == [.connect(id: m)])
        #expect(machine.state == .lost(monitorID: m, name: name))
        #expect(machine.hasPendingConnect)
    }

    @Test func lostSubscribedBecomesConnected() {
        var machine = connected()
        _ = machine.handle(.didDisconnect(id: m))
        #expect(machine.handle(.subscribed(id: m)) == [])
        #expect(machine.state == .connected(monitorID: m, name: name))
        #expect(!machine.hasPendingConnect)
    }

    @Test func sceneActiveInLostWithoutPendingReconnects() {
        var machine = lost()
        #expect(machine.handle(.sceneActive) == [.retrieveAndConnect(id: m)])
        #expect(machine.hasPendingConnect)
    }

    @Test func sceneActiveIsIdempotent() {
        var connectedMachine = connected()
        #expect(connectedMachine.handle(.sceneActive) == [])
        var noneMachine = available()
        #expect(noneMachine.handle(.sceneActive) == [])
        var pending = lost()
        _ = pending.handle(.sceneActive)
        #expect(pending.handle(.sceneActive) == [])
        var automatic = connecting(origin: .automatic)
        #expect(automatic.handle(.sceneActive) == [])
    }

    @Test func bluetoothOffWhileConnectedGoesLost() {
        let unavailable: [BluetoothAvailability] = [.poweredOff, .pending, .denied]
        for availability in unavailable {
            var fromConnected = connected()
            #expect(fromConnected.handle(.availabilityChanged(availability)) == [])
            #expect(fromConnected.state == .lost(monitorID: m, name: name))
            #expect(!fromConnected.hasPendingConnect)

            var fromLost = lost()
            _ = fromLost.handle(.sceneActive)
            #expect(fromLost.handle(.availabilityChanged(availability)) == [])
            #expect(fromLost.state == .lost(monitorID: m, name: name))
            #expect(!fromLost.hasPendingConnect)

            var fromAutomatic = connecting(origin: .automatic)
            #expect(fromAutomatic.handle(.availabilityChanged(availability)) == [.cancelTimeout])
            #expect(fromAutomatic.state == .lost(monitorID: m, name: name))
            #expect(!fromAutomatic.hasPendingConnect)
        }
    }

    @Test func bluetoothOnWhileLostReRetrieves() {
        var machine = connected()
        _ = machine.handle(.availabilityChanged(.poweredOff))
        #expect(machine.handle(.availabilityChanged(.available)) == [.retrieveAndConnect(id: m)])
        #expect(machine.state == .lost(monitorID: m, name: name))
        #expect(machine.hasPendingConnect)
    }

    @Test func availabilityIsTracked() {
        var machine = HeartRateConnectionMachine()
        for value in [BluetoothAvailability.pending, .available, .poweredOff, .denied, .unsupported, .notDetermined] {
            _ = machine.handle(.availabilityChanged(value))
            #expect(machine.availability == value)
        }
    }

    // MARK: Stale callbacks and contract guarantees

    @Test func staleCallbacksAreIgnored() {
        var machine = connected()
        _ = machine.handle(.userSelected(id: m2, name: name2))
        let before = machine.state
        let stale: [ConnectionEvent] = [
            .didDisconnect(id: m), .didFail(id: m), .subscribed(id: m), .timeoutFired(id: m), .didConnect(id: m),
        ]
        for event in stale {
            #expect(machine.handle(event) == [])
            #expect(machine.state == before)
        }
    }

    @Test func atMostOneMonitorTargeted() {
        let starts = [connected(), lost(), connecting(origin: .user), connecting(origin: .automatic)]
        for var machine in starts {
            let effects = machine.handle(.userSelected(id: m2, name: name2))
            let cancelIndex = effects.firstIndex(of: .cancel(id: m))
            let connectIndex = effects.firstIndex(of: .connect(id: m2))
            #expect(cancelIndex != nil)
            #expect(connectIndex != nil)
            #expect(cancelIndex! < connectIndex!)
        }
    }

    @Test func failuresEmittedOnlyForUserConnects() {
        var machine = HeartRateConnectionMachine()
        var all: [ConnectionEffect] = []
        all += machine.handle(.launch(storedID: m, storedName: name))
        all += machine.handle(.availabilityChanged(.available))
        all += machine.handle(.timeoutFired(id: m))
        all += machine.handle(.didFail(id: m))
        all += machine.handle(.subscribed(id: m))
        all += machine.handle(.didDisconnect(id: m))
        all += machine.handle(.availabilityChanged(.poweredOff))
        all += machine.handle(.availabilityChanged(.available))
        all += machine.handle(.sceneActive)
        #expect(!all.contains { if case .emitFailure = $0 { true } else { false } })
    }

    @Test func lastMonitorSavedOnEverySelectionEvenIfItFails() {
        var machine = available()
        let effects = machine.handle(.userSelected(id: m, name: name))
        #expect(effects.contains(.saveLastMonitor(id: m, name: name)))
        let after = machine.handle(.timeoutFired(id: m))
        #expect(!after.contains { if case .saveLastMonitor = $0 { true } else { false } })
        #expect(machine.state == .none)
    }

    @Test func savedMonitorButNoPermissionAtLaunch() {
        var machine = HeartRateConnectionMachine()
        #expect(machine.handle(.launch(storedID: m, storedName: name)) == [])
        #expect(machine.handle(.availabilityChanged(.pending)) == [])
        _ = machine.handle(.availabilityChanged(.available))
        #expect(machine.state == .connecting(monitorID: m, name: name, origin: .automatic))
    }

    // MARK: Review follow-ups

    @Test func disconnectDuringPendingConnectInLostClearsPending() {
        var machine = connected()
        _ = machine.handle(.didDisconnect(id: m))
        #expect(machine.hasPendingConnect)
        #expect(machine.handle(.didDisconnect(id: m)) == [])
        #expect(machine.state == .lost(monitorID: m, name: name))
        #expect(!machine.hasPendingConnect)
        #expect(machine.handle(.sceneActive) == [.retrieveAndConnect(id: m)])
    }

    @Test func selectingMonitorAlreadyConnectingByUserIsNoOp() {
        var machine = connecting(origin: .user)
        #expect(machine.handle(.userSelected(id: m, name: name)) == [])
        #expect(machine.state == .connecting(monitorID: m, name: name, origin: .user))
    }

    @Test func bluetoothOffDuringUserConnectCancelsPeripheral() {
        var machine = connecting(origin: .user)
        #expect(machine.handle(.availabilityChanged(.poweredOff)) == [.cancelTimeout, .cancel(id: m), .emitFailure(name: name)])
    }

    @Test func userSelectionClearsPendingLaunch() {
        var machine = HeartRateConnectionMachine()
        _ = machine.handle(.launch(storedID: m, storedName: name))
        _ = machine.handle(.availabilityChanged(.available))
        _ = machine.handle(.availabilityChanged(.poweredOff))
        _ = machine.handle(.userSelected(id: m2, name: name2))
        _ = machine.handle(.timeoutFired(id: m2))
        #expect(machine.state == .none)
        #expect(machine.handle(.availabilityChanged(.available)) == [])
    }

    @Test func callbacksIgnoredForUnrelatedMonitorInEveryState() {
        let machines = [HeartRateConnectionMachine(), connecting(origin: .automatic), connected(), lost()]
        let events: [ConnectionEvent] = [.didFail(id: m2), .didDisconnect(id: m2), .subscribed(id: m2), .timeoutFired(id: m2)]
        for var machine in machines {
            let before = machine.state
            for event in events {
                #expect(machine.handle(event) == [])
                #expect(machine.state == before)
            }
        }
    }

    @Test func didFailWhileConnectedIsIgnored() {
        var machine = connected()
        #expect(machine.handle(.didFail(id: m)) == [])
        #expect(machine.state == .connected(monitorID: m, name: name))
    }
}
