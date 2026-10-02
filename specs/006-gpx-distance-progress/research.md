# Research: Distance Travelled and Remaining

## R1 — Along-track distances and segment gaps

**Decision**: Flatten all segments into one route in file order, so the straight gap from one segment's last point to the next segment's first point becomes an ordinary edge. Edge lengths use `Geo.distance` (haversine); `cumulative[i]` is the metres from the start to point `i`.

**Rationale**: The spec counts gaps (Definitions, Along-track distance). Haversine already underlies the arrow distance in feature 005; summing it per edge stays within 0.1% of the true length for any realistic point spacing (SC-001).

**Alternatives**: Map-point lengths from `TrackGeometry.cumulativeLength`, rejected because they are scaled by latitude and exclude the gaps.

## R2 — Progress matching algorithm (FR-004a–f)

**Decision**: A cost-based matcher with a search window, a high-water mark and a movement direction, all held in `TrackProgressTracker`. Revised after plan review round 1.

1. **Projection**: for every edge, project the user onto it in a local equirectangular metre frame around the user. Compute `cos(latitude)` once per fix, use squared distances, and take one square root per edge. This gives the sideways distance `d` and the along-track position `x`. `dmin` is the smallest `d`; "on the track" means `dmin ≤ 30`.
2. **Passes**: a pass is a maximal run of consecutive edges with `d ≤ dmin + 30`. Its representative is the run's minimum-`d` point. Taking the minimum, rather than "descending while d falls", is robust to zero-length edges from duplicate points.
3. **Not established** (FR-004b, and FR-004d before progress is established): use the first pass in file order. If on the track, progress becomes established, and it is armed when `x < length − arm`.
4. **Established**:
   - The window is the on-track edges (`d ≤ 30`) that overlap `[P − 100 m, P + 300 m]`, where `P` is the previous progress position.
   - **If the window has edges**: use the window edge with the lowest cost. Cost = `d + 0.5·max(0, H − x) + 0.5·max(0, x − P) + 40·max(0, −cos(edge bearing − movement direction))`. The forward weight was raised from 0.2 to 0.5 during implementation (step 5 note).
     - `H` is a high-water mark. It rises with `x`, and is reset to `x` when progress moves more than 100 m back.
     - The direction term is one-sided: turns up to 90° cost nothing, and an opposite leg costs up to 40. It applies only once a movement direction is known.
   - **Otherwise** (off the track, FR-004d; rejoining elsewhere, FR-004e; a GPS gap): use the pass whose representative `x` is closest to `P` along the track, for continuity. For example, a loop shortcut to the start/finish from `P ≈ 3,000` takes the finish.
5. **Movement direction** (no speed threshold, FR-004c, US2-AS8):
   - Smooth each fix as the mean of the last 5 fixes, and keep the last 20 smoothed positions.
   - The direction is the bearing from the most recent stored position at least 10 m from the current smoothed position, to the current one.
   - This sliding look-back flips about 10 m after a turnaround. When no stored position is 10 m away (standing still), the previous direction is kept.
   - Tuning (implementation, plan review round 2 note 1): with the first settings (3 fixes, 60 positions, forward weight 0.2), a user standing still 50 m before an out-and-back tip under σ = 5 m Gaussian noise drifted up to 122 m onto the return leg. With 5 fixes, 20 positions and forward weight 0.5 the drift fell to 18 m. The turnaround switch still came within 17 m of walking back, with jumps ≤ 74 m.
6. **Finished** (FR-004f, Definitions):
   - `arm = min(200, length/2)`. **Armed**: progress has been established on the track while `x < length − arm`.
   - **Finished**: the tracker is armed, the user was on the track at the previous fix with `P ≥ length − arm`, the user is on the track now, and the new `x ≥ length − 15 m`. The value then latches at the track length.
   - The 15 m tolerance is inside SC-002's 20 m and absorbs GPS noise at the finish.
7. **Restore** (FR-013): `P = H = travelled`, with the restored `armed`/`finished`. "On the track at the previous fix" starts false, so the first fix after a relaunch cannot finish.

**Rationale**:
- The high-water mark and backward penalty make walking back along the outbound leg cost more than continuing onto the return leg (US2-AS5).
- On a single pass the cost still allows going back, because `0.5 < 1` (US2-AS9).
- The window stops jumps to far-away passes (return legs, the end of a loop, distant hairpin legs).
- The one-sided direction term separates overlapping opposite legs near a bend (US2-AS7) without penalising corners on a single pass (SC-002).

**Evidence**:
- A Python prototype (scratch) ran three seeds at 1.4 and 0.7 m/s, with no noise and with 5 m independent noise per axis, which is harsher than Core Location.

| Scenario | No noise | 5 m noise |
|---|---|---|
| Turn 0/7/13/20 m short of the tip: switch to the return leg after walking back | ≤ 15 m | ≤ 15 m |
| Turnaround switch jump | ≤ 66 m | ≤ 88 m |
| 1.5 km zig-zag (60°) and square wave (90°): max error | 15 m (finish latch only) | 29 m |
| 1.5 km zig-zag and square wave: max decrease | 0.6 m | 20 m |
| Hairpin, legs 20 m apart: max jump | 16 m | 24 m |
| Figure-8 (self-crossing): max error | 15 m | 16 m |
| 40 m stray on the return leg: max jump | 15 m | 24 m |

- In every run, the loop finishes at its length and latches.
- Loop shortcut from 3 km: ends at the finish.
- A 1 km GPS gap on the return leg stays on the return leg.
- Restore at 6 km, then a fix at the 4 km mark: 6 km.
- Hotel 300 m/20 m from the finish, then the start: 0, not finished.

**Alternatives**:
- Purely geometric closest point: breaks on loops and out-and-backs.
- Per-pass candidates with a 90° direction filter: rejected in spec review rounds 1–2. Doubled-back stretches inside the radius give one candidate, and the filter needs the 3 km/h Moving state.
- HMM / Viterbi map matching: correct but heavy for a single feature with no road graph.

## R3 — Cost of a full scan per fix

**Decision** (as implemented): Precompute each point in metres in one local frame around the first point, and group edges into chunks of 64 with a bounding box. Per fix:
- Visit the chunks nearest box first, and stop once a box is further than the best edge found (`dmin`).
- Then project only the edges in chunks within the near limit.
- Compute an edge's direction only when costing window candidates.

**Rationale**:
- The update runs on the main actor, so it must fit well inside one frame to keep 55 fps (SC-004).
- 50,000 edges × a handful of multiply-adds is about 1 ms in Release.
- A guard test enforces < 16 ms (best of 5) on a Debug simulator build.
- Measured on the 50,000-point track: 10.4 ms with chunks visited in file order, 0.46 ms with nearest-box-first order.
- Worst case (code review): a user off the track at the centre of a 5 km-radius, 50,000-point loop, where every edge is almost equally near. It took 49 ms in Debug at first. Scanning through buffers and building passes during the scan brought it to about 23 ms in Debug, and it passes the 16 ms guard in a Release build. The Debug guard for this case is 100 ms, because it flaked at 50 ms under parallel test load. It is a regression guard; the frame budget is checked in Release.
- Passes are split only after the distance has risen by more than 5 m (`passSplitRise`), so jitter along a leg doesn't create many tiny passes. Turnaround legs still separate, because the distance rises well over 5 m around the tip.
- The metre frame is centred on the track's first point, not on the user (R2 step 1 describes the user's frame for clarity). Over a track hundreds of km north–south, the single `cos(latitude)` skews east–west sideways distances by a few percent at the far end. Along-track distances are unaffected (haversine).

## R4 — Persistence (FR-013)

**Decision**: `ProgressState { travelled: Double, armed: Bool, finished: Bool }` (Codable), stored in `CurrentTrackProgress.json`.
- `TrackStoring` gains `loadProgress() -> ProgressState?` and `saveProgress(_:)`.
- `clearProgress()` deletes the progress file; `clear()` deletes both files.
- **Import race (plan review B4)**: the view model calls `store.clearProgress()` on the main actor inside `show()` for an import, in the same step that replaces the tracker. Any save by the old tracker happens before that point, and the new tracker saves only after it. `save(_ track:)` leaves progress alone.
- The view model saves whenever progress is established and has moved at least 5 m, or `armed`/`finished` changed, since the last save. At walking speed (≥ 0.7 m/s) that keeps the saved value under 10 s old. Each save is a write of under 100 bytes.

**Alternatives**:
- Saving on every fix: needless writes.
- A timer: adds time injection to the tests.

## R5 — Formatting (FR-009)

**Decision**: `DistanceFormat.progress(metres:) -> String` returns the number only. Values below 100 km get two decimals, from 100 km one decimal; "km" is drawn separately and smaller (FR-008). The function rounds first, so 99,996 m gives "100.0", not "100.00". Negative or NaN input clamps to "0.00".

## R6 — Band layout and type size (FR-006–FR-008)

**Decision**: Band height = 0.15 × full screen height, placed directly under the 30% panel, with `regularMaterial` background like the panel.
- Each half is a `VStack` of label (size `max(11, 0.14·band)`) and an `HStack` of digits (rounded, semibold, monospaced, size `0.45·band`, `minimumScaleFactor(0.85)`, `lineLimit(1)`) plus "km" at half the digit size.
- The digit cap height is about 0.7 × the font size. 0.45 × 0.85 × 0.7 ≈ 0.27 of the band at the smallest scale, which meets FR-008.
- On an iPhone 16 in portrait the band is 128 pt, so the digits are a 58 pt font against the speed's 120 pt.
- "999.9 km" measures about 165 pt against a half-width of about 180 pt.
- `topPanelBottom` (the map's top inset) is measured from the band's bottom edge instead of the panel's (FR-012).

**Revision (2026-10-02, device feedback)**: on a real phone, "65.xx km" was cut to "65....". The number and "km" were separate `Text`s, so the number truncated on its own instead of scaling down. Now:
- digits are regular weight at `0.36·band`, so the cap height is about 0.25 of the band;
- shrinking only happens for values that would not fit otherwise;
- number and unit are one `Text` with `minimumScaleFactor(0.5)`.

## R7 — When values show "—" (FR-010)

**Decision**: The view model publishes `TrackDistances(done:left:)`, or `nil` when no track is loaded.
- "—" appears for both values while progress is not established (FR-010): no fix since the track was loaded, or the location lost before progress was established. Off-track values from before progress is established are shown while fixes arrive, and drop back to "—" if the location is lost.
- Once progress is established, losing the location keeps the last values.
- `show()` feeds an already-known fix to the new tracker immediately, so a stationary user sees values at once.
- Location access denied with a restored state shows the restored values.

## R8 — Single-point and zero-length tracks

**Decision**: `TrackRoute` with one point has length 0 and no edges. The tracker returns 0 for every fix, both values show "0.00", and progress never finishes. That is harmless, because the values cannot change.
