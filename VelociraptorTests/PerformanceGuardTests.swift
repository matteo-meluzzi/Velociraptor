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
}
