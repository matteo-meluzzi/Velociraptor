# Implementation Plan: Altitude Display

**Branch**: `002-altitude-display` | **Date**: 2026-04-24 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/002-altitude-display/spec.md`

## Summary

Add a real-time GPS altitude display (in meters, always) below the speed value in `SpeedView`. The altitude value flows from `CLLocation.altitude` through the existing MVVM pipeline: `LocationManager` publishes altitude, `SpeedViewModel` formats it, `SpeedView` renders it at a smaller font size than the speed.

**Note:** The user has since requested separate files for the altitude view. The plan has been updated accordingly — see Source Code section.

## Technical Context

**Language/Version**: Swift 5.9+, iOS 18.2+  
**Primary Dependencies**: SwiftUI, Combine, CoreLocation (all system frameworks — no third-party dependencies)  
**Storage**: N/A — altitude is a transient GPS value, not persisted  
**Testing**: Swift Testing framework (`@Test`, `#expect`) — same as existing test suite  
**Target Platform**: iOS 18.2+, iPhone  
**Project Type**: Native iOS mobile app  
**Performance Goals**: Altitude updates in sync with location updates (~1 Hz for navigation accuracy mode)  
**Constraints**: Offline-capable (GPS only, no network); UI must remain readable at all brightness/motion conditions  
**Scale/Scope**: Single screen addition — no new files required; all changes are additive to existing files

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Build Integrity | PASS | Protocol, `LocationManager`, and `MockLocationProvider` changes must land atomically in one commit to avoid a broken-build intermediate state |
| II. Test Discipline | PASS | Unit tests required for: nil→placeholder, positive altitude, negative altitude, nil→real-reading transition |
| III. Peer Review Before Commit | PASS | Reviewer agent required before any commit |
| IV. Task Completion Gate | PASS | Each task reviewed before marked done |
| V. SwiftUI-First | PASS | Only SwiftUI `Text` views added; no UIKit involved |

No violations. No Complexity Tracking required.

## Project Structure

### Documentation (this feature)

```text
specs/002-altitude-display/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (affected files)

```text
Velociraptor/
├── LocationProviding.swift     # Add altitudePublisher to protocol
├── LocationManager.swift       # Publish CLLocation.altitude via altitudeSubject;
│                               #   also send nil to altitudeSubject in didFailWithError
├── SpeedView.swift             # SpeedViewModel + SpeedView co-located; remove internal Spacers
├── AltitudeView.swift          # NEW — AltitudeViewModel + AltitudeView co-located
└── VelociraptorApp.swift       # Delete ContentView.swift; move root layout here

VelociraptorTests/
├── SpeedViewModelTests.swift   # Update MockLocationProvider with altitudePublisher
└── AltitudeViewModelTests.swift  # NEW — nil→placeholder, positive, negative, nil→real transition
```

**Structure Decision**: Single iOS app. Each view and its view model are co-located in the same file (`SpeedView.swift` contains both `SpeedViewModel` and `SpeedView`; `AltitudeView.swift` contains both `AltitudeViewModel` and `AltitudeView`). `ContentView` is deleted — it adds no logic and is just a passthrough. The shared `LocationManager` creation and root layout (`VStack` with `SpeedView` + `AltitudeView`) move directly into `VelociraptorApp.swift`'s `WindowGroup`. `SpeedViewModel.swift` is also deleted, its contents merged into `SpeedView.swift`.

## Implementation Notes

- **`didFailWithError` must nil-out both subjects**: `LocationManager.locationManager(_:didFailWithError:)` currently sends `nil` to `speedSubject` only. It must also send `nil` to `altitudeSubject`, otherwise a stale altitude reading persists on screen after a location error (violating FR-006).
- **`.monospacedDigit()` on altitude text**: Integer altitude values (e.g. `"99 m"` → `"100 m"`) cause layout jitter without this modifier. Apply it to the altitude `Text` in `AltitudeView`.
- **Atomic commit for protocol + conformers**: The `altitudePublisher` protocol addition, `LocationManager` implementation, and `MockLocationProvider` extension must all land in the same commit. Any intermediate state will fail to build (Principle I).
