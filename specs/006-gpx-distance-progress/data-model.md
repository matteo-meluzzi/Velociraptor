# Data Model: Distance Travelled and Remaining

## TrackRoute (new, value type)

The track flattened for along-track measurement.

| Field | Type | Notes |
|---|---|---|
| `coordinates` | `[CLLocationCoordinate2D]` | All segment points in file order. Segment gaps become edges (R1) |
| `cumulative` | `[Double]` | Metres from the start to each point; `cumulative[0] == 0` |
| `length` | `Double` | `cumulative.last`; 0 for a single point |

Built from `Track` once per load or import, off the main actor together with `TrackGeometry`.

## ProgressState (new, Codable, Equatable)

What survives a relaunch (FR-013).

| Field | Type | Notes |
|---|---|---|
| `travelled` | `Double` | Metres along the track of the established progress position |
| `armed` | `Bool` | Progress has been established more than `min(200, length/2)` before the end (Definitions, Finished) |
| `finished` | `Bool` | Latched by FR-004f |

## TrackProgressTracker (new, value type)

| Member | Notes |
|---|---|
| `init(route: TrackRoute, restoring: ProgressState? = nil)` | A restored state counts as established |
| `mutating func update(_ coordinate: CLLocationCoordinate2D) -> Double` | Returns the distance travelled for this fix; remaining = `route.length − travelled` |
| `var state: ProgressState?` | `nil` until established |

Internal working state (not part of the contract): previous position, high-water mark, whether the user was on the track at the previous fix, the recent fixes, the smoothed-position history and the movement direction.

**State transitions**:
- not established → established: first fix with `dmin ≤ 30 m`, or restoring a state.
- established → finished: FR-004f conditions (R2 step 6).
- finished is terminal until the tracker is replaced. A new import or closing the track replaces it.

## TrackDistances (new, Equatable)

Published by `TrackViewModel`; `nil` when no track is loaded.

| Field | Type | Example |
|---|---|---|
| `done` | `String` | `"3.47"`, `"128.1"`, `"—"` |
| `left` | `String` | `"1.53"`, `"—"` |

## TrackStoring (modified)

Adds `loadProgress() -> ProgressState?`, `saveProgress(_ state: ProgressState)` and `clearProgress()`.
- `TrackViewModel.show()` calls `clearProgress()` for imports, on the main actor (research R4).
- `clear()` removes both files.
- An unreadable progress file loads as `nil` and is removed.
