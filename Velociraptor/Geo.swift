import CoreLocation
import MapKit
import SwiftUI

enum Geo {
    static let earthRadius: Double = 6_371_008.8

    /// Great-circle (haversine) distance in metres.
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Initial great-circle bearing from `a` to `b`, degrees clockwise from true north in `0..<360`.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalized(atan2(y, x) * 180 / .pi)
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Shortest angle between two headings, `0...180`.
    static func angularDistance(_ a: Double, _ b: Double) -> Double {
        let difference = abs(normalized(a) - normalized(b))
        return min(difference, 360 - difference)
    }
}

enum DistanceFormat {
    /// "850 m" below 1 km (rounded to the metre), "2.4 km" from 1 km.
    static func text(metres: Double) -> String {
        let rounded = metres.rounded()
        if rounded < 1000 { return "\(Int(rounded)) m" }
        return String(format: "%.1f km", metres / 1000)
    }

    /// Kilometres without the unit: "3.47" below 100 km, "128.1" from 100 km.
    static func progress(metres: Double) -> String {
        let kilometres = metres.isFinite ? max(0, metres) / 1000 : 0
        if (kilometres * 100).rounded() / 100 < 100 { return String(format: "%.2f", kilometres) }
        return String(format: "%.1f", kilometres)
    }
}

struct Viewport: Equatable {
    static let defaultWidth = 1_000.0
    static let minWidth = 100.0
    static let maxWidth = 20_000.0

    var center: CLLocationCoordinate2D
    /// Metres across the shorter side of the map view.
    var width: Double
    /// Degrees clockwise from true north that point to the top of the screen.
    var heading: Double

    static func clampedWidth(_ width: Double) -> Double {
        min(max(width, minWidth), maxWidth)
    }

    static func == (lhs: Viewport, rhs: Viewport) -> Bool {
        lhs.center.latitude == rhs.center.latitude
            && lhs.center.longitude == rhs.center.longitude
            && lhs.width == rhs.width
            && lhs.heading == rhs.heading
    }
}

/// The part of the map not covered by the speed/heart rate panels, and the projection between map and screen.
/// The viewport centre is drawn at the centre of `mapSize`; the top of the screen points to `viewport.heading`.
struct VisibleArea: Equatable {
    let mapSize: CGSize
    let insets: EdgeInsets
    let viewport: Viewport

    var visibleRect: CGRect {
        CGRect(
            x: insets.leading,
            y: insets.top,
            width: max(0, mapSize.width - insets.leading - insets.trailing),
            height: max(0, mapSize.height - insets.top - insets.bottom)
        )
    }

    var metresPerPoint: Double {
        viewport.width / Double(max(1, min(mapSize.width, mapSize.height)))
    }

    private var centerMapPoint: MKMapPoint { MKMapPoint(viewport.center) }
    private var mapPointsPerMetre: Double { MKMapPointsPerMeterAtLatitude(viewport.center.latitude) }
    private var headingRadians: Double { viewport.heading * .pi / 180 }

    func project(_ point: MKMapPoint) -> CGPoint {
        let center = centerMapPoint
        let east = (point.x - center.x) / mapPointsPerMetre
        let north = -(point.y - center.y) / mapPointsPerMetre
        let c = cos(headingRadians), s = sin(headingRadians)
        let x = (east * c - north * s) / metresPerPoint
        let y = -(north * c + east * s) / metresPerPoint
        return CGPoint(x: mapSize.width / 2 + x, y: mapSize.height / 2 + y)
    }

    func unproject(_ screen: CGPoint) -> MKMapPoint {
        let x = Double(screen.x - mapSize.width / 2) * metresPerPoint
        let y = Double(screen.y - mapSize.height / 2) * metresPerPoint
        let c = cos(headingRadians), s = sin(headingRadians)
        let east = c * x - s * y
        let north = -s * x - c * y
        let center = centerMapPoint
        return MKMapPoint(x: center.x + east * mapPointsPerMetre, y: center.y - north * mapPointsPerMetre)
    }

    /// Corners of `visibleRect` on the map, clockwise from top-left.
    var corners: [MKMapPoint] {
        let r = visibleRect
        return [
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
        ].map(unproject)
    }
}
