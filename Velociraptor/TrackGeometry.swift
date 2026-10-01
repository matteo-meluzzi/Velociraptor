import CoreLocation
import MapKit
import SwiftUI

/// A direction marker on the track line, in screen points. `angle` is the file-order direction (0 = up, clockwise).
struct Chevron: Equatable {
    let position: CGPoint
    let angle: Angle
}

struct NearestTrackPosition: Equatable {
    /// Anywhere on the track line, not only at its points.
    let coordinate: CLLocationCoordinate2D
    /// Metres from the user's real position.
    let distance: Double
    /// Initial bearing from the user to `coordinate`.
    let bearing: Double

    static func == (lhs: NearestTrackPosition, rhs: NearestTrackPosition) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.distance == rhs.distance && lhs.bearing == rhs.bearing
    }
}

/// Precomputed, map-projected form of a track for per-frame queries.
struct TrackGeometry {
    static let chunkSize = 256

    struct Chunk {
        let segment: Int
        /// Point indices; consecutive chunks of a segment share their boundary point, so every edge is in exactly one chunk.
        let points: ClosedRange<Int>
        let boundingRect: MKMapRect
    }

    let segments: [[MKMapPoint]]
    let coordinates: [[CLLocationCoordinate2D]]
    /// Per segment, map-point length from the segment start to each point.
    let cumulativeLength: [[Double]]
    let chunks: [Chunk]

    init(track: Track) {
        coordinates = track.segments.map { $0.points.map(\.coordinate) }
        segments = coordinates.map { $0.map(MKMapPoint.init) }
        cumulativeLength = segments.map { points in
            var total = 0.0
            return points.indices.map { i in
                if i > 0 { total += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y) }
                return total
            }
        }
        var chunks: [Chunk] = []
        for (s, points) in segments.enumerated() {
            var start = 0
            repeat {
                let end = min(start + Self.chunkSize, points.count - 1)
                chunks.append(Chunk(segment: s, points: start...end, boundingRect: Self.boundingRect(points[start...end])))
                start = end
            } while start < points.count - 1
        }
        self.chunks = chunks
    }

    /// Chevrons `spacing` points apart along the on-screen line, anchored to the track so they don't crawl when panning.
    func chevrons(in area: VisibleArea, project: (MKMapPoint) -> CGPoint, spacing: CGFloat) -> [Chevron] {
        let spacingInMapPoints = Double(spacing) * area.metresPerPoint
            * MKMapPointsPerMeterAtLatitude(area.viewport.center.latitude)
        guard spacingInMapPoints > 0 else { return [] }
        let visibleRect = area.visibleRect
        let bounds = Self.boundingRect(area.corners[...])
        var result: [Chevron] = []
        for chunk in chunks where chunk.boundingRect.intersects(bounds) {
            let points = segments[chunk.segment]
            let lengths = cumulativeLength[chunk.segment]
            for i in chunk.points.lowerBound..<chunk.points.upperBound {
                let startLength = lengths[i], endLength = lengths[i + 1]
                guard endLength > startLength else { continue }
                var k = (startLength / spacingInMapPoints).rounded(.up)
                var screenStart: CGPoint?, screenEnd: CGPoint?
                while k * spacingInMapPoints < endLength {
                    let t = (k * spacingInMapPoints - startLength) / (endLength - startLength)
                    let a = points[i], b = points[i + 1]
                    let position = project(MKMapPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                    if visibleRect.contains(position) {
                        if screenStart == nil { screenStart = project(a); screenEnd = project(b) }
                        let dx = screenEnd!.x - screenStart!.x, dy = screenEnd!.y - screenStart!.y
                        result.append(Chevron(position: position, angle: .radians(atan2(dx, -dy))))
                    }
                    k += 1
                }
            }
        }
        return result
    }

    /// The closest position on the track line (segments are not joined), searched in a local metre frame around `user`.
    func nearestPosition(to user: CLLocationCoordinate2D) -> NearestTrackPosition {
        let metresPerDegree = Geo.earthRadius * .pi / 180
        let metresPerDegreeLongitude = metresPerDegree * cos(user.latitude * .pi / 180)
        func local(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((c.longitude - user.longitude) * metresPerDegreeLongitude, (c.latitude - user.latitude) * metresPerDegree)
        }

        var best = (squared: Double.infinity, x: 0.0, y: 0.0)
        func consider(_ x: Double, _ y: Double) {
            let squared = x * x + y * y
            if squared < best.squared { best = (squared, x, y) }
        }
        for segment in coordinates {
            var previous = local(segment[0])
            if segment.count == 1 { consider(previous.x, previous.y) }
            for coordinate in segment.dropFirst() {
                let current = local(coordinate)
                let dx = current.x - previous.x, dy = current.y - previous.y
                let lengthSquared = dx * dx + dy * dy
                let t = lengthSquared > 0 ? min(1, max(0, -(previous.x * dx + previous.y * dy) / lengthSquared)) : 0
                consider(previous.x + t * dx, previous.y + t * dy)
                previous = current
            }
        }
        let nearest = CLLocationCoordinate2D(
            latitude: user.latitude + best.y / metresPerDegree,
            longitude: user.longitude + best.x / metresPerDegreeLongitude
        )
        return NearestTrackPosition(
            coordinate: nearest, distance: Geo.distance(user, nearest), bearing: Geo.bearing(from: user, to: nearest)
        )
    }

    /// Whether any part of the track line lies inside the visible area (even if none of its points do).
    func intersects(_ area: VisibleArea) -> Bool {
        guard !area.visibleRect.isEmpty else { return false }
        let corners = area.corners
        let bounds = Self.boundingRect(corners[...])
        for chunk in chunks where chunk.boundingRect.intersects(bounds) {
            let points = segments[chunk.segment]
            if chunk.points.count == 1, Self.contains(corners, points[chunk.points.lowerBound]) { return true }
            for i in chunk.points.lowerBound..<chunk.points.upperBound {
                let a = points[i], b = points[i + 1]
                if Self.contains(corners, a) || Self.contains(corners, b) { return true }
                for side in 0..<corners.count where Self.segmentsIntersect(a, b, corners[side], corners[(side + 1) % corners.count]) {
                    return true
                }
            }
        }
        return false
    }

    /// Point inside a convex polygon (any winding).
    private static func contains(_ polygon: [MKMapPoint], _ p: MKMapPoint) -> Bool {
        var sign = 0.0
        for i in polygon.indices {
            let cross = Self.cross(polygon[i], polygon[(i + 1) % polygon.count], p)
            if cross == 0 { continue }
            if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
        }
        return true
    }

    private static func cross(_ o: MKMapPoint, _ a: MKMapPoint, _ b: MKMapPoint) -> Double {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }

    private static func segmentsIntersect(_ p1: MKMapPoint, _ p2: MKMapPoint, _ q1: MKMapPoint, _ q2: MKMapPoint) -> Bool {
        let d1 = cross(q1, q2, p1), d2 = cross(q1, q2, p2), d3 = cross(p1, p2, q1), d4 = cross(p1, p2, q2)
        return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0))
    }

    private static func boundingRect<C: Collection>(_ points: C) -> MKMapRect where C.Element == MKMapPoint {
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        // A zero-size rect never intersects anything, so give single points and straight lines some thickness.
        return MKMapRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    }
}
