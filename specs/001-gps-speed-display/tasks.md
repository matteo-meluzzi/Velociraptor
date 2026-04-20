# Tasks: GPS Speed Display

**Input**: Design documents from `specs/001-gps-speed-display/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Organization**: Two user stories — US1 builds the static SwiftUI UI first; US2 wires in live GPS.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: User Story 1 — Static Speed UI (Priority: P1) 🎯 MVP

**Goal**: A polished SwiftUI speed screen driven by hardcoded data. No device or GPS required — verify entirely in Xcode Previews and simulator.

**Independent Test**: Launch in simulator → large number `"151"` visible (42 m/s × 3.6) with `"km/h"` label.

- [X] T001 [US1] Update `Velociraptor/ContentView.swift` to render `SpeedView` as its entire body (remove placeholder globe/text)
- [X] T002 [US1] Create `Velociraptor/SpeedView.swift` — large speed number display, hardcoded `@State var speed: Double = 42.0`, converts to km/h inline (× 3.6), static `"km/h"` label

**Checkpoint**: SpeedView renders in Previews with hardcoded speed; build passes.

---

## Phase 2: User Story 2 — Live GPS Speed (Priority: P2)

**Goal**: The app displays the device's real GPS speed in km/h, updated live. Shows `"– –"` when GPS is unavailable or signal is weak.

**Independent Test**: Run on simulator with GPX location file → speed number updates in real time → remove location simulation → display shows `"– –"`.

- [ ] T003 [US2] Add `NSLocationWhenInUseUsageDescription` key with usage description string to `Velociraptor/Info.plist`
- [ ] T004 [US2] Create `Velociraptor/LocationProviding.swift` — `LocationProviding` protocol with `speedPublisher: AnyPublisher<Double, Never>`, `authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never>`, `requestAuthorization()`, `startUpdatingLocation()`, `stopUpdatingLocation()`
- [ ] T005 [US2] Create `Velociraptor/LocationManager.swift` — `NSObject` subclass conforming to `CLLocationManagerDelegate` and `LocationProviding`; sets `desiredAccuracy = .bestForNavigation` and `activityType = .automotiveNavigation`; calls `requestWhenInUseAuthorization()` on init; publishes `rawSpeed` (Double, m/s) on each `didUpdateLocations` callback; handles `.denied` and `.restricted` authorization states
- [ ] T006 [US2] Create `Velociraptor/SpeedViewModel.swift` — `@MainActor final class` conforming to `ObservableObject`; injected `LocationProviding`; `@Published var displaySpeed: String` (km/h: always 1 decimal place, e.g. `"87.4"`, `"– –"` when speed < 0); `@Published var isLocationAvailable: Bool`
- [ ] T007 [US2] Update `Velociraptor/SpeedView.swift` to accept `@ObservedObject var viewModel: SpeedViewModel`; bind speed display to `viewModel.displaySpeed`; show `"Location unavailable"` message when `!viewModel.isLocationAvailable`
- [ ] T008 [US2] Update `Velociraptor/ContentView.swift` to create `@StateObject var viewModel = SpeedViewModel(locationProvider: LocationManager())` and pass it to `SpeedView(viewModel: viewModel)`
- [ ] T009 [P] [US2] Add `@Test` cases for `SpeedViewModel` display formatting in `VelociraptorTests/SpeedViewModelTests.swift` — use `MockLocationProvider` injected via `LocationProviding`; cover: `"– –"` for `speed = -1`, `"3.2"` for low speed, `"87.4"` for higher speed

**Checkpoint**: App requests location permission on first launch; speed updates live in km/h; `"– –"` shown when GPS unavailable; all tests pass.

---

## Phase 3: Polish & Cross-Cutting Concerns

**Purpose**: Final validation.

- [ ] T010 Run full build and test suite: `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` then `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## Dependencies & Execution Order

- **US1 (Phase 1)**: No dependencies — done ✅
- **US2 (Phase 2)**: T004 before T005, T006; T005 + T006 before T007, T008; T009 is parallel
- **Polish (Phase 3)**: Depends on all phases complete

### Parallel Opportunities

- T003, T004, T009 can all start at the same time
- T005 and T006 can run in parallel (different files)

---

## Implementation Strategy

### Full Feature

1. Complete Phase 2: T003 → T004 → T005 + T006 → T007 → T008 (+ T009 in parallel)
2. Complete Phase 3: T010

---

## Notes

- [P] tasks touch different files — safe to run in parallel
- Constitution gates apply after every task: build must pass, tests must pass, reviewer must approve before commit
- `MockLocationProvider` in T009 should conform to `LocationProviding` and expose a `CurrentValueSubject` to push test speed values
- Info.plist key (T003) is a hard requirement — the app crashes without it on `requestWhenInUseAuthorization()`
