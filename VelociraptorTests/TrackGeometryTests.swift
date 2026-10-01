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

    // MARK: Nearest position

    private func coordinate(_ c: CLLocationCoordinate2D) -> (Double, Double) { (c.latitude, c.longitude) }

    @Test func nearestOnATrackPointIsZero() {
        let nearest = TrackGeometry(track: makeTrack([line(from: -1000, to: 1000, step: 100)])).nearestPosition(to: origin)
        #expect(nearest.distance < 0.5)
    }

    @Test func nearestCanBeInTheMiddleOfAnEdge() {
        let a = offset(origin, metres: 1000, bearing: 180), b = offset(origin, metres: 1000, bearing: 0)
        let user = offset(origin, metres: 300, bearing: 90)
        let nearest = TrackGeometry(track: makeTrack([[coordinate(a), coordinate(b)]])).nearestPosition(to: user)
        #expect(abs(nearest.distance - 300) < 1)
        #expect(Geo.distance(nearest.coordinate, origin) < 2)
    }

    @Test func nearestIsOnTheCloserSegment() {
        let far = offset(origin, metres: 2000, bearing: 270), near = offset(origin, metres: 500, bearing: 90)
        let track = makeTrack([[coordinate(far)], [coordinate(near), coordinate(offset(near, metres: 100, bearing: 0))]])
        let nearest = TrackGeometry(track: track).nearestPosition(to: origin)
        #expect(abs(nearest.distance - 500) < 1)
    }

    @Test func nearestIsNeverOnTheGapBetweenSegments() {
        let track = makeTrack([line(from: -2000, to: -500, step: 100), line(from: 500, to: 2000, step: 100)])
        let nearest = TrackGeometry(track: track).nearestPosition(to: offset(origin, metres: 50, bearing: 90))
        #expect(nearest.distance > 400)
    }

    @Test func nearestOnOutAndBackTrackIsTheClosest() {
        let east = offset(origin, metres: 200, bearing: 90)
        let out = line(from: -1000, to: 1000, step: 100)
        let back = [coordinate(offset(east, metres: 1000, bearing: 0)), coordinate(offset(east, metres: 1000, bearing: 180))]
        let nearest = TrackGeometry(track: makeTrack([out + back])).nearestPosition(to: offset(origin, metres: 250, bearing: 90))
        #expect(abs(nearest.distance - 50) < 1)
    }

    @Test func bearingPointsAtTheTrack() {
        let user = offset(origin, metres: 2000, bearing: 90)
        let nearest = TrackGeometry(track: makeTrack([line(from: -3000, to: 3000, step: 100)])).nearestPosition(to: user)
        #expect(Geo.angularDistance(nearest.bearing, 270) < 5)
        #expect(abs(nearest.distance - 2000) < 5)
    }

    @Test func nearestOnSinglePointTrack() {
        let point = offset(origin, metres: 700, bearing: 45)
        let nearest = TrackGeometry(track: makeTrack([[coordinate(point)]])).nearestPosition(to: origin)
        #expect(abs(nearest.distance - 700) < 2)
    }

    // MARK: Track in view

    @Test func trackPointInsideIsInView() {
        let track = makeTrack([[coordinate(offset(origin, metres: 50, bearing: 0))]])
        #expect(TrackGeometry(track: track).intersects(area()))
    }

    @Test func longEdgeCrossingTheViewIsInView() {
        let a = offset(origin, metres: 5000, bearing: 270), b = offset(origin, metres: 5000, bearing: 90)
        #expect(TrackGeometry(track: makeTrack([[coordinate(a), coordinate(b)]])).intersects(area()))
    }

    @Test func trackOnlyUnderTheTopPanelIsNotInView() {
        let insets = EdgeInsets(top: 150, leading: 0, bottom: 0, trailing: 0)
        // ~1000 m wide view over 390 pt: the top 150 pt cover 422…272 pt above centre ≈ 700…1080 m north.
        let y = offset(origin, metres: 1000, bearing: 0)
        let track = makeTrack([[coordinate(offset(y, metres: 3000, bearing: 270)), coordinate(offset(y, metres: 3000, bearing: 90))]])
        let geometry = TrackGeometry(track: track)
        #expect(geometry.intersects(area()))
        #expect(!geometry.intersects(area(insets: insets)))
    }

    @Test func rotationCanBringTheTrackIntoView() {
        // The view is ±500 m wide and ±1082 m high. 1050 m at bearing 35° is 602 m east (outside when north-up),
        // but straight ahead and inside when the view is rotated to 35°.
        let track = makeTrack([[coordinate(offset(origin, metres: 1050, bearing: 35))]])
        let geometry = TrackGeometry(track: track)
        #expect(!geometry.intersects(area(heading: 0)))
        #expect(geometry.intersects(area(heading: 35)))
    }

    @Test func gapBetweenSegmentsCrossingTheViewIsNotInView() {
        let track = makeTrack([line(from: -5000, to: -3000, step: 500), line(from: 3000, to: 5000, step: 500)])
        #expect(!TrackGeometry(track: track).intersects(area()))
    }
}
