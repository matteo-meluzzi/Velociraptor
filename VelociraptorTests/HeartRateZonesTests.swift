import Testing
@testable import Velociraptor

struct HeartRateZonesTests {
    let zones = HeartRateZones(maxHeartRate: 200)

    @Test func belowZoneOneClampsToStart() {
        #expect(zones.position(for: 60) == 0)
        #expect(zones.zone(for: 60) == 0)
    }

    @Test func aboveMaxClampsToEnd() {
        #expect(zones.position(for: 230) == 1)
        #expect(zones.zone(for: 230) == 4)
    }

    @Test func positionIsLinearBetweenHalfAndMax() {
        #expect(zones.position(for: 150) == 0.5)
    }

    @Test(arguments: [(100, 0), (119, 0), (120, 1), (140, 2), (160, 3), (180, 4), (200, 4)])
    func zoneBoundaries(bpm: Int, zone: Int) {
        #expect(zones.zone(for: bpm) == zone)
    }
}
