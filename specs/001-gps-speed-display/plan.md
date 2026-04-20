# Implementation Plan: GPS Speed Display

**Branch**: `001-gps-speed-display` | **Date**: 2026-04-20 | **Spec**: `specs/001-gps-speed-display/spec.md`
**Input**: Feature description — SwiftUI-first GPS speed display app

## Summary

Build a native iOS 18.2+ SwiftUI app that displays the device's current GPS speed in real time. The implementation follows a UI-first sequence: build a polished static speed screen first, then wire in a `CLLocationManager`-backed view model to supply live speed data.

## Technical Context

**Language/Version**: Swift 5.9 / Xcode 16, iOS 18.2 minimum deployment  
**Primary Dependencies**: Core Location (system framework — no external packages)  
**Storage**: N/A — no persistence required  
**Testing**: Swift Testing (`@Test` / `#expect`) for unit tests; XCTest for UI tests  
**Target Platform**: iOS 18.2+  
**Project Type**: Native iOS mobile app  
**Performance Goals**: GPS speed updates at CLLocationManager's default interval (~1 Hz); UI renders at 60 fps with no jank  
**Constraints**: Requires `NSLocationWhenInUseUsageDescription` in Info.plist; speed is unavailable indoors or when GPS signal is weak (display fallback)  
**Scale/Scope**: Single-screen app

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Build Integrity | ✅ PASS | All commits gated on `xcodebuild build` exit 0 |
| II. Test Discipline | ✅ PASS | All commits gated on `xcodebuild test` all-pass |
| III. Peer Review Before Commit | ✅ PASS | Reviewer agent sign-off required before every commit |
| IV. Task Completion Gate | ✅ PASS | Tasks marked done only after review approval |
| V. SwiftUI-First | ✅ PASS | All UI is pure SwiftUI; `CLLocationManagerDelegate` bridged via `NSObject` subclass only because SwiftUI has no native Location API |

No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-gps-speed-display/
├── plan.md          ← this file
├── research.md      ← Phase 0 output
├── data-model.md    ← Phase 1 output
├── quickstart.md    ← Phase 1 output
└── tasks.md         ← Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
Velociraptor/
├── VelociraptorApp.swift         # @main entry point (exists)
├── ContentView.swift             # Root view — delegates to SpeedView (exists, to be replaced)
├── SpeedView.swift               # Primary UI: large km/h speed readout
├── SpeedViewModel.swift          # ObservableObject — owns LocationManager, publishes speed
└── LocationManager.swift         # NSObject + CLLocationManagerDelegate wrapper

VelociraptorTests/
├── VelociraptorTests.swift       # Existing placeholder
└── SpeedViewModelTests.swift     # Unit tests for km/h display formatting

VelociraptorUITests/
├── VelociraptorUITests.swift     # Existing placeholder
└── SpeedDisplayUITests.swift     # UI test: speed label visible
```

**Structure Decision**: Single flat group inside the existing Xcode project. No sub-folders — the file count is small enough that grouping by type adds no value.

## Complexity Tracking

> No constitution violations — table not applicable.
