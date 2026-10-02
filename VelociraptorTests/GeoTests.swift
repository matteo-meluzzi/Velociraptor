import CoreLocation
import MapKit
import SwiftUI
import Testing
@testable import Velociraptor

struct GeoTests {
    private let origin = CLLocationCoordinate2D(latitude: 45, longitude: 7)

    @Test func distanceParisToLondon() {
        let paris = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        #expect(abs(Geo.distance(paris, london) - 343_500) < 343_500 * 0.005)
    }

    @Test func distanceToSamePointIsZero() {
        #expect(Geo.distance(origin, origin) == 0)
    }

    @Test(arguments: [(0.0, 0.0), (90.0, 90.0), (180.0, 180.0), (270.0, 270.0)])
    func bearingCardinalDirections(direction: Double, expected: Double) {
        let target = offset(origin, metres: 1000, bearing: direction)
        #expect(Geo.angularDistance(Geo.bearing(from: origin, to: target), expected) < 0.5)
    }

    @Test func angularDistanceWrapsAroundNorth() {
        #expect(Geo.angularDistance(358, 2) == 4)
    }

    @Test(arguments: [
        (0.4, "0 m"), (999.4, "999 m"), (999.6, "1.0 km"), (1000, "1.0 km"), (2449, "2.4 km"), (12_345, "12.3 km"),
    ])
    func distanceText(metres: Double, expected: String) {
        #expect(DistanceFormat.text(metres: metres) == expected)
    }

    @Test(arguments: [
        (0.0, "0.00"), (3_474, "3.47"), (99_994, "99.99"), (99_996, "100.0"), (128_060, "128.1"), (-3, "0.00"),
        (.nan, "0.00"),
    ])
    func progressText(metres: Double, expected: String) {
        #expect(DistanceFormat.progress(metres: metres) == expected)
    }

    private func area(heading: Double, insets: EdgeInsets = EdgeInsets()) -> VisibleArea {
        VisibleArea(
            mapSize: CGSize(width: 390, height: 844),
            insets: insets,
            viewport: Viewport(center: origin, width: 1000, heading: heading)
        )
    }

    @Test func pointNorthProjectsAboveCentreWhenNorthUp() {
        let area = area(heading: 0)
        let point = area.project(MKMapPoint(offset(origin, metres: 100, bearing: 0)))
        #expect(abs(point.x - 195) < 0.5)
        #expect(abs((422 - point.y) - 100 / area.metresPerPoint) < 0.5)
    }

    @Test func pointNorthProjectsLeftWhenHeadingEast() {
        let point = area(heading: 90).project(MKMapPoint(offset(origin, metres: 100, bearing: 0)))
        #expect(point.x < 195 - 30)
        #expect(abs(point.y - 422) < 0.5)
    }

    @Test func unprojectInvertsProject() {
        let area = area(heading: 37)
        let screen = CGPoint(x: 120, y: 600)
        let back = area.project(area.unproject(screen))
        #expect(abs(back.x - screen.x) < 0.01)
        #expect(abs(back.y - screen.y) < 0.01)
    }

    @Test func visibleRectExcludesInsets() {
        let area = area(heading: 0, insets: EdgeInsets(top: 150, leading: 0, bottom: 80, trailing: 0))
        #expect(area.visibleRect == CGRect(x: 0, y: 150, width: 390, height: 614))
    }

    @Test func locationFixBehaviorPassesInvalidAccuracyThrough() {
        let location = CLLocation(
            coordinate: origin, altitude: 0, horizontalAccuracy: -1, verticalAccuracy: -1,
            course: 90, speed: 2, timestamp: Date()
        )
        let fix = LocationFixBehavior().value(from: location)
        #expect(fix?.horizontalAccuracy == -1)
        #expect(fix?.course == 90)
    }
}
