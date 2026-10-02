import CoreLocation
import Foundation
import SwiftUI
import Testing
@testable import Velociraptor

/// Generous regression guards on the simulator (Debug build); they don't prove SC-002, which is measured on device (D6).
struct PerformanceGuardTests {
    private static let data = Data(largeGPX().utf8)

    /// Best of several runs, so other tests running in parallel don't make the guard flaky.
    private func elapsed(runs: Int = 5, _ work: () -> Void) -> Duration {
        (0..<runs).map { _ in ContinuousClock().measure(work) }.min()!
    }

    @Test func largeTrackParsesAndPreparesQuickly() {
        var geometry: TrackGeometry?
        let duration = elapsed(runs: 3) {
            if case .success(let track) = GPXParser.parse(Self.data, fileName: "large.gpx") {
                geometry = TrackGeometry(track: track)
            }
        }
        #expect(geometry != nil)
        #expect(duration < .seconds(2), "parse + geometry took \(duration)")
    }

    /// Runs on the main actor once per fix, so it has to fit well inside a frame (SC-004).
    @Test func progressUpdateOnLargeTrackFitsInAFrame() throws {
        guard case .success(let track) = GPXParser.parse(Self.data, fileName: "large.gpx") else {
            Issue.record("large track did not parse")
            return
        }
        var tracker = TrackProgressTracker(route: TrackRoute(track: track))
        let middle = track.segments[0].points[25_000].coordinate
        _ = tracker.update(middle)
        var step = 0.0
        let duration = elapsed {
            step += 0.000001
            _ = tracker.update(CLLocationCoordinate2D(latitude: middle.latitude + step, longitude: middle.longitude))
        }
        #expect(duration < .milliseconds(16), "progress update took \(duration)")
    }

    /// Worst case for the off-track search: at the centre of a big loop every edge is almost equally near, so the whole
    /// track is scanned twice. About 23 ms in this Debug build; under 16 ms in Release (checked 2026-10-02, research R3).
    @Test func progressUpdateAtTheCentreOfALargeLoopFitsInAFrame() {
        let centre = CLLocationCoordinate2D(latitude: 45, longitude: 7)
        let points = (0..<50_000).map { i in
            let c = offset(centre, metres: 5000, bearing: Double(i) * 360 / 50_000)
            return TrackPoint(latitude: c.latitude, longitude: c.longitude)
        }
        var tracker = TrackProgressTracker(route: TrackRoute(track: Track(name: "Ring", segments: [TrackSegment(points: points)])))
        var step = 0.0
        let duration = elapsed {
            step += 0.000001
            _ = tracker.update(CLLocationCoordinate2D(latitude: centre.latitude + step, longitude: centre.longitude))
        }
        #expect(duration < .milliseconds(50), "off-track progress update took \(duration)")
    }
}
