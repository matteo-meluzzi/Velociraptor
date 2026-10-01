import Foundation
import Testing
@testable import Velociraptor

struct HeartRateMonitorProvidingTests {
    private let now = Date(timeIntervalSince1970: 1000)

    private func monitor(_ name: String = "M", rssi: Int = -50, age: TimeInterval = 0, id: UUID = UUID()) -> DiscoveredMonitor {
        DiscoveredMonitor(id: id, name: name, rssi: rssi, lastSeen: now.addingTimeInterval(-age))
    }

    @Test func prunesStaleEntry() {
        let list = DiscoveredMonitor.visibleList([monitor(age: 5.1)], now: now, connected: nil)
        #expect(list.isEmpty)
    }

    @Test func keepsEntryAtExactlyFiveSeconds() {
        let list = DiscoveredMonitor.visibleList([monitor(age: 5)], now: now, connected: nil)
        #expect(list.count == 1)
    }

    @Test func sortsNearestFirst() {
        let far = monitor("far", rssi: -70)
        let near = monitor("near", rssi: -40)
        let list = DiscoveredMonitor.visibleList([far, near], now: now, connected: nil)
        #expect(list.map(\.name) == ["near", "far"])
    }

    @Test func unavailableRssiSortsLast() {
        let unknown = monitor("unknown", rssi: 127)
        let far = monitor("far", rssi: -90)
        let list = DiscoveredMonitor.visibleList([unknown, far], now: now, connected: nil)
        #expect(list.map(\.name) == ["far", "unknown"])
    }

    @Test func duplicateNamesAreKept() {
        let list = DiscoveredMonitor.visibleList([monitor("Polar"), monitor("Polar")], now: now, connected: nil)
        #expect(list.count == 2)
    }

    @Test func connectedIsPinnedFirstAndDeduplicated() {
        let id = UUID()
        let connected = monitor("Connected", rssi: 0, id: id)
        let duplicate = monitor("Connected", rssi: -30, id: id)
        let other = monitor("Other", rssi: -40)
        let list = DiscoveredMonitor.visibleList([other, duplicate], now: now, connected: connected)
        #expect(list.map(\.id) == [id, other.id])
    }

    @Test func advertisedNameWins() {
        #expect(DiscoveredMonitor.displayName(advertisedName: "Adv", peripheralName: "Per") == "Adv")
    }

    @Test func fallsBackToPeripheralName() {
        #expect(DiscoveredMonitor.displayName(advertisedName: nil, peripheralName: "Per") == "Per")
    }

    @Test func fallsBackToUnnamed() {
        #expect(DiscoveredMonitor.displayName(advertisedName: nil, peripheralName: nil) == "Unnamed heart rate monitor")
    }

    @Test func emptyNameCountsAsMissing() {
        #expect(DiscoveredMonitor.displayName(advertisedName: "", peripheralName: "Per") == "Per")
        #expect(DiscoveredMonitor.displayName(advertisedName: "", peripheralName: "") == "Unnamed heart rate monitor")
    }

    private func makeStore() -> (UserDefaultsLastMonitorStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "HeartRateTests-\(UUID())")!
        return (UserDefaultsLastMonitorStore(defaults: defaults), defaults)
    }

    @Test func storeRoundTrips() {
        let (store, _) = makeStore()
        let id = UUID()
        store.lastMonitorID = id
        store.lastMonitorName = "Polar H10"
        #expect(store.lastMonitorID == id)
        #expect(store.lastMonitorName == "Polar H10")
    }

    @Test func storeNilRemoves() {
        let (store, defaults) = makeStore()
        store.lastMonitorID = UUID()
        store.lastMonitorName = "X"
        store.lastMonitorID = nil
        store.lastMonitorName = nil
        #expect(defaults.object(forKey: "lastHeartRateMonitorID") == nil)
        #expect(defaults.object(forKey: "lastHeartRateMonitorName") == nil)
    }

    @Test func garbageIDReadsNil() {
        let (store, defaults) = makeStore()
        defaults.set("not-a-uuid", forKey: "lastHeartRateMonitorID")
        #expect(store.lastMonitorID == nil)
    }
}
