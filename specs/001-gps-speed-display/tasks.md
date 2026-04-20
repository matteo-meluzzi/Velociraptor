# Tasks: GPS Speed Display

**Input**: Design documents from `specs/001-gps-speed-display/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Organization**: Two user stories — US1 builds the static SwiftUI UI first; US2 wires in live GPS.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Shared type needed by both user stories before any UI or GPS code can be written.

- [ ] T001 Create `SpeedUnit` enum (String raw values `"km/h"` / `"mph"`, CaseIterable, `convert(from:)` method) in `Velociraptor/SpeedUnit.swift`

---

## Phase 2: User Story 1 — Static Speed UI (Priority: P1) 🎯 MVP

**Goal**: A polished SwiftUI speed screen driven by hardcoded data. No device or GPS required — verify entirely in Xcode Previews and simulator.

**Independent Test**: Launch in simulator → large number `"42"` visible with `"km/h"` label → tap toggle → label switches to `"mph"` and number updates.

- [ ] T002 [US1] Update `Velociraptor/ContentView.swift` to render `SpeedView` as its entire body (remove placeholder globe/text)
- [ ] T003 [US1] Create `Velociraptor/SpeedView.swift` — large speed number display, unit label (`SpeedUnit.rawValue`), unit toggle button; driven by `@State var speed: Double = 42.0` and `@State var unit: SpeedUnit = .kmh`
- [ ] T004 [P] [US1] Add `@Test` cases for `SpeedUnit.convert(from:)` (km/h and mph conversion) in `VelociraptorTests/SpeedViewModelTests.swift`

**Checkpoint**: SpeedView renders in Previews with hardcoded speed; unit toggle works; build and tests pass.

---

## Phase 3: User Story 2 — Live GPS Speed (Priority: P2)

**Goal**: The app displays the device's real GPS speed updated live. Shows `"– –"` when GPS is unavailable or signal is weak.

**Independent Test**: Run on simulator with GPX location file → speed number updates in real time → remove location simulation → display shows `"– –"`.

- [ ] T005 [US2] Add `NSLocationWhenInUseUsageDescription` key with usage description string to `Velociraptor/Info.plist`
- [ ] T006 [US2] Create `Velociraptor/LocationProviding.swift` — `LocationProviding` protocol with `speedPublisher: AnyPublisher<Double, Never>`, `authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never>`, `requestAuthorization()`, `startUpdatingLocation()`, `stopUpdatingLocation()`
- [ ] T007 [US2] Create `Velociraptor/LocationManager.swift` — `NSObject` subclass conforming to `CLLocationManagerDelegate` and `LocationProviding`; sets `desiredAccuracy = .bestForNavigation` and `activityType = .automotiveNavigation`; calls `requestWhenInUseAuthorization()` on init; publishes `rawSpeed` (Double, m/s) on each `didUpdateLocations` callback; handles `.denied` and `.restricted` authorization states
- [ ] T008 [US2] Create `Velociraptor/SpeedViewModel.swift` — `@MainActor final class` conforming to `ObservableObject`; injected `LocationProviding`; `@Published var displaySpeed: String` (formatted: 0 decimal places ≥ 10, 1 decimal place < 10, `"– –"` when speed < 0); `@Published var unit: SpeedUnit = .kmh`; `@Published var isLocationAvailable: Bool`
- [ ] T009 [US2] Update `Velociraptor/SpeedView.swift` to accept `@ObservedObject var viewModel: SpeedViewModel` instead of local `@State`; bind speed display to `viewModel.displaySpeed`, unit label to `viewModel.unit.rawValue`, toggle action to mutate `viewModel.unit`; show `"Location unavailable"` message when `!viewModel.isLocationAvailable`
- [ ] T010 [US2] Update `Velociraptor/ContentView.swift` to create `@StateObject var viewModel = SpeedViewModel(locationProvider: LocationManager())` and pass it to `SpeedView(viewModel: viewModel)`
- [ ] T011 [P] [US2] Add `@Test` cases for `SpeedViewModel` display formatting in `VelociraptorTests/SpeedViewModelTests.swift` — use `MockLocationProvider` injected via `LocationProviding`; cover: `"– –"` for `speed = -1`, `"3.2"` for `speed < 10/3.6`, `"87"` for `speed ≥ 10/3.6`, unit toggle updates `displaySpeed`

**Checkpoint**: App requests location permission on first launch; speed updates live; `"– –"` shown when GPS unavailable; all tests pass.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup.

- [ ] T012 Run full build and test suite to confirm both stories integrate cleanly: `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` then `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **US1 (Phase 2)**: Depends on T001 (`SpeedUnit`) — then T002, T003, T004 can start
- **US2 (Phase 3)**: Depends on US1 completion (T003 must exist before T009 updates it)
- **Polish (Phase 4)**: Depends on all phases complete

### Within Each User Story

- T002 before T003 (ContentView before SpeedView wiring)
- T006 before T007 (protocol before concrete implementation)
- T006 before T008 (protocol before ViewModel)
- T007, T008 before T009 (types must exist before SpeedView update)
- T009, T010 before T012 (all wiring before final validation)
- T004 and T011 are [P] — write anytime within their story phase

### Parallel Opportunities

- T004 can run in parallel with T002 and T003 (different files)
- T011 can run in parallel with T005–T010 (different files, pure logic test)
- T006 and T007 can run in parallel (different files, no mutual dependency)

---

## Parallel Example: User Story 2

```
Parallel batch A (can all start once US1 is done):
  Task T005: Add Info.plist key
  Task T006: Create LocationProviding.swift
  Task T011: Write SpeedViewModelTests.swift (mock-based, no impl needed)

Sequential after batch A:
  Task T007: Create LocationManager.swift  (needs T006)
  Task T008: Create SpeedViewModel.swift   (needs T006)

Sequential after T007 + T008:
  Task T009: Update SpeedView.swift
  Task T010: Update ContentView.swift
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: T001
2. Complete Phase 2: T002 → T003 → T004
3. **STOP and VALIDATE**: SpeedView renders correctly in Previews and simulator

### Full Feature

4. Complete Phase 3: T005–T011 (in dependency order above)
5. Complete Phase 4: T012

---

## Notes

- [P] tasks touch different files — safe to run in parallel
- Constitution gates apply after every task: build must pass, tests must pass, reviewer must approve before commit
- `MockLocationProvider` in T011 should conform to `LocationProviding` and expose a `Subject` to push test speed values
- Info.plist key (T005) is a hard requirement — the app crashes without it on `requestWhenInUseAuthorization()`
