import CoreLocation
import MapKit
import SwiftUI

/// A direction marker on the track line, in screen points. `angle` is the file-order direction (0 = up, clockwise).
struct Chevron: Equatable {
    let position: CGPoint
    let angle: Angle
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
    /// Per segment, map-point length from the segment start to each point.
    let cumulativeLength: [[Double]]
    let chunks: [Chunk]

    init(track: Track) {
        segments = track.segments.map { $0.points.map { MKMapPoint($0.coordinate) } }
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
