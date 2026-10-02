# Implementation Plan: Distance Travelled and Remaining Along the GPX Track

**Branch**: `006-gpx-distance-progress` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-gpx-distance-progress/spec.md`

## Summary

Show "Done" and "Left" distances along the loaded GPX track in a band covering 30–45% of the screen height, directly under the speed and heart rate panel. A new pure value type, `TrackProgressTracker`, flattens the track into one route. Segment gaps count toward its length. On each location fix it chooses a progress position with a cost-based matcher, which makes the behavioural FR-004a–f concrete (research R2). The matcher was prototyped and tuned in a simulation with noisy GPS before planning. `TrackViewModel` feeds it fixes, publishes formatted texts, and saves the tracker's small `ProgressState` through `TrackStoring`, so a relaunch restores it (FR-013). `ContentView` adds a `DistanceBand` view and moves the map's top inset below it (FR-012).

## Technical Context

**Language/Version**: Swift 5 language mode, Xcode with the iOS 18.2 SDK

**Primary Dependencies**: SwiftUI, Combine, CoreLocation, Foundation. No new frameworks.

**Storage**: `Application Support/CurrentTrackProgress.json`, a small JSON file next to `CurrentTrack.json` (feature 005)

**Testing**: Swift Testing. The tracker is tested on synthetic tracks built with the existing `offset()` and `makeTrack()` helpers, asserting on the distances it returns (behaviour, not internals). `TrackViewModel` is tested through its published texts with the existing mocks and a real `FileTrackStore` on a temp directory. A performance guard covers a 50,000-point track.

**Target Platform**: iOS 18.2+, iPhone, portrait and landscape

**Project Type**: Native iOS app, single target with synchronized groups, so new files are picked up automatically

**Performance Goals**: one tracker update on a 50,000-point track fits inside a frame (guard: < 16 ms best-of-5 on a Debug simulator build), because it runs on the main actor. No per-frame work: updates run per location fix (SC-004).

**Constraints**: Speed and heart rate behaviour unchanged (FR-011). The no-track screen is unchanged (US1-AS7).

**Scale/Scope**: 2 new production files (`TrackProgress.swift`, `DistanceBand.swift`), 4 modified (`TrackStore.swift`, `Geo.swift`, `TrackViewModel.swift`, `VelociraptorApp.swift`). 1 new test file, 3 extended.

No NEEDS CLARIFICATION remain (see [research.md](research.md)).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Build Integrity | PASS | `xcodebuild build` green before the commit |
| II. Test Discipline | PASS | The tracker is a pure value type tested only through `update(_:)` return values and `state`. View model tests assert on published texts and on what a fresh view model restores from the same store directory. No private state, no call-order assertions; the only doubles are the existing Core Location mocks |
| III. Peer Review Before Commit | PASS | Reviewer agent on `git diff` before the commit |
| IV. Task Completion Gate | PASS | Tasks close only after reviewer sign-off on the diff |
| V. SwiftUI-First | PASS | The band is pure SwiftUI |
| VI. Plan Review Gate | PENDING | Reviewer agent on this plan + research + data model before `/speckit-tasks` |
| VII. Specification Review Gate | PASS | spec.md **APPROVED** in independent review round 6 (see [checklists/requirements.md](checklists/requirements.md)) |

**Post-design re-check**: No new dependencies and no UIKit. All matching rules live in one pure type with a table of tests ([contracts/track-progress.md](contracts/track-progress.md)). PASS.

## Project Structure

### Documentation (this feature)

```text
specs/006-gpx-distance-progress/
├── spec.md
├── plan.md                    # This file
├── research.md                # Phase 0: R1–R8
├── data-model.md              # Phase 1
├── quickstart.md              # Phase 1: manual checks
├── contracts/
│   ├── track-progress.md      # tracker behaviour table P1–P22, formatting F1–F6
│   └── ui.md                  # band layout, identifiers, view-model guarantees D1–D12
├── checklists/requirements.md
└── tasks.md                   # Phase 2 (/speckit-tasks)
```

### Source Code

```text
Velociraptor/
├── TrackProgress.swift        # NEW: TrackRoute (flattened, cumulative metres), ProgressState (Codable), TrackProgressTracker
├── DistanceBand.swift         # NEW: SwiftUI band with "Done"/"Left" values
├── Geo.swift                  # MOD: DistanceFormat.progress(metres:) -> "3.47" / "128.1"
├── TrackStore.swift           # MOD: TrackStoring gains loadProgress/saveProgress/clearProgress; clear() drops both
├── TrackViewModel.swift       # MOD: owns a tracker, publishes `distances`, saves progress
└── VelociraptorApp.swift      # MOD: ContentView.trackLayout inserts the band; map top inset = band bottom

VelociraptorTests/
├── TrackProgressTests.swift   # NEW: contract table P1–P22
├── GeoTests.swift             # MOD: F1–F6
├── FileTrackStoreTests.swift  # MOD: progress round trip, cleared by new track / clear
├── TrackViewModelTests.swift  # MOD: D1–D12
└── PerformanceGuardTests.swift# MOD: 50k-point update guard
```

**Structure Decision**: The single app target as in features 001–005. The matcher sits beside `TrackGeometry` as another pure track type. It is separate from it because `TrackGeometry` works in map points for drawing, while progress needs metres along the track.

## Complexity Tracking

No violations.
