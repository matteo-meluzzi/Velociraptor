import CoreLocation

/// The track as one line in file order for measuring along it; gaps between segments are ordinary edges.
struct TrackRoute {
    /// A run of consecutive edges with the box around them, so far-away parts of the track are skipped per fix.
    struct Chunk {
        let edges: Range<Int>
        let minX, maxX, minY, maxY: Double
    }

    static let chunkSize = 64

    let coordinates: [CLLocationCoordinate2D]
    /// Metres from the start to each point.
    let cumulative: [Double]
    /// Each point in metres east (`x`) and north (`y`) of the first point; flat within the accuracy needed here.
    let x: [Double]
    let y: [Double]
    let chunks: [Chunk]
    private let origin: CLLocationCoordinate2D
    private let metresPerDegreeLongitude: Double

    private static let metresPerDegree = Geo.earthRadius * .pi / 180

    var length: Double { cumulative.last ?? 0 }
    var edgeCount: Int { max(0, coordinates.count - 1) }

    init(track: Track) {
        let coordinates = track.segments.flatMap { $0.points.map(\.coordinate) }
        var total = 0.0
        cumulative = coordinates.indices.map { i in
            if i > 0 { total += Geo.distance(coordinates[i - 1], coordinates[i]) }
            return total
        }
        let origin = coordinates[0]
        let metresPerDegreeLongitude = Self.metresPerDegree * cos(origin.latitude * .pi / 180)
        let x = coordinates.map { ($0.longitude - origin.longitude) * metresPerDegreeLongitude }
        let y = coordinates.map { ($0.latitude - origin.latitude) * Self.metresPerDegree }
        let edgeCount = max(0, coordinates.count - 1)
        chunks = stride(from: 0, to: edgeCount, by: Self.chunkSize).map { start in
            let edges = start..<min(start + Self.chunkSize, edgeCount)
            let points = edges.lowerBound...edges.upperBound
            return Chunk(
                edges: edges,
                minX: x[points].min()!, maxX: x[points].max()!, minY: y[points].min()!, maxY: y[points].max()!
            )
        }
        self.coordinates = coordinates
        self.origin = origin
        self.metresPerDegreeLongitude = metresPerDegreeLongitude
        self.x = x
        self.y = y
    }

    /// `coordinate` in the route's metre frame.
    func local(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        ((coordinate.longitude - origin.longitude) * metresPerDegreeLongitude,
         (coordinate.latitude - origin.latitude) * Self.metresPerDegree)
    }
}

/// What survives a relaunch (FR-013).
struct ProgressState: Codable, Equatable {
    /// Metres along the track.
    var travelled: Double
    /// Progress has been on the track well before the end, so reaching the end can count as finishing.
    var armed: Bool
    var finished: Bool
}

/// Chooses where along the track the user is (spec FR-004, research R2).
struct TrackProgressTracker {
    static let onTrackRadius = 30.0
    static let windowBehind = 100.0
    static let windowAhead = 300.0
    static let backwardWeight = 0.5
    static let forwardWeight = 0.5
    static let oppositeDirectionCost = 40.0
    static let directionBaseline = 10.0
    static let smoothingCount = 5
    static let historyCount = 20
    static let finishTolerance = 15.0
    /// How far the distance must rise within a run before a fall starts a new pass; ignores jitter along a leg.
    static let passSplitRise = 5.0

    let route: TrackRoute
    /// `nil` until established.
    private(set) var state: ProgressState?

    /// High-water mark: walking back below it costs more than continuing (turnarounds).
    private var highWater = 0.0
    private var wasOnTrack = false
    private var recentFixes: [(x: Double, y: Double)] = []
    private var smoothedHistory: [(x: Double, y: Double)] = []
    /// Radians in the route frame; kept until the user has moved `directionBaseline` again.
    private var movementDirection: Double?

    private var armDistance: Double { min(200, route.length / 2) }

    init(route: TrackRoute, restoring restored: ProgressState? = nil) {
        self.route = route
        state = restored
        highWater = restored?.travelled ?? 0
    }

    /// Distance travelled for this fix; remaining is `route.length` minus it.
    mutating func update(_ coordinate: CLLocationCoordinate2D) -> Double {
        // Core Location never sends these, but a NaN would leave no candidates below.
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return state?.travelled ?? 0 }
        let user = route.local(coordinate)
        updateDirection(user)
        guard route.edgeCount > 0 else { return 0 }
        if let state, state.finished { return route.length }

        let nearest = nearestDistance(to: user)
        let onTrack = nearest <= Self.onTrackRadius
        // Spec "Near the user": within 30 m on the track, within d + 30 m off it.
        let candidates = scan(user, within: onTrack ? Self.onTrackRadius : nearest + Self.onTrackRadius)
        defer { wasOnTrack = onTrack }

        guard var current = state else {
            let x = candidates.passes[0].along
            if onTrack {
                state = ProgressState(travelled: x, armed: x < route.length - armDistance, finished: false)
                highWater = x
            }
            return x
        }

        let previous = current.travelled
        var x: Double
        // Off the track every candidate is further than 30 m, so the window is empty.
        if let best = candidates.onTrack.filter({ inWindow($0, around: previous) })
            .min(by: { cost($0, previous) < cost($1, previous) }) {
            x = best.along
        } else {
            x = candidates.passes.min { abs($0.along - previous) < abs($1.along - previous) }!.along
        }
        if onTrack, wasOnTrack, current.armed, previous >= route.length - armDistance,
           x >= route.length - Self.finishTolerance {
            x = route.length
            current.finished = true
        }
        if onTrack, x < route.length - armDistance { current.armed = true }
        current.travelled = x
        if x > highWater || x < highWater - Self.windowBehind { highWater = x }
        state = current
        return x
    }

    // MARK: - Matching

    private struct Projection {
        let edge: Int
        let distance: Double
        let along: Double
    }

    /// Squared distance from the user to the closest point of edge `i`, and how far along the edge it is (0...1).
    private static func closest(
        onEdge i: Int, _ xs: UnsafeBufferPointer<Double>, _ ys: UnsafeBufferPointer<Double>, to user: (x: Double, y: Double)
    ) -> (squared: Double, t: Double) {
        let ax = xs[i] - user.x, ay = ys[i] - user.y
        let dx = xs[i + 1] - xs[i], dy = ys[i + 1] - ys[i]
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared > 0 ? min(1, max(0, -(ax * dx + ay * dy) / lengthSquared)) : 0
        let px = ax + t * dx, py = ay + t * dy
        return (px * px + py * py, t)
    }

    private func boxDistanceSquared(_ chunk: TrackRoute.Chunk, _ user: (x: Double, y: Double)) -> Double {
        let dx = max(chunk.minX - user.x, 0, user.x - chunk.maxX)
        let dy = max(chunk.minY - user.y, 0, user.y - chunk.maxY)
        return dx * dx + dy * dy
    }

    /// Visits chunks nearest box first, so a good bound is found early and the rest of the track is skipped.
    private func nearestDistance(to user: (x: Double, y: Double)) -> Double {
        let boxes = route.chunks.indices
            .map { (squared: boxDistanceSquared(route.chunks[$0], user), chunk: $0) }
            .sorted { $0.squared < $1.squared }
        // Buffers keep the per-edge loop cheap in Debug builds too; it runs on the main actor once per fix.
        return route.x.withUnsafeBufferPointer { xs in
            route.y.withUnsafeBufferPointer { ys in
                var best = Double.infinity
                for box in boxes {
                    if box.squared >= best { break }
                    for i in route.chunks[box.chunk].edges {
                        best = min(best, Self.closest(onEdge: i, xs, ys, to: user).squared)
                    }
                }
                return best.squareRoot()
            }
        }
    }

    /// Edges within `limit` of the user, in file order: the on-track ones (for the window) and one closest point per pass.
    /// A pass is a run of consecutive edges, split where the distance has risen by more than `passSplitRise` and
    /// falls again, so the two legs of a turnaround are separate passes. Passes are built while scanning, so a user
    /// off the track inside a big loop (every edge nearly as close) doesn't build a list of the whole track.
    private func scan(_ user: (x: Double, y: Double), within limit: Double) -> (onTrack: [Projection], passes: [Projection]) {
        let limitSquared = limit * limit
        let onTrackSquared = Self.onTrackRadius * Self.onTrackRadius
        return route.x.withUnsafeBufferPointer { xs in
            route.y.withUnsafeBufferPointer { ys in
                route.cumulative.withUnsafeBufferPointer { cumulative in
                    var onTrack: [Projection] = []
                    var passes: [Projection] = []
                    var previous: Projection?
                    var rising = false
                    for chunk in route.chunks where boxDistanceSquared(chunk, user) <= limitSquared {
                        for i in chunk.edges {
                            let (squared, t) = Self.closest(onEdge: i, xs, ys, to: user)
                            guard squared <= limitSquared else { continue }
                            let along = cumulative[i] + t * (cumulative[i + 1] - cumulative[i])
                            let p = Projection(edge: i, distance: squared.squareRoot(), along: along)
                            if squared <= onTrackSquared { onTrack.append(p) }
                            if let last = previous, p.edge == last.edge + 1, !(rising && p.distance < last.distance) {
                                if p.distance > passes[passes.count - 1].distance + Self.passSplitRise { rising = true }
                                if p.distance < passes[passes.count - 1].distance { passes[passes.count - 1] = p }
                            } else {
                                passes.append(p)
                                rising = false
                            }
                            previous = p
                        }
                    }
                    return (onTrack, passes)
                }
            }
        }
    }

    private func inWindow(_ p: Projection, around previous: Double) -> Bool {
        route.cumulative[p.edge + 1] >= previous - Self.windowBehind
            && route.cumulative[p.edge] <= previous + Self.windowAhead
    }

    private func cost(_ p: Projection, _ previous: Double) -> Double {
        var value = p.distance
            + Self.backwardWeight * max(0, highWater - p.along)
            + Self.forwardWeight * max(0, p.along - previous)
        if let movementDirection {
            let edgeDirection = atan2(route.y[p.edge + 1] - route.y[p.edge], route.x[p.edge + 1] - route.x[p.edge])
            // One-sided: turns up to 90° cost nothing; a leg running the opposite way costs up to the full amount.
            value += Self.oppositeDirectionCost * max(0, -cos(edgeDirection - movementDirection))
        }
        return value
    }

    // MARK: - Direction

    /// Direction from the latest smoothed position at least `directionBaseline` back; needs no minimum speed.
    private mutating func updateDirection(_ user: (x: Double, y: Double)) {
        recentFixes.append(user)
        if recentFixes.count > Self.smoothingCount { recentFixes.removeFirst() }
        let n = Double(recentFixes.count)
        let smoothed = (x: recentFixes.map(\.x).reduce(0, +) / n, y: recentFixes.map(\.y).reduce(0, +) / n)
        if let origin = smoothedHistory.last(where: { hypot(smoothed.x - $0.x, smoothed.y - $0.y) >= Self.directionBaseline }) {
            movementDirection = atan2(smoothed.y - origin.y, smoothed.x - origin.x)
        }
        smoothedHistory.append(smoothed)
        if smoothedHistory.count > Self.historyCount { smoothedHistory.removeFirst() }
    }
}
