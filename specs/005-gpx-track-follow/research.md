# Research: Follow a GPX Track

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-01

Each entry: Decision, Rationale, Alternatives considered.

## R1. Map: MapKit, hosted through `MKMapView` (UIViewRepresentable)

**Decision**: Show the street map with MapKit. Host it in an `MKMapView` wrapped in a `UIViewRepresentable` (`TrackMapView`), not the SwiftUI `Map`.

**Rationale**:
- Spec item 7 / US5: MapKit is built in, free, needs no API key or third-party service, shows roads and intersections, and can be rotated and zoomed under custom overlays. That confirms the spec's "low effort" assumption.
- The track line must stay glued to the roads while panning, zooming and rotating at ≥ 55 fps with 50,000 points (SC-002, SC-007). An `MKMultiPolyline` overlay rendered by MapKit itself does that: MapKit tiles and caches it, and it moves in the same frame as the map.
- SwiftUI `Map` has no custom `MKOverlayRenderer`, no per-frame region callback in the same frame as rendering (`onMapCameraChange(.continuous)` arrives asynchronously), and no reliable way to tell a user gesture from a programmatic camera change *while it starts* (FR-019 needs zoom-only gestures to switch to Browsing at once). Drawing the chevrons (FR-008a) in a SwiftUI `Canvas` over a SwiftUI `Map` via `MapProxy` lags the map by a frame, so the chevrons visibly slide off the line while panning.
- Constitution V allows UIKit "only where SwiftUI has no equivalent API (e.g. certain `UIViewRepresentable` wrappers)". This is that case; see plan Complexity Tracking. Everything around the map (overlay, arrow, buttons, north indicator, messages) stays SwiftUI.

**Alternatives considered**:
- SwiftUI `Map` + `MapPolyline` + `Canvas` for chevrons: rejected for the reasons above.
- Drawing everything ourselves on a blank `Canvas` (no road map): would satisfy US1–US4 but drop US5, and the spec found the road map to be low effort.
- Third-party map SDKs: prohibited (no dependencies; Constitution V).

## R2. Plain-background fallback when map data is unavailable (FR-022)

**Decision**: Rely on MapKit's own behaviour: without network and without cached tiles, `MKMapView` draws its empty grid background while overlays and annotations still render. No extra code path. `mapViewDidFailLoadingMap` is not needed to keep following working.

**Rationale**: Overlays (track line), annotations (start/finish, user location) and our SwiftUI overlay (arrow, chevrons layer) do not depend on tile loading. The quickstart verifies this in airplane mode in an uncached area.

**Alternatives considered**: Detecting map failure and swapping to a separate `Canvas` renderer: two renderers to keep in sync for no user-visible gain.

## R3. Track line, start/finish markers, chevrons (FR-008, FR-008a, US5-AS3)

**Decision**:
- **Track line**: one `MKMultiPolyline` (one `MKPolyline` per segment, so segments are not joined) rendered by `MKMultiPolylineRenderer`: 6 pt wide, saturated magenta/purple stroke (`.systemPurple`-like, not used by Apple Maps roads) with a 2 pt white casing drawn by a second, wider renderer underneath, so it contrasts on light and dark map styles.
- **Start/finish**: two `MKAnnotation`s (`TrackEndpointAnnotation`) with fixed screen-size views: green flag (start), checkered flag (finish). When the first and last points are ≤ 20 m apart, one combined "start/finish" annotation.
- **Chevrons**: drawn in screen space by a transparent `CAShapeLayer`-backed `UIView` above the `MKMapView` (a subview of the representable's container, user interaction disabled). In `mapViewDidChangeVisibleRegion(_:)` (called every frame during gestures and animations) the adapter asks the pure `TrackGeometry.chevrons` for chevron positions and angles over the visible chunks only. Projection to screen is an **analytic transform** (map point → screen from the map's current centre, metres-per-point and heading, all read once per frame), not `MKMapView.convert` per point. Points closer than 2 pt on screen to the previous kept point are skipped while walking the line, so at 20 km width a 50k-point track costs at most a few thousand cheap operations per frame. Spacing: **60 pt** along the on-screen line.
- Chevron phase is anchored to the track (positions at multiples of the spacing measured from each segment's start, in map points at the current zoom), so panning does not make chevrons crawl along the line.

**Rationale**:
- 1 cm on screen: iPhones range from 326 ppi @2x (≈ 64 pt/cm) to 460 ppi @3x (≈ 60 pt/cm). A 60 pt constant is 0.94–1.0 cm, within the 1 cm ± 0.3 cm tolerance on every supported iPhone, without reading device ppi (not public API).
- An `MKOverlayRenderer` for chevrons would draw at MapKit's discrete tile zoom levels and be scaled in between, so the on-screen spacing would drift up to ×√2 between levels and break the tolerance. Screen-space drawing gives exact spacing at every zoom.
- `mapViewDidChangeVisibleRegion` runs in the same run-loop pass as the map's own update, so chevrons stay on the line.

**Alternatives considered**: One `MKAnnotation` per chevron: thousands of annotations at 20 km width, and spacing would need recomputation on every zoom step anyway. Chevrons in the overlay renderer: rejected (tolerance, above).

## R4. Camera control: view width, rotation, zoom limits

**Decision**:
- The model state is a `Viewport` (centre coordinate, view width in metres, heading in degrees). The adapter applies it to `MKMapView.camera` (`centerCoordinate`, `heading`, `centerCoordinateDistance`, pitch 0).
- **View width ↔ camera distance**: with pitch 0, camera distance is proportional to the ground distance shown. After the first layout (and whenever the map's width changes, e.g. rotation to landscape) the adapter measures the current metres-per-point by converting two screen points on the horizontal centre line to coordinates and taking their geodesic distance, then sets `distance = currentDistance × targetWidth / currentWidth`. The "view width" is measured across the **shorter side** of the map view (spec Definitions), so in landscape the height is used.
- **Zoom limits** (FR-017): `MKMapView.cameraZoomRange` set to the camera distances that correspond to 100 m and 20 km view width, recomputed with the same ratio when the size changes.
- `isRotateEnabled = false`, `isPitchEnabled = false`: rotation comes only from the orientation rule (R7). `showsCompass = false` (its tap would reset north, conflicting with the rule). `pointOfInterestFilter` excludes nothing; `showsUserLocation = true` (R6).
- Camera changes from the model are applied with `UIView.animate(withDuration: 0.5)` + `setCamera(_, animated: false)` inside, so heading changes rotate smoothly (US3-AS5).
- **Applying the model viewport** (rules that keep the model from fighting the user):
  1. While a map gesture is active (from the gesture-start detection in R5 until `regionDidChangeAnimated` after it ends) the adapter applies **nothing** from the model, neither centre/width nor heading. The newest heading is remembered and applied when the gesture ends.
  2. In Browsing, a heading-only change is applied to the map's **current** `centerCoordinate` and `centerCoordinateDistance`, never to the model's centre/width, so rotation never moves or rescales the view.
  3. When a gesture ends, the adapter first reports the final centre and width (`userChangedCamera`, V7), then resumes applying the model.
  4. If a gesture starts during a running programmatic animation (e.g. a Following re-centre), the gesture wins: the animation's end state is not re-applied.

**Rationale**: Measuring the scale from the live map avoids hard-coding MapKit's field of view, which is not documented.

**Alternatives considered**: `setRegion` (cannot carry heading; the region of a rotated map is the bounding box, not the view width). `MKMapCamera(lookingAtCenter:fromEyeCoordinate:...)`: same FOV problem.

## R5. User gesture detection → Browsing (FR-018, FR-019)

**Decision**: In `mapView(_:regionWillChangeAnimated:)` the adapter checks whether any gesture recognizer on the map view **or any of its descendant views** is in `.began` or `.changed` state, or in `.ended` (double-tap and two-finger-tap zoom are tap recognizers that only reach `.ended`), (the recognizers are not reliably on `subviews.first` across iOS versions). If this proves unreliable on iOS 18, the fallback is the adapter's own `UIPanGestureRecognizer`/`UIPinchGestureRecognizer` attached to the map with simultaneous recognition, used only as a gesture-start signal. If so, the change is user-initiated: the adapter marks a gesture as active (R4 rule 1) and, on `regionDidChangeAnimated`, reports the final centre and width with `userChangedCamera(center:width:)`. To make "Re-centre" appear at once (FR-019), it also calls `userChangedCamera` with the current camera at gesture start. Programmatic changes are tagged by a flag set while the adapter applies a model viewport, and are never reported as user changes.

Pinch, double-tap zoom, two-finger-tap zoom-out and pan all count (all are "zoom or pan").

**Rationale**: The standard, widely used technique for `MKMapView`; it fires at the start of the gesture, so "Re-centre" appears immediately and the next location fix does not snap the view back.

**Alternatives considered**: Using only our own simultaneous recognizers from the start: more code for the same result, so it is kept as the fallback described above rather than the primary approach.

## R6. Position marker and accuracy halo

**Decision**: `MKMapView.showsUserLocation = true` with the system blue dot, which already shows the horizontal-accuracy halo (Edge case "Poor GPS accuracy"). `userTrackingMode = .none`: centring is driven by our model (R8), not MapKit.

**Rationale**: Zero code; matches the system look; the dot comes from the same Core Location fixes the app uses.

**Alternatives considered**: Custom annotation updated from our fixes: duplicates what MapKit does.

## R7. Orientation: travel direction vs compass (US3, Orientation table, SC-005)

**Decision**: A pure `OrientationController` value type:
- **Motion state** with hysteresis from `CLLocation.speed` (m/s × 3.6): becomes Moving at ≥ 3 km/h, Stationary at < 2 km/h, otherwise keeps the previous state. Initial state Stationary. A negative speed (invalid) keeps the previous state.
- **Source heading**: Moving → `CLLocation.course` if `course ≥ 0` (else unavailable). Stationary → compass `trueHeading` if ≥ 0, else `magneticHeading`; unavailable if `headingAccuracy < 0` or no compass.
- **Displayed heading**: if the source is unavailable, keep the last displayed heading (0 = north if none yet). Otherwise update the displayed heading only when the shortest angular difference to the current one is ≥ 5° (US3-AS5 dead band). The view animates each change over 0.5 s along the shortest arc, well within the 3 s of SC-005.
- Compass: `CLLocationManager.startUpdatingHeading()` with `headingFilter = 1`, wrapped in `HeadingProviding` / `CompassHeadingPublisher` (same pattern as `LocationPublisher`). `headingOrientation` is set from the interface orientation (portrait / landscapeLeft / landscapeRight are supported), so "the direction the device is facing" is the top of the screen in landscape too. **Caller**: `TrackMapView`'s coordinator reads `window?.windowScene?.interfaceOrientation` in `updateUIView` and on `UIDevice.orientationDidChangeNotification` and calls `HeadingProviding.setInterfaceOrientation(_:)` when it changes; `.unknown` (e.g. no window yet) is ignored so the last good orientation is kept. Heading needs no extra permission (spec Assumptions).

**Rationale**: Pure and deterministic, so every row of the Orientation table and the hysteresis boundaries are unit-tested.

**Alternatives considered**: `userTrackingMode = .followWithHeading`: MapKit switches nothing by speed, uses compass always, and fights our zoom/pan model.

## R8. Following vs Browsing, re-centre, location unknown (FR-010, FR-011, FR-019, FR-020, FR-023, US1-AS9/10)

**Decision**: `TrackViewModel` owns `mode` (`.following` / `.browsing`) and the target `Viewport`:
- Following, location known → centre = latest fix, width = 1 km.
- Following, **no fix received yet since the track was loaded**, or location access denied/restricted → centre = first point of the first segment, width = 1 km (FR-023, US1-AS9).
- Following, location lost **after** a fix was received (e.g. a brief GPS failure; `LocationPublisher` sends `nil` on `didFailWithError`) → centre stays on the last fix, `locationMessage = .unknown`, no arrow. The view does not jump to the track start. FR-023's "until a location is known" is read as "until the first fix arrives".
- Any user camera change → Browsing; the reported viewport (centre, width) becomes the model's; heading still follows the orientation rule (US4-AS5).
- Re-centre → Following, width 1 km, centre = latest known fix (the last one, even if location is currently lost), else the track start.
- Location becomes known: Following moves to the user; Browsing stays.
- Back from background: nothing special. Following re-centres on the next fix; Browsing keeps its viewport (it lives in the view model, which survives backgrounding).
- SC-003 (marker ≤ 10% of width from centre while walking): every fix is applied with a short (0.25 s) animated camera move; at walking speed a fix moves ≈ 1.5 m per second against a 100 m tolerance.

## R9. Off-screen arrow and "track in view" (US2, FR-012..FR-015, SC-004, SC-006)

**Decision**: Pure functions in `TrackGeometry`, working in `MKMapPoint` (Web Mercator, a public MapKit Foundation type usable in unit tests):
- **Nearest track position**: for each segment edge, the closest point on the edge to the user (projection clamped to the edge) in a local equirectangular frame around the user (metres; exact enough below ~50 km), then the minimum. Distance and initial bearing to that point are geodesic (haversine / standard bearing formula). O(n) per fix: 50,000 edges ≈ well under 1 ms.
- **Track in view**: the visible area is the map view rectangle minus the overlay insets (R11), as a rotated rectangle in map points. The track is in view if any edge intersects it (segment–polygon intersection, so a long edge crossing the view with both points outside counts, US2-AS4). Edges are grouped into chunks of 256 points with precomputed bounding rects; chunks whose rect misses the visible rect's bounding box are skipped. Re-evaluated on every visible-region change.
- **Arrow placement** (view side, pure `ArrowPlacement`): screen angle = bearing − displayed heading; the arrow sits where a ray from the visible area's centre at that angle meets the visible area's edge, inset by 32 pt.
- **Distance text**: `< 1000 m` → "`N` m" (rounded to the metre); otherwise "`N.N` km" (one decimal).
- No arrow when location unknown (US2-AS6) or the track is in view; the arrow is measured from the real position even while Browsing (US2-AS5).

**Rationale**: SC-004 asks for ≤ 5°; the geodesic bearing to the true nearest point is exact up to floating point. The local planar nearest-point search errs by far less than a degree at distances where the arrow is shown.

## R10. GPX parsing (FR-003, FR-004, edge cases)

**Decision**: `GPXParser` built on Foundation `XMLParser` (SAX, streaming) with `shouldProcessNamespaces = true`, matching local element names so GPX 1.0 and 1.1 (different namespaces, same element names) both work.
- Collect `trk/trkseg/trkpt` into segments; collect `rte/rtept` as segments separately. Use track segments if any valid track point exists, else route segments (one segment per `rte`). `wpt` are ignored.
- A point is valid if `lat` and `lon` parse as finite numbers with `-90…90` / `-180…180`. Invalid points are dropped; empty segments are dropped.
- Name: first `trk/name` (or `rte/name` when using routes), else `metadata/name` (1.1) or top-level `name` (1.0), else the file name without extension.
- Elevation and time are not read.
- Errors: XML parse error, root element not `gpx`, or no valid points → `GPXImportError.unreadable` / `.noTrackPoints`. Both give the same user message (FR-004).

**Rationale**: No dependencies; `XMLParser` parses a 50,000-point file (~5 MB) in a few hundred ms on device, inside the 3 s of SC-002.

## R11. Layout with a loaded track (FR-009)

**Decision**: When a track is loaded, `ContentView` becomes a `ZStack`: `TrackMapView` full-screen (ignoring safe areas), a top panel taking **30% of the screen height** from the top edge (changed from a compact 44 pt panel at the user's request on 2026-10-01: speed digits up to 120 pt, shrinking to fit the width but never below 48 pt; heart rate gauge filling the panel height, max 150 pt), and a bottom bar with "Import GPX track", the heart rate monitor button, and "Close track". Both panels use `.regularMaterial` backgrounds. Their measured heights (`onGeometryChange`) are passed to the map as **overlay insets**: they define the visible area for "track in view" and arrow placement (spec Definitions), and the map's `layoutMargins` so MapKit's attribution stays visible. The panel insets are also the map's layout margins: MapKit centres the camera inside its margins, so the user marker sits in the middle of the visible area (US1-AS3). Chevron projection anchors on the coordinate actually drawn at the screen centre, so it is unaffected.

In landscape the top panel lays speed and heart rate side by side to keep it short.

When no track is loaded, the existing layout is unchanged except for the new "Import GPX track" button next to the heart rate button (FR-001).

## R12. Importing: file picker and GPX type (FR-002)

**Decision**: SwiftUI `.fileImporter(isPresented:allowedContentTypes: [.gpx], allowsMultipleSelection: false)`. `UTType.gpx` = `UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)`, declared in the app's Info.plist under `UTImportedTypeDeclarations` (extension `gpx`, MIME `application/gpx+xml`). The selected URL is read with `startAccessingSecurityScopedResource()`. A `false` return means no scope is needed (e.g. app-local or temp URLs in tests), not a failure; `stopAccessingSecurityScopedResource()` is called only if start returned `true`. Data is read and parsed off the main actor; the result is applied on the main actor.

**Info.plist**: the target generates its Info.plist (`GENERATE_INFOPLIST_FILE = YES`), and `UTImportedTypeDeclarations` has no `INFOPLIST_KEY_` build setting. Add a partial `Velociraptor-Info.plist` **at the repository root (outside the synchronized `Velociraptor/` group, so it is not copied as a resource)** and set `INFOPLIST_FILE = "Velociraptor-Info.plist"` for Debug and Release; Xcode merges it with the generated keys.

**Rationale**: `.fileImporter` is the SwiftUI file picker and covers on-device files and file provider services (iCloud Drive, etc.), US1-AS2. Without the imported type declaration, a dynamic `UTType(filenameExtension:)` may leave `.gpx` files greyed out in the picker.

## R13. Remembering the track across relaunch (FR-007)

**Decision**: `TrackStoring` protocol with `FileTrackStore`: the parsed `Track` is encoded as JSON (`Codable`) and written atomically to `Application Support/CurrentTrack.json` on every successful import; deleted on close. `FileTrackStore` creates the directory (`withIntermediateDirectories: true`) before writing. At launch the app calls `TrackViewModel.loadStoredTrack()` from `.task`; it reads and decodes off the main actor and applies the result on the main actor. Any read or decode failure → no track, no message (Edge case), and the bad file is removed.

**Rationale**: Application Support is not purged by the system (unlike Caches). Storing the parsed track avoids keeping the original file name separately and avoids re-parsing XML at launch; 50,000 points decode in well under a second.

**Alternatives considered**: Security-scoped bookmark to the original file: breaks if the file is moved or the provider is offline. Copying the raw GPX: needs the name stored separately and re-parsing.

## R14. Keeping the screen on (FR-024)

**Decision**: In `VelociraptorApp`, `.onChange(of: scenePhase, initial: true)`: `UIApplication.shared.isIdleTimerDisabled = (phase == .active)`. `initial: true` applies it at launch too. Independent of the track.

**Rationale**: The only API for it (no SwiftUI equivalent; it is a property, not a view). Resetting it on background restores normal auto-lock.

## R15. Location stream for the track view

**Decision**: Reuse the existing `LocationPublisher<Behavior>` with a new `LocationFixBehavior` producing `LocationFix?` (coordinate, horizontal accuracy, speed m/s, course). `nil` until the first fix and after `didFailWithError`. Authorization comes from the existing `AuthorizationStatusPublisher` (denied/restricted → message with "Open Settings", as feature 004 does for Bluetooth).

**Rationale**: Same pattern and the same protocol (`LocationProviding`), so tests reuse `MockLocationProvider`. The extra `CLLocationManager` instance costs nothing measurable; Core Location shares the hardware.

## R16. Performance plan (SC-002)

- Parsing and JSON decoding happen off the main actor; only the finished `Track` is published.
- Track geometry (map points, chunk bounding rects, cumulative lengths) is precomputed once per track in `TrackGeometry.init`.
- Per frame: chunk-culled "track in view" and chevron layout over visible chunks only, with analytic projection and 2 pt subsampling (R3). Per fix: O(n) nearest search.
- The adapter calls `visibleAreaChanged` every frame, but the view model assigns `arrow` (and other `@Published` values) only when the value actually changes, so SwiftUI overlays are not re-rendered every frame.
- The stored track is loaded and decoded off the main actor at launch (R13).
- Measured on device with a 50,000-point fixture (quickstart Q8) using the Core Animation FPS HUD / Instruments.
