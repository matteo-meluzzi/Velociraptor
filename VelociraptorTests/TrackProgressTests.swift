import CoreLocation
import Testing
@testable import Velociraptor

/// Contract rows P1–P22 (specs/006-gpx-distance-progress/contracts/track-progress.md).
/// Tracks and walks are laid out in metres east/north of an origin; assertions are on returned distances only.
struct TrackProgressTests {
    private typealias Point = (east: Double, north: Double)

    private static let origin = CLLocationCoordinate2D(latitude: 45, longitude: 7)

    private static func coordinate(_ p: Point) -> CLLocationCoordinate2D {
        offset(offset(origin, metres: p.north, bearing: 0), metres: p.east, bearing: 90)
    }

    /// Points every `step` metres along the polyline through `corners`.
    private static func densify(_ corners: [Point], step: Double = 5) -> [Point] {
        var points = [corners[0]]
        for (a, b) in zip(corners, corners.dropFirst()) {
            let length = hypot(b.east - a.east, b.north - a.north)
            let count = max(1, Int((length / step).rounded()))
            for k in 1...count {
                let t = Double(k) / Double(count)
                points.append((a.east + (b.east - a.east) * t, a.north + (b.north - a.north) * t))
            }
        }
        return points
    }

    private static func route(_ segments: [[Point]]) -> TrackRoute {
        TrackRoute(track: Track(name: "Test", segments: segments.map { corners in
            TrackSegment(points: densify(corners).map {
                let c = coordinate($0)
                return TrackPoint(latitude: c.latitude, longitude: c.longitude)
            })
        }))
    }

    private static func route(_ corners: [Point]) -> TrackRoute { route([corners]) }

    /// Positions every `step` metres along a walk, with the distance walked so far.
    private static func walk(_ corners: [Point], step: Double = 1.4) -> [(point: Point, walked: Double)] {
        var result: [(Point, Double)] = [(corners[0], 0)]
        var walked = 0.0, carried = 0.0
        for (a, b) in zip(corners, corners.dropFirst()) {
            let length = hypot(b.east - a.east, b.north - a.north)
            var along = step - carried
            while along <= length {
                let t = along / length
                result.append(((a.east + (b.east - a.east) * t, a.north + (b.north - a.north) * t), walked + along))
                along += step
            }
            carried = length - (along - step)
            walked += length
        }
        return result
    }

    /// Deterministic noise in `-amplitude...amplitude` metres per axis (linear congruential generator).
    private struct Noise {
        var state: UInt64
        let amplitude: Double

        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return (Double(state >> 11) / Double(1 << 53) * 2 - 1) * amplitude
        }

        mutating func apply(_ p: Point) -> Point { (p.east + next(), p.north + next()) }
    }

    private struct Run {
        var travelled: [Double] = []
        var tracker: TrackProgressTracker

        var maxJump: Double { zip(travelled, travelled.dropFirst()).map { abs($1 - $0) }.max() ?? 0 }
        var last: Double { travelled.last ?? .nan }
    }

    private static func run(
        _ route: TrackRoute, _ walk: [(point: Point, walked: Double)], noise: Noise? = nil,
        restoring: ProgressState? = nil
    ) -> Run {
        var run = Run(tracker: TrackProgressTracker(route: route, restoring: restoring))
        var noise = noise
        for step in walk {
            var point = step.point
            if noise != nil { point = noise!.apply(point) }
            run.travelled.append(run.tracker.update(coordinate(point)))
        }
        return run
    }

    // MARK: Shapes

    private static let straight: [Point] = [(0, 0), (5000, 0)]
    private static let outAndBack: [Point] = [(0, 0), (5000, 0), (5000, 4), (0, 4)]
    private static let loop: [Point] = [(0, 0), (1000, 0), (1000, 1000), (0, 1000), (0, 0)]
    private static let hairpin: [Point] = [(0, 0), (2000, 0), (2000, 20), (0, 20)]
    private static let figureEight: [Point] = [(0, 0), (200, 200), (200, 0), (0, 200), (0, 0)]

    /// 1.5 km of 50 m legs alternating east and north/south (90° corners).
    private static let squareWave: [Point] = {
        var corners: [Point] = [(0, 0)]
        for k in 0..<30 {
            let last = corners[corners.count - 1]
            corners.append(k % 2 == 0 ? (last.east + 50, last.north) : (last.east, last.north + ((k / 2) % 2 == 0 ? 50 : -50)))
        }
        return corners
    }()

    /// 50 m legs at ±60° from east.
    private static func zigZag(legs: Int, legLength: Double = 50) -> [Point] {
        var corners: [Point] = [(0, 0)]
        for k in 0..<legs {
            let last = corners[corners.count - 1]
            let angle = (k % 2 == 0 ? 1.0 : -1.0) * .pi / 3
            corners.append((last.east + legLength * cos(angle), last.north + legLength * sin(angle)))
        }
        return corners
    }

    // MARK: US1 – one-way tracks

    @Test func p1StartOfTrackIsZeroAndLengthIsAlongTheTrack() {
        var tracker = TrackProgressTracker(route: Self.route(Self.straight))
        #expect(abs(tracker.route.length - 5000) < 50)
        #expect(abs(tracker.update(Self.coordinate((0, 0)))) < 5)
    }

    @Test func p2DistanceFollowsTheTrackNotAStraightLine() {
        // 4 km of zig-zag that only covers 2 km east; the 2 km point is 1 km east of the start.
        var tracker = TrackProgressTracker(route: Self.route(Self.zigZag(legs: 40, legLength: 100)))
        let twoKilometres = Self.zigZag(legs: 40, legLength: 100)[20]
        #expect(abs(tracker.update(Self.coordinate(twoKilometres)) - 2000) < 5)
    }

    @Test func p3WalkingForwardOnlyIncreases() {
        let run = Self.run(Self.route(Self.straight), Self.walk([(0, 0), (1000, 0)]))
        #expect(zip(run.travelled, run.travelled.dropFirst()).allSatisfy { $1 >= $0 })
        #expect(abs(run.last - 1000) < 5)
    }

    @Test func p4SidewaysGapIsNotCounted() {
        var tracker = TrackProgressTracker(route: Self.route(Self.straight))
        #expect(abs(tracker.update(Self.coordinate((1000, 20))) - 1000) < 5)
    }

    @Test func p5GapBetweenSegmentsCounts() {
        let route = Self.route([[(0, 0), (1000, 0)], [(1100, 0), (2000, 0)]])
        #expect(abs(route.length - 2000) < 20)
    }

    @Test func p13OffTheTrackUsesTheClosestPoint() {
        var tracker = TrackProgressTracker(route: Self.route(Self.straight))
        _ = tracker.update(Self.coordinate((1000, 0)))
        #expect(abs(tracker.update(Self.coordinate((1500, 200))) - 1500) < 5)
    }

    @Test func p14RejoiningElsewhereMovesThere() {
        var tracker = TrackProgressTracker(route: Self.route(Self.straight))
        _ = tracker.update(Self.coordinate((1000, 0)))
        #expect(abs(tracker.update(Self.coordinate((3000, 0))) - 3000) < 5)
    }

    @Test(arguments: [false, true])
    func p17CornersDoNotHoldProgressBack(zigZag: Bool) {
        let corners = zigZag ? Self.zigZag(legs: 30) : Self.squareWave
        let walk = Self.walk(corners)
        let run = Self.run(Self.route(corners), walk)
        let worstError = zip(run.travelled, walk).map { abs($0 - $1.walked) }.max()!
        let worstDecrease = zip(run.travelled, run.travelled.dropFirst()).map { $0 - $1 }.max()!
        #expect(worstError <= 20)
        #expect(worstDecrease <= 1)
        #expect(abs(run.last - run.tracker.route.length) < 1)
    }

    @Test func singlePointTrackIsAlwaysZero() {
        var tracker = TrackProgressTracker(route: Self.route([[(0, 0)]]))
        #expect(tracker.route.length == 0)
        #expect(tracker.update(Self.coordinate((0, 0))) == 0)
        #expect(tracker.update(Self.coordinate((300, 300))) == 0)
    }

    @Test func finishedStaysAtTheEnd() {
        let route = Self.route([(0, 0), (1000, 0)])
        var run = Self.run(route, Self.walk([(0, 0), (1000, 0)]))
        #expect(run.tracker.state?.finished == true)
        #expect(run.tracker.update(Self.coordinate((0, 0))) == route.length)
        #expect(run.tracker.update(Self.coordinate((500, 300))) == route.length)
    }

    // MARK: US2 – repeated passes

    @Test func p6LoopStartsAtZero() {
        var tracker = TrackProgressTracker(route: Self.route(Self.loop))
        #expect(tracker.update(Self.coordinate((0, 0))) < 5)
    }

    @Test func p7LoopFinishesAtItsLength() {
        let run = Self.run(Self.route(Self.loop), Self.walk(Self.loop))
        #expect(run.last == run.tracker.route.length)
        #expect(run.tracker.state?.finished == true)
        #expect(run.maxJump <= 60)
    }

    @Test(arguments: [0.7, 1.4])
    func p8OutAndBackCountsTheReturnLeg(speed: Double) {
        let walk = Self.walk(Self.outAndBack, step: speed)
        let run = Self.run(Self.route(Self.outAndBack), walk)
        let oneKilometreBack = zip(run.travelled, walk).first { $1.point.north == 4 && $1.point.east <= 1000 }!.0
        // The test helper's flat-earth offsets and the route's haversine lengths differ by about 0.1%.
        let expected = run.tracker.route.length * 9004 / 10004
        #expect(abs(oneKilometreBack - expected) < 10, "1 km back: \(oneKilometreBack), expected \(expected)")
        let firstWrong = zip(run.travelled, walk).first { $1.walked >= 5004 + 20 && $0 <= 5000 }
        #expect(firstWrong == nil, "on the way back: \(String(describing: firstWrong))")
        #expect(run.last == run.tracker.route.length, "last \(run.last)")
        #expect(run.maxJump <= 100, "jump \(run.maxJump)")
    }

    @Test(arguments: [0.0, 7, 13, 20])
    func p9TurningShortOfTheTipSwitchesToTheReturnLeg(short: Double) {
        let turn = 5000 - short
        let walk = Self.walk([(0, 0), (turn, 0), (turn, 2), (3000, 2)])
        let run = Self.run(Self.route(Self.outAndBack), walk)
        for (travelled, step) in zip(run.travelled, walk) where step.walked >= turn + 2 + 20 {
            #expect(travelled > 5000)
        }
        #expect(run.maxJump <= 100)
    }

    @Test func p10ShortBacktrackStaysOnTheSamePass() {
        let walk = Self.walk([(0, 0), (2000, 0), (1980, 0), (3000, 0)])
        let run = Self.run(Self.route(Self.outAndBack), walk)
        #expect(run.travelled.max()! <= 3005)
        let lowestAfterTwoKilometres = zip(run.travelled, walk).filter { $1.walked >= 2000 }.map(\.0).min()!
        #expect(abs(lowestAfterTwoKilometres - 1980) < 5)
    }

    @Test func p11LoopFirstFixOffTheTrackStartsAtZero() {
        let walk = Self.walk([(-28, -28), (0, 0), (100, 0)])
        let run = Self.run(Self.route(Self.loop), walk)
        #expect(run.travelled.max()! <= 110)
    }

    @Test func p12HairpinFollowsTheLegWalked() {
        let walk = Self.walk(Self.hairpin)
        let run = Self.run(Self.route(Self.hairpin), walk)
        let fiveHundredOnSecondLeg = zip(run.travelled, walk).first { $1.point.north == 20 && $1.point.east <= 1500 }!.0
        #expect(abs(fiveHundredOnSecondLeg - 2520) < 10)
        #expect(run.maxJump <= 60)
    }

    @Test func p15LoadedNearTheFinishDoesNotFinish() {
        var tracker = TrackProgressTracker(route: Self.route(Self.straight))
        _ = tracker.update(Self.coordinate((5300, 0)))
        _ = tracker.update(Self.coordinate((4980, 0)))
        _ = tracker.update(Self.coordinate((4995, 0)))
        #expect(tracker.state?.finished != true)
        #expect(tracker.update(Self.coordinate((0, 0))) < 5)
        #expect(tracker.state?.finished != true)
    }

    @Test func p16RestoredProgressKeepsTheReturnLeg() {
        var tracker = TrackProgressTracker(
            route: Self.route(Self.outAndBack), restoring: ProgressState(travelled: 6000, armed: true, finished: false)
        )
        #expect(abs(tracker.update(Self.coordinate((4000, 2))) - 6004) < 10)
    }

    @Test func p18CrossingKeepsThePassWalked() {
        let walk = Self.walk(Self.figureEight)
        let run = Self.run(Self.route(Self.figureEight), walk)
        let worstError = zip(run.travelled, walk).map { abs($0 - $1.walked) }.max()!
        #expect(worstError <= 20)
        #expect(run.maxJump <= 60)
    }

    @Test func p19LoopShortcutToTheStartGoesToTheFinish() {
        let walk = Self.walk([(0, 0), (1000, 0), (1000, 1000), (0, 1000), (300, 700), (30, 30), (0, 0)])
        let run = Self.run(Self.route(Self.loop), walk)
        #expect(abs(run.last - run.tracker.route.length) < 5)
    }

    @Test func p20GapOnTheReturnLegStaysOnIt() {
        var run = Self.run(Self.route(Self.outAndBack), Self.walk([(0, 0), (5000, 0), (5000, 4), (4000, 4)]))
        #expect(abs(run.tracker.update(Self.coordinate((2000, 3))) - 8004) < 10)
    }

    @Test func p21StrayOnTheReturnLegDoesNotJump() {
        let walk = Self.walk([(0, 0), (5000, 0), (5000, 4), (3000, 4), (3000, 44), (2500, 44), (2500, 4), (0, 4)])
        let run = Self.run(Self.route(Self.outAndBack), walk)
        let afterTurn = zip(run.travelled, walk).filter { $1.walked > 5200 }.map(\.0)
        #expect(zip(afterTurn, afterTurn.dropFirst()).map { abs($1 - $0) }.max()! <= 60)
        #expect(run.last == run.tracker.route.length)
    }

    // MARK: P22 – seeded GPS noise (±5 m per axis, independent per fix)

    @Test(arguments: [1, 2, 3] as [UInt64])
    func p22NoiseOutAndBack(seed: UInt64) {
        let run = Self.run(Self.route(Self.outAndBack), Self.walk(Self.outAndBack), noise: Noise(state: seed, amplitude: 5))
        #expect(run.maxJump <= 100)
        #expect(run.last == run.tracker.route.length)
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func p22NoiseEarlyTurnaround(seed: UInt64) {
        let walk = Self.walk([(0, 0), (4980, 0), (4980, 2), (0, 2)])
        let run = Self.run(Self.route(Self.outAndBack), walk, noise: Noise(state: seed, amplitude: 5))
        #expect(run.maxJump <= 100)
        #expect(run.last == run.tracker.route.length)
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func p22NoiseHairpinAndCorners(seed: UInt64) {
        for corners in [Self.hairpin, Self.squareWave] {
            let run = Self.run(Self.route(corners), Self.walk(corners), noise: Noise(state: seed, amplitude: 5))
            #expect(run.maxJump <= 60)
            #expect(run.last == run.tracker.route.length)
        }
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func standingStillNearTheTipStaysPut(seed: UInt64) {
        var run = Self.run(Self.route(Self.outAndBack), Self.walk([(0, 0), (4950, 0)]))
        // Harsher than the walks: ±8 m per axis, independent per fix.
        var noise = Noise(state: seed, amplitude: 8)
        for _ in 0..<120 {
            let travelled = run.tracker.update(Self.coordinate(noise.apply((4950, 0))))
            #expect(abs(travelled - 4950) <= 20)
        }
    }
}
