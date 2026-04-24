# Tasks: Altitude Display

**Input**: Design documents from `specs/002-altitude-display/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ quickstart.md ✅

**Organization**: Tasks are grouped by phase. One user story (P1).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[US1]**: Belongs to User Story 1 — View Altitude While Tracking Speed

---

## Phase 1: Foundational (Blocking Prerequisites)

**Purpose**: Extend the `LocationProviding` protocol and its conformers to publish altitude. These three tasks must be **committed atomically** — any intermediate state fails to build (constitution Principle I).

**⚠️ CRITICAL**: No US1 work can begin until this phase is complete.

- [ ] T001 Add `altitudePublisher: AnyPublisher<Double?, Never>` to the protocol in `Velociraptor/LocationProviding.swift`
- [ ] T002 [P] Add `altitudeSubject` (`CurrentValueSubject<Double?, Never>(nil)`), implement `altitudePublisher`, send `locations.last?.altitude` in `didUpdateLocations`, and send `nil` to `altitudeSubject` in `didFailWithError` (alongside existing `speedSubject.send(nil)`) in `Velociraptor/LocationManager.swift`
- [ ] T003 [P] Add `altitudeSubject` (`CurrentValueSubject<Double?, Never>(nil)`), implement `altitudePublisher`, and add `func send(altitude: Double?)` helper to `MockLocationProvider` in `VelociraptorTests/SpeedViewModelTests.swift`

**Checkpoint**: Build must pass (`xcodebuild build`) before proceeding. T001 + T002 + T003 committed in one atomic commit.

---

## Phase 2: User Story 1 — View Altitude While Tracking Speed (Priority: P1) 🎯 MVP

**Goal**: Display real-time GPS altitude in meters below the speed value. Font visibly smaller than speed. Unit hardcoded to "m". Placeholder "– m" when no fix.

**Independent Test**: Open the app (or inject a simulator location) and observe altitude in meters appearing below "km/h", updating in real time, always showing "m".

### Implementation

- [ ] T004 [P] [US1] Merge `SpeedViewModel` into `Velociraptor/SpeedView.swift` (move the class definition to the top of the file), remove the two `Spacer()` calls from `SpeedView.body` (layout moves to app root), then delete `Velociraptor/SpeedViewModel.swift`
- [ ] T005 [P] [US1] Create `Velociraptor/AltitudeView.swift` containing `AltitudeViewModel` (ObservableObject, `@Published var displayAltitude: String = "– m"`, subscribes to `locationProvider.altitudePublisher`, formats as `"\(Int(altitude.rounded())) m"` or `"– m"` for nil) and `AltitudeView` (renders `Text(viewModel.displayAltitude)` with `.font(.title2)`, `.foregroundStyle(.secondary)`, `.monospacedDigit()`)
- [ ] T006 [US1] Delete `Velociraptor/ContentView.swift` and update `Velociraptor/VelociraptorApp.swift`: create one shared `LocationManager`, instantiate `SpeedViewModel` and `AltitudeViewModel` as `@StateObject` using explicit `StateObject(wrappedValue:)` init, and replace `ContentView()` in `WindowGroup` with a `VStack(spacing: 8) { Spacer(); SpeedView(...); AltitudeView(...); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)` (depends on T004, T005)
- [ ] T007 [P] [US1] Create `VelociraptorTests/AltitudeViewModelTests.swift` with `@MainActor` test struct covering: nil → "– m" placeholder, positive altitude (e.g. 52.4 → "52 m"), negative altitude (e.g. -3.7 → "-4 m"), nil → real reading transition ("– m" then "52 m")

**Checkpoint**: Build passes, all tests pass, altitude appears below speed in simulator with correct font size and "m" unit always present.

---

## Phase 3: Polish & Verification

**Purpose**: Final validation against the acceptance checklist.

- [ ] T008 Verify build is clean: `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] T009 Verify all tests pass: `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] T010 Run through the acceptance checklist in `specs/002-altitude-display/quickstart.md` on simulator (inject location via Features → Location → Custom Location to verify altitude value updates and placeholder shows without a fix)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational)**: No dependencies — start immediately
- **Phase 2 (US1)**: Depends on Phase 1 completion (T001–T003 all done and committed)
- **Phase 3 (Polish)**: Depends on Phase 2 completion

### Within Phase 2

- T004 and T005 are independent (different files) — run in parallel
- T006 depends on T004 and T005 (needs both SpeedView and AltitudeView to exist)
- T007 is independent of T006 — can run in parallel with T006

### Parallel Opportunities

```
Phase 1 (run together, commit atomically):
  T001 → LocationProviding.swift
  T002 → LocationManager.swift          [P]
  T003 → SpeedViewModelTests.swift      [P]

Phase 2 (after Phase 1 committed):
  T004 → SpeedView.swift + delete SpeedViewModel.swift   [P]
  T005 → AltitudeView.swift (new)                        [P]
  T007 → AltitudeViewModelTests.swift (new)              [P]
  T006 → VelociraptorApp.swift (after T004 + T005)
```

---

## Implementation Strategy

### MVP (single story — this entire feature is MVP)

1. Complete Phase 1 atomically (T001 + T002 + T003, one commit)
2. Complete T004 + T005 + T007 in parallel
3. Complete T006
4. Complete Phase 3 verification

---

## Notes

- T001 + T002 + T003 **must be committed in a single atomic commit** — any intermediate state will fail to build
- `.monospacedDigit()` is required on `AltitudeView`'s text to prevent layout jitter as digit count changes
- `didFailWithError` in `LocationManager` must nil-out **both** `speedSubject` and `altitudeSubject`
- Each task completion requires: build ✅ → tests ✅ → reviewer agent on `git diff` ✅ (constitution Principles I–IV)
