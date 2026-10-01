# Quickstart: Validate "Follow a GPX Track"

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- Xcode with the iOS 18.2 SDK; iPhone 16 simulator; a physical iPhone for D1–D10 (compass, real GPS, frame rate).
- GPX fixtures in `VelociraptorTests/Fixtures/` (added in the tasks): `short-1_1.gpx` (≈ 2 km, GPX 1.1), `short-1_0.gpx` (same track, GPX 1.0), `two-segments.gpx`, `route-only.gpx`, `waypoints-only.gpx`, `not-gpx.gpx` (PNG bytes renamed).
- `large-50k.gpx` (50,000 points) is not committed. Generate it with `swift specs/005-gpx-track-follow/scripts/make-large-gpx.swift > large-50k.gpx` (script added in the tasks; tests use the same generator in code).
- For device tests: one fixture recorded along streets near the tester, and AirDrop / Files to put fixtures on the phone.

## Automated checks

```bash
xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test  -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds; all suites pass, including `GPXParserTests`, `TrackGeometryTests`, `OrientationControllerTests`, `ArrowPlacementTests` (incl. distance text), `FileTrackStoreTests`, `TrackViewModelTests` (tables in [contracts/](contracts/)), and the existing 004 suites unchanged.

## Simulator scenarios

Use **Features → Location → Custom Location / City Run** in the simulator.

| # | Steps | Expected |
|---|---|---|
| Q1 | Launch. | Speed screen as before plus "Import GPX track" beside the heart rate button. Screen does not auto-lock while open (FR-024; verify on device in D7). |
| Q2 | Tap Import, cancel. | Nothing changes (US1-AS4). |
| Q3 | Import `not-gpx.gpx`, then `waypoints-only.gpx`. | Alert "Couldn't load …" each time; no track view (US1-AS5). |
| Q4 | Set location near `short-1_1.gpx`; import it. | Full-screen map, compact speed/HR on top, blue dot centred, track line with chevrons and start/finish markers, ~1 km across (US1-AS3, FR-008a, FR-009). |
| Q5 | Import `two-segments.gpx`. | Replaces the previous track; gap not joined (FR-005). |
| Q6 | Set location 2 km away. | Arrow at the visible edge pointing to the track with "2.0 km"-style text; disappears once location is moved back near the track (US2). |
| Q7 | Pinch, then tap Re-centre; pan, then tap Re-centre; double-tap, then two-finger-tap. | Re-centre appears after zoom-only, pan-only and tap-zoom, and the next location fix does not undo the zoom; tap restores 1 km centred view (US4). Zoom stops at ~100 m and ~20 km. |
| Q8 | Run "City Run". | View follows; marker stays within 10% of the view width from the centre (SC-003); while running, the travel direction is at the top (US3-AS1). |
| Q9 | Close track; relaunch. | After close, the screen looks exactly as before any import (US1-AS8). After relaunch, no track view. Import again; kill app from the switcher; relaunch → track shown in the default view (FR-007). |
| Q10 | Deny location in Settings; relaunch with a track. | Message + Open Settings; view on the track start; no arrow (FR-023, US2-AS6). |
| Q11 | Rotate to landscape. | Compact panels fit; view width = shorter side ≈ 1 km; arrow stays inside the visible area. |
| Q12 | With a track loaded and Following, set location to a point 500 m away while dragging the map. | The drag is not interrupted; Re-centre appears; the view does not snap to the new location (adapter M1, M3). |

## Device scenarios

| # | Steps | Expected |
|---|---|---|
| D1 | Stand still, turn the phone. | View rotates with the phone; north indicator shown; no jitter for small movements (US3-AS2, AS5). |
| D2 | Walk off and stop. | Within 3 s of starting to walk, travel direction at top; within 3 s of stopping, compass (SC-005). |
| D3 | Follow only the arrow from 2 km away. | Reaches the track without zooming or panning (SC-006). |
| D4 | Street-recorded track, 5 intersections. | Track line within 10 m of the road (SC-007). |
| D5 | Airplane mode in an area never viewed. | Track, marker, arrow on plain background; following works (US5-AS2, FR-022). |
| D6 | Import `large-50k.gpx` (stopwatch from tap on file). Enable Xcode's FPS gauge / Instruments "Animation Hitches" while pinching, panning and rotating. | Appears < 3 s; ≥ 55 fps (SC-002). |
| D7 | Leave the app open 2 min with a track; then background it 2 min. | Screen stays on while open; auto-locks normally in background (FR-024). |
| D8 | Connect a heart rate monitor with a track loaded. | HR behaves as in 004; only size/position differ (Edge case HR states). |
| D9 | Background while Browsing, return. | Zoom/position kept, Re-centre still shown. Repeat while Following → re-centred on current position. |
| D10 | Stand still with a track loaded; pan slowly with one finger while turning the phone. Then pinch while turning. | The view never snaps back during the gesture; after release it keeps the panned centre/zoom and rotates in place (M1, M2, US4-AS5). Also in landscape: the top of the screen is the direction the phone faces. |
