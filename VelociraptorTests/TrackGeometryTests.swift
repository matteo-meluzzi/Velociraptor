import CoreLocation
import MapKit
import SwiftUI
import Testing
@testable import Velociraptor

struct TrackGeometryTests {
    private let origin = CLLocationCoordinate2D(latitude: 45, longitude: 7)

    private func area(center: CLLocationCoordinate2D? = nil, heading: Double = 0, insets: EdgeInsets = EdgeInsets()) -> VisibleArea {
        VisibleArea(
            mapSize: CGSize(width: 390, height: 844),
            insets: insets,
            viewport: Viewport(center: center ?? origin, width: 1000, heading: heading)
        )
    }

    /// Points along the north-south line through `origin`, from `fromMetres` to `toMetres` (negative = south), in file order.
    private func line(from fromMetres: Double, to toMetres: Double, step: Double) -> [(Double, Double)] {
        stride(from: fromMetres, through: toMetres, by: step).map {
            let c = offset(origin, metres: abs($0), bearing: $0 < 0 ? 180 : 0)
            return (c.latitude, c.longitude)
        }
    }

    private func chevrons(_ track: Track, in area: VisibleArea) -> [Chevron] {
        TrackGeometry(track: track).chevrons(in: area, project: area.project, spacing: 60)
    }

    // MARK: Chevrons

    @Test func chevronsAreEvenlySpacedAndPointInFileOrder() {
        let result = chevrons(makeTrack([line(from: -3000, to: 3000, step: 100)]), in: area())
        #expect(result.count >= 13)
        let ys = result.map(\.position.y).sorted()
        for (a, b) in zip(ys, ys.dropFirst()) {
            #expect(abs((b - a) - 60) < 0.5)
        }
        for chevron in result {
            #expect(abs(chevron.position.x - 195) < 0.5)
            #expect(abs(chevron.angle.degrees) < 0.5) // south → north is "up" on a north-up screen
        }
    }

    @Test func chevronsMoveWithTheTrackWhenPanned() {
        let track = makeTrack([line(from: -3000, to: 3000, step: 100)])
        let before = chevrons(track, in: area())
        let pannedNorth = offset(origin, metres: 37 * area().metresPerPoint, bearing: 0)
        let after = chevrons(track, in: area(center: pannedNorth))
        for chevron in before where chevron.position.y < 700 {
            #expect(after.contains { abs($0.position.y - (chevron.position.y + 37)) < 0.5 })
        }
    }

    @Test func noChevronsWhenTrackIsOutsideTheView() {
        let far = offset(origin, metres: 5000, bearing: 90)
        let track = makeTrack([[(far.latitude, far.longitude - 0.01), (far.latitude, far.longitude + 0.01)]])
        #expect(chevrons(track, in: area()).isEmpty)
    }

    @Test func noChevronsOnTheGapBetweenSegments() {
        let track = makeTrack([line(from: -3000, to: -100, step: 100), line(from: 100, to: 3000, step: 100)])
        let result = chevrons(track, in: area())
        let gapHalfHeight = 100 / area().metresPerPoint
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { abs($0.position.y - 422) >= gapHalfHeight - 0.5 })
    }

    @Test func densePointsGiveTheSameChevrons() {
        let sparse = chevrons(makeTrack([line(from: -3000, to: 3000, step: 100)]), in: area())
        let dense = chevrons(makeTrack([line(from: -3000, to: 3000, step: 1)]), in: area())
        #expect(abs(sparse.count - dense.count) <= 1)
    }

    @Test func chevronsOnlyInsideTheVisibleArea() {
        let insets = EdgeInsets(top: 150, leading: 0, bottom: 80, trailing: 0)
        let a = area(insets: insets)
        let result = chevrons(makeTrack([line(from: -3000, to: 3000, step: 100)]), in: a)
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { a.visibleRect.contains($0.position) })
    }
}
