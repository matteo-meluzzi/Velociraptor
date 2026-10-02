# Tasks: Distance Travelled and Remaining Along the GPX Track

**Input**: Design documents from `specs/006-gpx-distance-progress/` (plan.md, spec.md, research.md, data-model.md, contracts/)

**Tests**: Included. The constitution (Principle II) and the contracts (P1–P22, F1–F6, D1–D12) require them. Tests assert on behaviour only: returned distances, `state`, published texts, and what a fresh view model restores.

**Gates**: Every task ends with `xcodebuild build` and `xcodebuild test` green. One reviewer agent reviews the full `git diff` before the commit (Principles I–IV).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

No setup: the app target uses synchronized groups, so new files are picked up automatically.

## Phase 2: Foundational (blocking)

- [x] T001 [P] Add `DistanceFormat.progress(metres:)` to `Velociraptor/Geo.swift`. It returns the number only: two decimals below 100 km, one decimal from 100 km, rounding first so 99,996 m gives "100.0", and clamping negative or NaN input to "0.00". Add tests F1–F6 to `VelociraptorTests/GeoTests.swift`
- [x] T002 [P] Extend `TrackStoring` in `Velociraptor/TrackStore.swift` with `loadProgress() -> ProgressState?`, `saveProgress(_:)` and `clearProgress()`.
  - Store the progress in `CurrentTrackProgress.json`.
  - An unreadable progress file loads as `nil` and is removed.
  - `clear()` removes both files; `save(_ track:)` does not touch progress.
  - Add round-trip, clear and unreadable-file tests to `VelociraptorTests/FileTrackStoreTests.swift`.
  - Requires `ProgressState` from T003 (define it first in `Velociraptor/TrackProgress.swift`).

## Phase 3: User Story 1 — See how far I've come and how far is left (P1) 🎯 MVP

**Goal**: The band shows Done/Left along the track on simple tracks.

**Independent test**: Import a straight track. A fix at the start shows 0.00 / length; a fix halfway shows the halves.

- [x] T003 [US1] Create `Velociraptor/TrackProgress.swift` with `TrackRoute`, `ProgressState: Codable, Equatable { travelled: Double; armed: Bool; finished: Bool }` and `TrackProgressTracker` implementing research R2 steps 1–7.
  - `TrackRoute` flattens the segments, with gaps counted.
  - Constants: on-track radius 30 m; window −100/+300 m; weights 0.5/0.5 (tuned in T011); one-sided direction cost 40; 10 m direction look-back over smoothed fixes; finish tolerance 15 m; `arm = min(200, length/2)`.
- [x] T004 [US1] Create `VelociraptorTests/TrackProgressTests.swift` with contract rows P1–P5, P13, P14, P17, the single-point track and the finished-stays-finished row, using `offset()`/`makeTrack()` from `TrackTestDoubles.swift`.
- [x] T005 [US1] In `Velociraptor/TrackViewModel.swift`:
  - Build the `TrackRoute` off the main actor with the geometry, and hold a `TrackProgressTracker`.
  - Publish `distances: TrackDistances?` (`done`/`left` strings; "—" while not established and no value is shown, per R7).
  - Feed every valid fix, including one already known when `show()` runs.
  - Save progress when it moved ≥ 5 m or `armed`/`finished` changed.
  - Restore progress in `loadStoredTrack()`.
  - Call `store.clearProgress()` inside `show()` for imports (main actor), and also in the detached import task before `store.save(track)`.
  - Set `distances = nil` on close.
- [x] T006 [US1] Add tests D1–D12 to `VelociraptorTests/TrackViewModelTests.swift`. For D12, send a fix after calling `importFile` but before awaiting it, and assert only on what a fresh view model restores.
- [x] T007 [US1] Create `Velociraptor/DistanceBand.swift`, a SwiftUI band per contracts/ui.md:
  - Labels "Done" and "Left".
  - Digits at `0.45 × band`, `minimumScaleFactor(0.85)`; "km" at half size; label size `max(11, 0.14 × band)`.
  - `regularMaterial` background.
  - Accessibility identifiers and labels as specified.
- [x] T008 [US1] In `ContentView.trackLayout` (`Velociraptor/VelociraptorApp.swift`), insert the band under the speed/heart rate panel with height `0.15 × screen.height`. Measure `topPanelBottom` from the band's bottom edge (FR-012). Add a preview with distances.
- [x] T009 [P] [US1] Add a 50,000-point tracker update guard (< 16 ms, best of 5) to `VelociraptorTests/PerformanceGuardTests.swift`

**Checkpoint**: US1 works on one-way tracks.

## Phase 4: User Story 2 — Correct progress on loops and out-and-back routes (P2)

**Goal**: Continuity on loops, out-and-backs, hairpins and crossings; correct finish.

**Independent test**: Walk an out-and-back in a test. Done increases from 0 to the length without jumping back.

- [x] T010 [US2] Add contract rows P6–P12, P15, P16 and P18–P22 to `VelociraptorTests/TrackProgressTests.swift`. Include the stationary-near-the-tip noise row from plan review round 2 (120 noisy fixes 50 m before the tip; travelled stays within 20 m of 4,950). Use seeded deterministic noise from a small linear congruential generator in the test file.
- [x] T011 [US2] Tune `Velociraptor/TrackProgress.swift` until T010 passes.
  - Keep the previous direction when no smoothed position qualifies.
  - Split passes at local maxima of `d`.
  - Record any constant changes in research.md R2.

## Phase 5: Polish

- [x] T012 Run the full build and tests, then spawn a reviewer agent on the full `git diff`. Address any blocking issues, then commit on `006-gpx-distance-progress`.
- [x] T013 [P] Check the manual simulator steps in `specs/006-gpx-distance-progress/quickstart.md`; record anything that can't be checked without a device.

## Dependencies

- T001 and T002 (with `ProgressState` from T003) come first.
- T003 → T004, T005. T005 → T006, T008. T007 → T008.
- US2 (T010–T011) depends on T003.
- T012 comes last.

## Parallel opportunities

T001 ∥ T002. T007 ∥ T005. T009 ∥ T006.

## Implementation strategy

1. The MVP is US1 (T001–T009): the band with correct values on one-way tracks.
2. US2 hardens the matcher for repeated passes. The algorithm already includes this logic from T003; US2 adds the tests and tuning.
