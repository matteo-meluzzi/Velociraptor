# Contract: Track geometry, orientation, arrow (pure types)

All pure, no MapKit views, no Core Location managers; `MKMapPoint` / `MKMapRect` and `CLLocationCoordinate2D` are plain value types.

```swift
struct TrackGeometry {
    init(track: Track)
    func nearestPosition(to coordinate: CLLocationCoordinate2D) -> NearestTrackPosition
    func intersects(_ area: VisibleArea) -> Bool
    /// Chevrons for the visible chunks, in screen points, `spacing` apart along the on-screen line.
    /// `project` is an analytic transform (centre, metres-per-point, heading); points < 2 pt from the last kept one are skipped.
    func chevrons(in area: VisibleArea, project: (MKMapPoint) -> CGPoint, spacing: CGFloat) -> [Chevron]
}
struct Chevron: Equatable { let position: CGPoint; let angle: Angle }  // angle = file-order direction on screen

enum Geo {
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double   // haversine, metres
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double // 0..<360
}

enum DistanceFormat { static func text(metres: Double) -> String }

enum ArrowPlacement {
    /// Point on the visible rectangle's edge (inset by `margin`) in the direction `screenAngle` (0 = up, clockwise).
    static func position(in visibleRect: CGRect, screenAngle: Double, margin: CGFloat = 32) -> CGPoint
}

struct OrientationController { /* see data-model.md */ }
```

## Guarantees and test tables

### Nearest position (`TrackGeometryTests`)

| Case | Expected |
|---|---|
| User exactly on a track point | distance ≈ 0 |
| User beside the middle of a 2 km straight edge, 300 m off | nearest is mid-edge (not an endpoint), distance 300 ± 1 m |
| Two segments, the second nearer | nearest on the second |
| Gap between segments | never on the imaginary line joining segments |
| Self-crossing / out-and-back track | the closest, regardless of order |
| User 2 km east of a north–south track | bearing 270 ± 5° (SC-004) |
| Single-point track | that point |

### Track in view

| Case | Expected |
|---|---|
| A track point inside the visible rect | true |
| Long edge crosses the visible rect, both ends outside (US2-AS4) | true |
| Track only under the top panel / bottom bar insets | false |
| Track outside, view rotated 45° so a corner now covers it | true |
| Gap between two segments crosses the view, segments outside | false |

### Distance text

| Metres | Text |
|---|---|
| 0.4 | "0 m" |
| 999.4 | "999 m" |
| 999.6 | "1.0 km" |
| 1000 | "1.0 km" |
| 2449 | "2.4 km" |
| 12_345 | "12.3 km" |

### Chevrons

| Case | Expected |
|---|---|
| Straight on-screen line of 600 pt, spacing 60 | 10 ± 1 chevrons, consecutive distance 60 ± 0.5 pt, angle = line direction in file order |
| Same track panned 37 pt | chevrons move with the line (same track positions), not re-phased |
| Line outside the visible area | none |
| Two segments | chevrons on both; none on the gap |

### Orientation

One test per row of the Motion transitions and Displayed heading tables in [data-model.md](../data-model.md#motionstate-and-orientationcontroller-spec-definitions--orientation-table), plus:

| Case | Expected |
|---|---|
| Speed 2.5 km/h after Stationary | stays Stationary (hysteresis) |
| Speed 2.5 km/h after Moving | stays Moving |
| Candidate 4° from displayed | not applied |
| Candidate 5° from displayed | applied |
| Displayed 358°, candidate 2° | 4° apart (wraps), not applied |
| Never had a heading, source unavailable | 0 (north) |

### Arrow placement

| Visible rect | Angle | Expected |
|---|---|---|
| 300×500 at origin, margin 32 | 0° | (150, 32) |
| same | 90° | (268, 250) |
| same | 180° | (150, 468) |
| same | 45° | on the right edge or top edge, inside the rect by 32 pt |
