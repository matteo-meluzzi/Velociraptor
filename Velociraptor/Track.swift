import CoreLocation

struct TrackPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// An ordered run of points; segments of a track are never joined to each other. Always ≥ 1 point.
struct TrackSegment: Codable, Equatable {
    let points: [TrackPoint]
}

/// A route imported from a GPX file. `name` is never empty; `segments` has ≥ 1 segment (guaranteed by `GPXParser`).
struct Track: Codable, Equatable {
    /// Start and finish closer than this are shown as one combined marker.
    static let loopThreshold: Double = 20

    let name: String
    let segments: [TrackSegment]

    var start: TrackPoint { segments[0].points[0] }
    var finish: TrackPoint { segments[segments.count - 1].points.last! }
    var isLoop: Bool { Geo.distance(start.coordinate, finish.coordinate) <= Self.loopThreshold }
}
