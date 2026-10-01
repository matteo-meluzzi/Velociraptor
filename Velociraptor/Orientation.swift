import Foundation

enum MotionState {
    case stationary, moving
}

/// Decides which way the top of the track view points (spec "Track View Orientation" table).
struct OrientationController {
    /// Moving from this speed up…
    static let movingSpeedKmh = 3.0
    /// …stationary below this one; in between the previous state is kept.
    static let stationarySpeedKmh = 2.0
    /// Smaller heading changes are ignored, so the view doesn't jitter.
    static let deadBand = 5.0

    private(set) var motion: MotionState = .stationary
    /// North-up until a heading is known.
    private(set) var displayedHeading: Double = 0

    mutating func update(fix: LocationFix?, compass: CompassHeading?) {
        if let fix, fix.speed >= 0 {
            let kmh = fix.speed * 3.6
            switch motion {
            case .stationary where kmh >= Self.movingSpeedKmh: motion = .moving
            case .moving where kmh < Self.stationarySpeedKmh: motion = .stationary
            default: break
            }
        }

        let candidate: Double? = switch motion {
        case .moving:
            fix.flatMap { $0.course >= 0 ? $0.course : nil }
        case .stationary:
            compass.flatMap { compass in
                guard compass.accuracy >= 0 else { return nil }
                return compass.trueHeading >= 0 ? compass.trueHeading : compass.magneticHeading
            }
        }
        if let candidate, Geo.angularDistance(candidate, displayedHeading) >= Self.deadBand {
            displayedHeading = Geo.normalized(candidate)
        }
    }
}
