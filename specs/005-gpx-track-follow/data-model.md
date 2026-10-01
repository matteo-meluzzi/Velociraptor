# Data Model: Follow a GPX Track

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

All types are value types unless noted. Coordinates are WGS84 degrees; distances are metres; headings are degrees clockwise from true north, normalised to `0..<360`.

## Track (spec Key Entity "Track")

```swift
struct TrackPoint: Codable, Equatable { let latitude: Double; let longitude: Double }
struct TrackSegment: Codable, Equatable { let points: [TrackPoint] }      // ≥ 1 point
struct Track: Codable, Equatable {
    let name: String                // never empty
    let segments: [TrackSegment]    // ≥ 1 segment
}
```

Derived (computed, not stored): `start` = first point of first segment; `finish` = last point of last segment; `isLoop` = distance(start, finish) ≤ 20 m (one combined marker, FR-008a).

**Validation** (applied by `GPXParser`, so every `Track` in the app is valid):

| Rule | Source |
|---|---|
| `latitude` finite and in −90…90, `longitude` finite and in −180…180; otherwise the point is dropped | Edge case "missing or out-of-range coordinates" |
| Empty segments are dropped; a track with no segments is rejected | FR-004 |
| Track points (`trk/trkseg/trkpt`) win; route points (`rte/rtept`) are used only if there are no valid track points; waypoints never | FR-003, edge cases |
| Each `trkseg` (or each `rte`) is one segment; segments are not joined | Definitions "Track line" |
| Name: `trk/name` → `metadata/name` (1.1) / `gpx/name` (1.0) → file name without extension | Key Entities |

## GPXImportError

```swift
enum GPXImportError: Error, Equatable { case unreadable, noTrackPoints }
```

Both map to the one user message in [contracts/ui.md](contracts/ui.md#messages).

## TrackGeometry (derived from a Track, built once per track)

| Field | Meaning |
|---|---|
| `segments: [[MKMapPoint]]` | projected points, same structure as the track |
| `chunks: [Chunk]` | runs of ≤ 256 consecutive points within one segment (consecutive chunks share their boundary point so no edge is lost) with `boundingRect: MKMapRect` |
| `cumulativeLength: [[Double]]` | per segment, map-point length from the segment start to each point (anchors chevron phase, R3) |

Operations (all pure, see [contracts/track-geometry.md](contracts/track-geometry.md)): `nearestPosition(to:)`, `intersects(_ area: VisibleArea)`, `chevrons(in:projection:spacing:)`.

## NearestTrackPosition

```swift
struct NearestTrackPosition: Equatable {
    let coordinate: CLLocationCoordinate2D  // anywhere on the line, not only at points
    let distance: Double                    // metres, geodesic, from the user's real position
    let bearing: Double                     // initial great-circle bearing user → coordinate
}
```

## LocationFix (from Core Location)

```swift
struct LocationFix: Equatable {
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: Double  // metres; < 0 means invalid → ignored by TrackViewModel (not turned into nil)
    let speed: Double               // m/s; < 0 means unknown
    let course: Double              // degrees; < 0 means unknown
}
```

Published as `LocationFix?` (`nil` = location unknown).

## CompassHeading

```swift
struct CompassHeading: Equatable {
    let trueHeading: Double       // < 0 when unavailable
    let magneticHeading: Double
    let accuracy: Double          // < 0 → heading invalid (needs calibration)
}
```

Published as `CompassHeading?` (`nil` = no compass / not started).

## MotionState and OrientationController (spec Definitions + Orientation table)

```swift
enum MotionState { case stationary, moving }
struct OrientationController {
    private(set) var motion: MotionState = .stationary
    private(set) var displayedHeading: Double = 0   // north-up until a heading is known
    mutating func update(fix: LocationFix?, compass: CompassHeading?)
}
```

### Motion transitions (km/h = speed × 3.6)

| Current | Speed | Next |
|---|---|---|
| any | unknown (< 0) or no fix | unchanged |
| stationary | ≥ 3 | moving |
| stationary | < 3 | stationary |
| moving | < 2 | stationary |
| moving | ≥ 2 | moving |

### Displayed heading

| Motion | Candidate heading | Result |
|---|---|---|
| moving | `fix.course` if ≥ 0 | candidate |
| moving | course unknown / no fix | unchanged (last shown; 0 if never) |
| stationary | `compass.trueHeading` if ≥ 0, else `magneticHeading`; only if `accuracy ≥ 0` | candidate |
| stationary | no compass / invalid accuracy | unchanged |

A candidate is applied only when its shortest angular distance from `displayedHeading` is ≥ 5° (US3-AS5 dead band).

## Viewport and TrackViewMode (spec Key Entity "Track view state")

```swift
struct Viewport: Equatable {
    var center: CLLocationCoordinate2D
    var width: Double    // metres across the shorter side of the map view; clamped to 100…20_000
    var heading: Double  // = OrientationController.displayedHeading
}
enum TrackViewMode { case following, browsing }
```

Constants: `defaultWidth = 1_000`, `minWidth = 100`, `maxWidth = 20_000`.

### Mode transitions

| Mode | Event | Next mode | Viewport effect |
|---|---|---|---|
| (no track) | track loaded (import or relaunch) | following | default view (see centre rule) |
| following | location fix | following | centre = fix |
| following | location becomes unknown after a fix was received | following | centre unchanged (last fix); message "unknown" |
| following | user zoom / pan gesture | browsing | centre, width = reported by the map |
| browsing | location fix | browsing | none |
| browsing | user zoom / pan | browsing | centre, width = reported |
| browsing | Re-centre tapped | following | default view |
| any | heading change | unchanged | heading = displayed heading |
| any | new track imported | following | default view |
| any | track closed | (no track) | — |

**Centre rule for the default view**: the latest fix received since the track was loaded, even if location is lost right now; if no fix has been received yet, or location access is denied/restricted, the track's start point (US1-AS9, FR-023).

## VisibleArea

```swift
struct VisibleArea {
    let mapSize: CGSize           // map view size in points
    let insets: EdgeInsets        // heights of the top panel / bottom bar (R11)
    let viewport: Viewport
}
```

Gives the visible rectangle in screen points and, through the viewport's projection, as a rotated rectangle in map points (`corners: [MKMapPoint]`). Used for "track in view" and arrow placement.

## OffTrackArrow (view-model output)

```swift
struct OffTrackArrow: Equatable {
    let bearing: Double          // degrees from north; the view subtracts the displayed heading
    let distanceText: String     // "850 m" | "2.4 km"
}
```

`nil` when there is no track, location unknown, or the track is in view.

## Persisted state

| What | Where | Written | Removed |
|---|---|---|---|
| Current `Track` (JSON) | `Application Support/CurrentTrack.json` | each successful import (atomic) | close track; unreadable at launch |

Mode, viewport and orientation are not persisted: a relaunch shows the default view (Edge case "App is relaunched").
