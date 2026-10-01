# Implementation Plan: Follow a GPX Track

**Branch**: `005-gpx-track-follow` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-gpx-track-follow/spec.md`

## Summary

Add an "Import GPX track" button beside the heart rate monitor button. Picking a `.gpx` file (SwiftUI `.fileImporter`, imported UTType `com.topografix.gpx`) parses track points, or route points if there are none, with Foundation `XMLParser`. The parsed `Track` is saved as JSON in Application Support so it comes back after relaunch. While a track is loaded the screen becomes a full-screen MapKit street map (`MKMapView` in a `UIViewRepresentable`, since SwiftUI `Map` lacks custom per-frame overlays and gesture-start detection). It draws the track as an `MKMultiPolyline`, start/finish annotations, screen-space chevrons 60 pt (≈ 1 cm) apart, and the system blue dot with accuracy halo. Compact speed and heart rate panels sit on top.

A `@MainActor TrackViewModel` owns Following/Browsing, the target `Viewport` (centre, width 100 m–20 km, heading) and the off-track arrow. It is fed by the existing `LocationPublisher` (new `LocationFixBehavior`), a new `CompassHeadingPublisher`, the existing `AuthorizationStatusPublisher` and a `TrackStoring` store. The decisions are pure, unit-tested types: `GPXParser`, `TrackGeometry` (nearest track position, track-in-view, chevron layout), `OrientationController` (Moving/Stationary hysteresis, course vs compass, 5° dead band), `ArrowPlacement` and `DistanceFormat`. The map adapter only applies viewports and reports gestures and visible regions. The screen stays awake while the app is active.

## Technical Context

**Language/Version**: Swift 5 language mode (`SWIFT_VERSION = 5.0`), Xcode with iOS 18.2 SDK

**Primary Dependencies**: SwiftUI, Combine, MapKit, CoreLocation, UniformTypeIdentifiers, Foundation (`XMLParser`, `JSONEncoder`, `FileManager`). System frameworks only.

**Storage**: `Application Support/CurrentTrack.json` (current track; R13). No new `UserDefaults` keys.

**Testing**: Swift Testing (`@Test`, `#expect`). Pure types are tested by input/output tables ([contracts/](contracts/)). `TrackViewModel` is tested through its public interface with mocks at the Core Location boundary and the real `FileTrackStore` on a temp directory. `MKMapView`, compass and real GPS are verified manually ([quickstart.md](quickstart.md)).

**Target Platform**: iOS 18.2+, iPhone, portrait + landscape

**Project Type**: Native iOS app, single target with `fileSystemSynchronizedGroups`, so new files under `Velociraptor/` and `VelociraptorTests/` are picked up automatically

**Performance Goals**: 50,000-point track loaded and shown < 3 s; ≥ 55 fps while zooming, panning and rotating (SC-002). Orientation source switch ≤ 3 s (SC-005). Arrow within 5° (SC-004).

**Constraints**: Foreground only (no background location mode). No third-party code. The no-track speed screen is unchanged apart from the new button (FR-009). The heart rate behaviour is untouched. Works offline without the street map (FR-022).

**Scale/Scope**: 10 new production files, 4 modified, 1 new Info.plist + build setting, 7 new test files + fixtures

No NEEDS CLARIFICATION remain; all unknowns are resolved in [research.md](research.md) (R1–R16).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Build Integrity | PASS | Each task ends with `xcodebuild build` green before commit |
| II. Test Discipline | PASS | Every decision lives in a pure type or the view model, tested via public interface and observable outputs (contract tables). Doubles only at the Core Location boundary; storage tests use the real `FileTrackStore` on a temp directory. No test inspects private state or collaborators |
| III. Peer Review Before Commit | PASS | Reviewer agent on `git diff` before each commit |
| IV. Task Completion Gate | PASS | Each task closes only after reviewer sign-off |
| V. SwiftUI-First | PASS (justified) | All UI is SwiftUI except `MKMapView` in a `UIViewRepresentable` (R1, no SwiftUI equivalent for per-frame overlay sync and gesture-start detection) and `UIApplication.isIdleTimerDisabled` (R14, no SwiftUI API). See Complexity Tracking |
| VI. Plan Review Gate | PASS | Reviewer agent returned **APPROVED** (round 2, 2026-10-01) after the round 1 BLOCKED issues (gesture vs model viewport; location-lost rule) were fixed; round 2 nits applied |
| VII. Specification Review Gate | PASS | spec.md **APPROVED** by an independent reviewer, re-approved after `/speckit-clarify` (see [checklists/requirements.md](checklists/requirements.md)) |

**Post-design re-check**: The design adds no dependencies. Core Location and storage sit behind protocols, and MapKit stays inside one thin adapter, so every rule in the spec's tables has a pure, tested home. No new violations beyond the justified UIKit wrapper.

## Project Structure

### Documentation (this feature)

```text
specs/005-gpx-track-follow/
├── spec.md
├── plan.md                       # This file
├── research.md                   # Phase 0
├── data-model.md                 # Phase 1
├── quickstart.md                 # Phase 1
├── contracts/
│   ├── gpx-import.md             # parser + fixture table
│   ├── track-geometry.md         # nearest/in-view/chevrons/orientation/arrow tables
│   ├── track-view-model.md       # boundaries, guarantees V1–V17, adapter rules M1–M5
│   └── ui.md                     # identifiers, layout, messages, styling
├── checklists/requirements.md
└── tasks.md                      # Phase 2 (/speckit-tasks — not created here)
```

### Source Code

```text
Velociraptor/
├── Track.swift                    # NEW: TrackPoint, TrackSegment, Track (Codable), start/finish/isLoop
├── GPXParser.swift                # NEW: XMLParser-based parser, GPXImportError, UTType.gpx
├── Geo.swift                      # NEW: haversine distance, bearing, angle helpers, DistanceFormat, Viewport, VisibleArea
├── TrackGeometry.swift            # NEW: projected chunks, nearestPosition, intersects(VisibleArea), chevrons
├── Orientation.swift              # NEW: MotionState, OrientationController
├── TrackStore.swift               # NEW: TrackStoring, FileTrackStore
├── HeadingPublisher.swift         # NEW: CompassHeading, HeadingProviding, CompassHeadingPublisher
├── LocationPublisher.swift        # MODIFY: add LocationFix + LocationFixBehavior (existing types untouched)
├── TrackViewModel.swift           # NEW: TrackViewModel, TrackViewMode, OffTrackArrow, LocationMessage
├── TrackMapView.swift             # NEW: UIViewRepresentable MKMapView adapter + chevron layer + endpoint annotations
├── TrackView.swift                # NEW: TrackView (map + arrow + north indicator + re-centre + location message), ArrowPlacement
├── SpeedView.swift                # MODIFY: `compact` size option (44 pt digits)
├── HeartRateView.swift            # MODIFY: `compact` size option (72 pt gauge)
└── VelociraptorApp.swift          # MODIFY: wire TrackViewModel, import button, fileImporter, alert,
                                   #         track layout (ZStack + panels), idle timer on scenePhase, previews

Velociraptor-Info.plist            # NEW (repo root, outside synced group): UTImportedTypeDeclarations for com.topografix.gpx
Velociraptor.xcodeproj/project.pbxproj  # MODIFY: INFOPLIST_FILE = Velociraptor-Info.plist (Debug + Release, app target)

VelociraptorTests/
├── Fixtures/*.gpx                 # NEW: fixtures listed in quickstart (large-50k generated by a test helper, not committed)
├── GPXParserTests.swift           # NEW: contracts/gpx-import.md table
├── TrackGeometryTests.swift       # NEW: nearest, in-view, chevrons tables
├── OrientationControllerTests.swift # NEW: motion + heading tables
├── ArrowPlacementTests.swift      # NEW: placement + distance-text tables
├── FileTrackStoreTests.swift      # NEW: round-trip, clear, unreadable → nil (temp dir)
├── TrackViewModelTests.swift      # NEW: V1–V17
└── TrackTestDoubles.swift         # NEW: MockHeadingProvider, temp-directory helper, fixture builders, 50k-point generator

specs/005-gpx-track-follow/scripts/make-large-gpx.swift  # NEW: writes a 50k-point GPX to stdout for device test D6
```

**Structure Decision**: Keep the flat layout of `Velociraptor/` and `VelociraptorTests/` with one file per concern, matching features 001–004. Test fixtures are small inline strings where possible. Only file-based import tests use `Fixtures/`, copied to a temp directory at test time; the synchronized test group bundles them as resources. The 50k-point fixture is generated in code.

## Design

### Data flow

```text
CLLocationManager ──► LocationPublisher<LocationFixBehavior> ─┐  LocationFix?
CLLocationManager ──► CompassHeadingPublisher ────────────────┤  CompassHeading?
CLLocationManager ──► AuthorizationStatusPublisher ───────────┤  CLAuthorizationStatus
FileTrackStore (Application Support) ◄──────────────────────► │
                                                              ▼
                     TrackViewModel (@MainActor)
                       ├─ OrientationController (pure)  → viewport.heading
                       ├─ TrackGeometry (pure)          → arrow, track-in-view
                       ├─ GPXParser (pure, off-main)    ← importFile(url)
                       └─ @Published track, mode, viewport, arrow, userLocation, locationMessage, alertMessage
                                                              │
                     ContentView ─┬─ no track: existing VStack + [Import GPX track]
                                  └─ track:    ZStack
                                                ├─ TrackView
                                                │   ├─ TrackMapView (MKMapView adapter)
                                                │   │     applies viewport ▸ reports userChangedCamera / visibleAreaChanged
                                                │   │     draws MKMultiPolyline, endpoints, chevron layer (TrackGeometry.chevrons)
                                                │   ├─ off-track arrow (ArrowPlacement), north indicator, Re-centre, location message
                                                ├─ top panel: SpeedView(compact) + HeartRateView(compact)
                                                └─ bottom bar: Import · HR monitor · Close track
```

### Key decisions (details in [research.md](research.md))

- **Map** (R1–R3, R6): `MKMapView` adapter. MapKit renders the line and markers; chevrons are a screen-space layer updated in `mapViewDidChangeVisibleRegion`. The system blue dot provides the halo. Offline, MapKit's empty grid is the plain background.
- **Camera** (R4): width ↔ camera distance by measuring the live scale. Zoom limits via `cameraZoomRange`. Rotation and pitch gestures off. Heading animated 0.5 s.
- **Browsing** (R4, R5): gesture recognizer state at `regionWillChange` → `userChangedCamera` (at start and end). Programmatic changes are flagged and ignored. While a gesture is active the model is never applied. In Browsing, heading-only changes keep the map's own centre and distance (adapter rules M1–M5).
- **Location lost** (R8): before the first fix (or when access is denied), the view centres on the track start. If location is lost after a fix, the view stays on the last fix and shows a message.
- **Orientation** (R7): Moving ≥ 3 km/h, Stationary < 2 km/h. Course vs compass, last-known fallback, north initially. 5° dead band. `headingOrientation` follows the interface orientation.
- **Arrow** (R9): geodesic nearest position over all edges. Track-in-view by segment/rotated-rect intersection with chunk culling. Arrow at the visible-area edge. Text "N m" / "N.N km".
- **Import** (R10, R12): `.fileImporter` with `UTType.gpx`, security-scoped read, parse off-main. Failure → alert and the old track kept.
- **Persistence** (R13): JSON in Application Support. Unreadable → silently no track.
- **Screen on** (R14): `isIdleTimerDisabled = scenePhase == .active`, applied with `onChange(initial: true)`.
- **Frame budget** (R3, R16): chevrons use analytic projection with 2 pt subsampling. The view model re-publishes only changed values. The stored track is decoded off-main via `loadStoredTrack()`.
- **Layout** (R11): compact panels. Their measured heights become the map's overlay insets and define the visible area.

## Implementation Order

| # | Task | Depends on |
|---|---|---|
| 1 | `Track`, `GPXParser`, `UTType.gpx` + `GPXParserTests` (contract table) | — |
| 2 | `Geo` (incl. `DistanceFormat`, `Viewport`, `VisibleArea`), `TrackGeometry` (nearest, intersects, chevrons) + `TrackGeometryTests` | 1 |
| 3 | `OrientationController` + `OrientationControllerTests` | — |
| 4 | `TrackStoring` + `FileTrackStore` + `FileTrackStoreTests` | 1 |
| 5 | `LocationFix`/`LocationFixBehavior`, `HeadingProviding`/`CompassHeadingPublisher`; test doubles | — |
| 6 | `TrackViewModel` + `TrackViewModelTests` (V1–V17) | 1–5 |
| 7 | `Velociraptor-Info.plist` + `INFOPLIST_FILE`; Import button, `.fileImporter`, alert in `ContentView` (no-track layout); `loadStoredTrack()` from `.task`; idle timer on `scenePhase`; `make-large-gpx.swift` | 6 |
| 8 | `TrackMapView` adapter (camera, zoom range, gestures and rules M1–M5, polyline, endpoints, chevron layer, interface orientation → `setInterfaceOrientation`) + `ArrowPlacement` + tests; `TrackView` overlays | 2, 6 |
| 9 | Compact `SpeedView`/`HeartRateView`, track layout (ZStack, panels, insets, Close track in the bottom bar), landscape; previews with mock providers and a sample track | 7, 8 |
| 10 | Manual validation per [quickstart.md](quickstart.md) (simulator Q1–Q12, device D1–D10) | 9 |

Each task ends with build → test → reviewer sign-off → commit (Constitution I–IV).

## Risks

- **MapKit scale measurement** (R4): if the measured metres-per-point is briefly wrong before first layout, the first frame could be off-scale. Mitigation: apply the viewport only after the map has a non-zero size, then re-apply on size change.
- **Chevron layer sync**: `mapViewDidChangeVisibleRegion` is expected to fire every frame during animated camera changes. If animated heading changes lag, fall back to a `CADisplayLink` while an animation is running. Verified in D1/D6.
- **Gesture detection on iOS 18** (R5): if the recognizer-state check is unreliable, use the adapter's own simultaneous recognizers. Verified in Q7, Q12 and D10.
- **Compass in landscape**: wrong `headingOrientation` would rotate the view 90° off. Covered by Q11/D1 in landscape.
- **SC-002 on device only**: frame rate and load time cannot be measured in unit tests. Covered by D6 with a generated 50k-point fixture.
- **Screen-on battery cost** (FR-024): accepted by the spec. Background restores auto-lock.
- **Feature 004 regression**: the HR view gets only a size option. Existing 004 tests must stay green, and D8 checks it on device.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| `MKMapView` via `UIViewRepresentable` (Constitution V allows it where SwiftUI has no equivalent) | Chevrons must stay on the line at every zoom and frame (FR-008a). Zoom-only gestures must switch to Browsing at gesture start (FR-019). 50k points at ≥ 55 fps (SC-002) | SwiftUI `Map`: no custom overlay renderer, camera callbacks arrive a frame late (chevrons slide off the line), no gesture-start signal |
| `UIApplication.shared.isIdleTimerDisabled` | FR-024 keeps the screen on | No SwiftUI API exists |
