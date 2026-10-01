# Contract: UI (speed screen + track view)

## Elements

| Element | Accessibility identifier | Shown when | Content |
|---|---|---|---|
| Import button | `importTrackButton` | always (every HR state), next to `heartRateMonitorButton` | "Import GPX track" |
| Close track | `closeTrackButton` | track loaded | "Close track" (xmark icon + label) |
| Track map | `trackMap` | track loaded | full screen, under the panels |
| Re-centre | `recentreButton` | Browsing | "Re-centre" (location icon + label) |
| Off-track arrow | `offTrackArrow` | `arrow != nil` | arrow glyph rotated to `bearing − displayed heading`, at the visible-area edge, with the distance ("850 m" / "2.4 km") below it; one accessibility element whose value is the distance |
| North indicator | `northIndicator` | displayed heading ≠ 0 | "N" needle rotated to `−heading` |
| Location message | `trackLocationMessage` | `locationMessage != nil` | see Messages |
| Open Settings | `trackOpenSettingsButton` | location denied | "Open Settings" |
| Speed (over map) | existing `SpeedView` | track loaded | top panel = 30% of screen height; digits up to 120 pt (75% of the panel's content height), shrink to fit width, never below 48 pt |
| Heart rate (over map) | existing identifiers | track loaded, per feature 004 | speed and gauge each take half the panel width (speed takes all of it when no heart rate is shown); gauge fills its half up to the panel content height |
| Bottom bar buttons (over map) | existing identifiers | track loaded | regular control size (≈1.5× the earlier small size, ~32 pt tall), 32 pt apart, icon-only when titles don't fit |

Existing identifiers from feature 004 (`heartRateMonitorButton`, `heartRateValue`, …) are unchanged.

## Layout

```text
No track (unchanged from 004 + one button):      Track loaded:
┌───────────────────────────┐                    ┌───────────────────────────┐
│                           │                    │ [speed 44pt] [HR gauge]   │ ← top panel (material)
│        [HR gauge]         │                    ├───────────────────────────┤
│        188.8 km/h         │                    │  N↑            ⟶ 850 m    │
│   Location unavailable    │                    │        ~~~~~~~            │
│                           │                    │          ● (user)         │ ← map, visible area
│ [Change HR monitor]       │                    │                           │
│ [Import GPX track]        │                    │      [Re-centre]          │
└───────────────────────────┘                    ├───────────────────────────┤
                                                 │ [Import] [HR monitor] [✕] │ ← bottom bar (material)
                                                 └───────────────────────────┘
```

The two buttons in the no-track layout sit side by side in an `HStack` when they fit and stack vertically otherwise (`ViewThatFits`), so neither is truncated.

## Messages

| Situation | Where | Text |
|---|---|---|
| Import failed (any reason) | alert | "Couldn't load `<file name>`" with message "The file is not a GPX track or has no track points." |
| Location not yet known | track view, under top panel | "Waiting for your location…" |
| Location access denied / restricted | track view | "Location access is off. Showing the start of the track." + "Open Settings" |

## Map styling

- Track line: 6 pt, purple, over a 9 pt white casing; segments not joined.
- Start: green flag marker; finish: checkered flag; loop (≤ 20 m): one combined start/finish marker.
- Chevrons: white-filled, dark-outlined, 10 pt wide, 60 pt apart along the line, pointing in file order.
- User: system blue dot with accuracy halo.
