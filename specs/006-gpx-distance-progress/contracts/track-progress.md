# Contract: TrackProgressTracker and DistanceFormat.progress

Tests feed coordinates built with `offset(origin, metres:, bearing:)` along synthetic tracks with points every 5 m, and assert on the values `update(_:)` returns and on `state`. "Walk" means fixes 1.4 m apart in order unless stated otherwise. Tolerances: ±5 m unless stated otherwise (noise-free tests). Every row asserts only on returned distances and `state`.

| ID | Spec | Given | When | Then |
|---|---|---|---|---|
| P1 | US1-AS2, SC-001 | straight 5 km track | fix at the start | travelled 0; `route.length` within 1% of 5,000 m |
| P2 | US1-AS4 | zig-zag track, 2 km along it, start–finish straight line 1 km | fix at the 2 km point | travelled ≈ 2,000 (not a straight-line value) |
| P3 | US1-AS5 | straight track | walk forward | travelled increases monotonically; travelled + remaining = length |
| P4 | US1-AS6, FR-005 | straight track | fix 20 m to the side of the 1 km point | travelled ≈ 1,000 |
| P5 | Along-track distance | 2 segments, 100 m gap | — | length = both segments + 100 m |
| P6 | US2-AS1 | 4 km loop (start = finish) | first fix at the start | travelled ≈ 0 |
| P7 | US2-AS2, FR-004f | 4 km loop | walk the whole loop | final travelled = length, `state.finished` |
| P8 | US2-AS3, US2-AS8, SC-003 | 5 km out-and-back, legs 4 m apart | walk it all at 0.7 m/s and at 1.4 m/s | at the 1 km mark on the way back, travelled ≈ 9,000; ends at length; within 20 m of walking back from the tip travelled > 5,000; no jump > 100 m |
| P9 | US2-AS5, SC-003 | same | turn 0, 7, 13, 20 m before the tip and walk back | within 20 m of walking back travelled > 5,000 and never ≤ 5,000 again; no jump > 100 m |
| P10 | US2-AS9 | same | at 2 km walk 20 m back, then forward | travelled dips ≈ 20 m, never > 3,000 |
| P11 | US2-AS6 | loop with the start at a corner | first fix off the track, 40 m diagonally outside the start corner (≈ 40 m from both legs), then walk to the start and 100 m along the track | travelled never exceeds 110 m (never near the track length) |
| P12 | US2-AS7 | hairpin, legs 20 m apart, 2 km each | walk it all | follows the leg: at 500 m on the second leg travelled ≈ 2,520; no jump > 60 m |
| P13 | FR-004d | straight track, established at 1 km | fix 200 m to the side of the 1.5 km point | travelled ≈ 1,500 |
| P14 | FR-004e | straight 5 km track, established at 1 km | fix on the track at 3 km | travelled ≈ 3,000 |
| P15 | US2-AS10, Finished | point-to-point track | first fixes 20 m and 300 m from the finish, then a fix at the start | at the start travelled ≈ 0; `state?.finished != true` |
| P16 | FR-013 | restoring `ProgressState(travelled: 6,000, armed: true, finished: false)` on the out-and-back | fix on the shared road at the 4 km mark | travelled ≈ 6,000 (return leg), not 4,000 |
| P17 | SC-002, US1-AS5 | 1.5 km square-wave track (50 m legs, 90° corners) and 60° zig-zag | walk it all | travelled within 20 m of the true distance at every fix; never decreases by more than 1 m |
| P18 | US2-AS4 | figure-8 crossing itself | walk it all | within 20 m of the truth at every fix; no jump > 60 m |
| P19 | FR-004e, edge case loop shortcut | 4 km loop, walked to 3 km | cut straight across to the start/finish and step onto it | travelled ≈ length (the finish, not 0) |
| P20 | FR-004c, FR-004d | out-and-back, walked onto the return leg | no fixes for 1 km, then a fix on the shared road at the 2 km mark | travelled ≈ 8,000 |
| P21 | SC-003 | out-and-back | on the return leg stray 40 m off for 500 m and come back | no jump > 60 m after the turnaround switch; ends at length |
| P22 | SC-003 under noise | P8, P9 (20 m), P12 and P17 with seeded deterministic noise (±5 m) | walk | no jump > 100 m at the turnaround, > 60 m elsewhere; all end at length |

Additional:
- Single-point track: length 0, every fix returns 0.
- A finished tracker stays at the length for any later fix (FR-004f, second lap).

## DistanceFormat.progress(metres:)

| ID | Input (m) | Output |
|---|---|---|
| F1 | 0 | `0.00` |
| F2 | 3,474 | `3.47` |
| F3 | 99,994 | `99.99` |
| F4 | 99,996 | `100.0` |
| F5 | 128,060 | `128.1` |
| F6 | −3 | `0.00` |
