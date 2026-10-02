# Contract: Distance band and TrackViewModel

## Layout (FR-006–FR-009, FR-012)

- The band appears only in `ContentView.trackLayout`. It sits directly under the speed/heart rate panel, with height `0.15 × screen.height` (full screen height, the same measure as the 30% panel) and a `regularMaterial` background.
- Two equal halves: left "Done", right "Left". Each is a label above the number, followed by a smaller "km".
- Digits: rounded, regular weight, monospaced, `0.36 × band` pt. "km" is set at half the digit size. Number and unit form one `Text` with `lineLimit(1)` and `minimumScaleFactor(0.5)`, so they shrink together and are never cut off (device feedback 2026-10-02). The label is `max(11, 0.14 × band)` pt, secondary colour.
- Portrait: the band is pulled up (negative top padding) by half the visible gap between the instruments (speed digits, location status line, gauge) and the "Done" letters. The pull is computed from measurements in the panel's and band's own coordinate spaces, which don't depend on the pull, so it updates whenever the instruments change (for example a monitor connects). The measurement corrects frames for font metrics: digits bottom = speed frame bottom − 0.22 × digit size, labels top = label frame top + 0.2 × label size. Panel and band share one `regularMaterial` background.
- Landscape: one bar (top 30%) with `HStack { HStack { speed; heart rate }; DistanceBand(height: bar content height) }`, each half of the width. The background extends into the top and side safe areas.
- The bottom buttons float over the map, each with its own `regularMaterial` rounded background. The bar has no background, and the map runs to the bottom edge.
- The map's top inset is the bottom of the top overlay, and its bottom inset is the top of the buttons, so the user is centred in what is visible.
- Accessibility identifiers: `distanceBand`, `distanceTravelled`, `distanceRemaining`. VoiceOver labels: "Done, 3.47 kilometres" and "Left, 1.53 kilometres"; with no value, "Done, unknown".

## TrackViewModel guarantees

| ID | Given | Then `distances` |
|---|---|---|
| D1 | no track | `nil` |
| D2 | track imported, no fix yet | `done == "—"`, `left == "—"` |
| D3 | 1.11 km straight track imported, fix at the start | `done == "0.00"`, `left == "1.11"` |
| D4 | then a fix halfway along | `done` and `left` change accordingly and add up to the length within 0.01 |
| D5a | progress established, then the location is lost (`nil` fix) | unchanged |
| D5b | progress not established (fix > 30 m off the track shown), then the location is lost | `"—"` for both |
| D6 | track closed | `nil`; a fresh view model on the same store loads no progress |
| D7 | progress established and moved ≥ 5 m | a fresh view model on the same store restores it: after `loadStoredTrack()` and before any fix, `done` shows the saved value |
| D8 | a new track is imported over one with saved progress | `done == "—"` until a fix; the old progress is not restored on relaunch |
| D9 | location access denied, restored progress | the restored values are shown |
| D10 | a fix is already known when a track is imported | values shown immediately, without another fix |
| D11 | Browsing (user panned the map) | values still follow the real fixes |
| D12 | progress saved for track A; fixes keep arriving while track B is imported | after the import, a fresh view model on the same store restores no progress (or B's own progress once B is established) |
