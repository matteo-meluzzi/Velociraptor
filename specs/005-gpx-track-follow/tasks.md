---

description: "Task list for Follow a GPX Track"
---

# Tasks: Follow a GPX Track

**Input**: Design documents from `specs/005-gpx-track-follow/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R16), data-model.md, contracts/ (`gpx-import.md`, `track-geometry.md`, `track-view-model.md`, `ui.md`), quickstart.md

**Tests**: Included. The plan requires unit tests for every pure type and for `TrackViewModel` (Constitution II), using Swift Testing (`import Testing`, `@Test`, `#expect`, `@testable import Velociraptor`). Tests assert on return values and published state only, never on private state or call order. Test doubles exist only at the Core Location boundary (`MockLocationProvider`, `MockHeadingProvider`, `MockAuthorizationProvider`). Storage uses the real `FileTrackStore` on a per-test temp directory. `MKMapView`, the compass and real GPS are verified manually (quickstart.md).

**Organization**: Tasks are grouped by user story (spec.md): US1 Import and see (P1), US2 Off-screen arrow (P1), US3 View turns with me (P2), US4 Zoom/pan/re-centre (P2), US5 Roads under the track (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)

## Path Conventions

- App sources: `Velociraptor/` (flat; `fileSystemSynchronizedGroups`, so new files are picked up automatically, no `project.pbxproj` file-reference edits needed)
- Unit tests: `VelociraptorTests/`
- Build settings: `Velociraptor.xcodeproj/project.pbxproj`
- Swift 5 language mode (`SWIFT_VERSION = 5.0`). View models are `@MainActor final class … : ObservableObject` with `@Published private(set)` outputs, like `HeartRateViewModel` in `Velociraptor/HeartRateView.swift`
- Headings are degrees clockwise from true north, normalised to `0..<360`. Distances are metres.

## Commit gates (apply to every "Gate" task)

Per the constitution, in order:
1. `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` exits 0.
2. `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` passes, including all feature 004 suites unchanged.
3. A reviewer agent reviews `git diff` + `git diff --cached` and approves. The review must flag tests that assert on implementation details. Fix any blocking feedback and re-run steps 1–3.
4. Commit only the files of that task group. Messages end with the attribution line.

A task is not complete until its gate passes.

---

## Phase 1: Setup

**Purpose**: GPX file type, test infrastructure, green baseline.

- [X] T001 Run `xcodebuild test` on the current branch and confirm it is green before any change. If it is not, stop and report to the user (do not start feature work on a red baseline)
- [X] T002 Create `Velociraptor-Info.plist` at the **repository root** (outside the synchronized `Velociraptor/` group, so it is not copied as a resource), containing only `UTImportedTypeDeclarations` with one entry: `UTTypeIdentifier` = `com.topografix.gpx`, `UTTypeDescription` = `GPX track`, `UTTypeConformsTo` = [`public.xml`], `UTTypeTagSpecification` = { `public.filename-extension` = [`gpx`], `public.mime-type` = [`application/gpx+xml`] } (research R12)
- [X] T003 In `Velociraptor.xcodeproj/project.pbxproj` add `INFOPLIST_FILE = "Velociraptor-Info.plist";` to the **app target's** Debug and Release build configurations only: the two blocks that contain `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`. Keep `GENERATE_INFOPLIST_FILE = YES` so the generated keys are merged. Build and confirm the built app's `Info.plist` contains both `UTImportedTypeDeclarations` and `NSLocationWhenInUseUsageDescription` (`plutil -p` on the built product)
- [X] T004 Gate: commit T002–T003 ("build: declare GPX document type")

---

## Phase 2: Foundational (shared types and boundaries)

**Purpose**: Types every story uses. **⚠️ No user story work begins until this phase is complete.**

- [X] T005 [P] Create `Velociraptor/Track.swift`:
  - `struct TrackPoint: Codable, Equatable { let latitude: Double; let longitude: Double }`, with `var coordinate: CLLocationCoordinate2D`.
  - `struct TrackSegment: Codable, Equatable { let points: [TrackPoint] }` ("≥ 1 point").
  - `struct Track: Codable, Equatable { let name: String; let segments: [TrackSegment] }` ("name never empty", "≥ 1 segment").
  - Computed `start` (first point of first segment), `finish` (last point of last segment) and `isLoop` (`Geo.distance(start, finish) <= 20`).
- [X] T006 [P] Create `Velociraptor/Geo.swift`:
  - `enum Geo`:
    - `static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double`: haversine, Earth radius 6_371_008.8 m.
    - `static func bearing(from:to:) -> Double`: initial great-circle bearing, `0..<360`.
    - `static func normalized(_ degrees: Double) -> Double`: to `0..<360`.
    - `static func angularDistance(_ a: Double, _ b: Double) -> Double`: shortest, `0...180`.
  - `enum DistanceFormat { static func text(metres: Double) -> String }`:
    - Round to the nearest metre first. If the result is `< 1000`, return `"\(Int) m"`; otherwise `String(format: "%.1f km", metres / 1000)`.
    - Contract table: 0.4→"0 m", 999.4→"999 m", 999.6→"1.0 km", 1000→"1.0 km", 2449→"2.4 km", 12_345→"12.3 km".
  - `struct Viewport: Equatable { var center: CLLocationCoordinate2D; var width: Double; var heading: Double }`:
    - Constants `static let defaultWidth = 1_000.0`, `minWidth = 100.0`, `maxWidth = 20_000.0`.
    - `static func clampedWidth(_:)`.
    - `Equatable` compares coordinates by latitude/longitude.
  - `struct VisibleArea: Equatable { let mapSize: CGSize; let insets: EdgeInsets; let viewport: Viewport }`:
    - `var visibleRect: CGRect`: the map rect minus the insets, in screen points.
    - `var metresPerPoint: Double`: `viewport.width / min(mapSize.width, mapSize.height)`.
    - `func project(_ p: MKMapPoint) -> CGPoint`: analytic transform. Screen centre = map centre; rotate by −heading; scale by map points per metre at the centre latitude (`MKMapPointsPerMeterAtLatitude`).
    - `func unproject(_ s: CGPoint) -> MKMapPoint`.
    - `var corners: [MKMapPoint]`: the visible rect's four corners unprojected.
  - Add `extension EdgeInsets: Equatable` only if SwiftUI doesn't already provide it.
- [X] T007 [P] Write `VelociraptorTests/GeoTests.swift`:
  - Distance: Paris→London ≈ 343.5 km ± 0.5%. Same point → 0.
  - Bearing: due north 0, due east ≈ 90 ± 0.5, due south 180, due west 270.
  - `angularDistance(358, 2) == 4`.
  - The whole DistanceFormat table.
  - `VisibleArea`:
    - With heading 0, a point 100 m north of centre projects above the centre by `100 / metresPerPoint` pt (± 0.5).
    - With heading 90, the same point projects to the left of centre.
    - `project(unproject(p)) ≈ p`.
    - `visibleRect` excludes the insets.
- [X] T008 [P] Add to `Velociraptor/LocationPublisher.swift` (existing types untouched):
  - `struct LocationFix: Equatable { let coordinate: CLLocationCoordinate2D; let horizontalAccuracy: Double; let speed: Double; let course: Double }`, with custom `==` comparing lat/lon.
  - `struct LocationFixBehavior: LocationBehavior`:
    - `initialValue: LocationFix?` = `nil`.
    - `value(from:)` maps every `CLLocation` → `LocationFix`, including ones with `horizontalAccuracy < 0`. It never returns `nil` for a delivered location: `nil` means "location lost" to the view model, and invalid fixes are filtered there instead (V15).

  `LocationPublisher` already sends `initialValue` (nil) on `didFailWithError` (research R15).
- [X] T009 [P] Create `Velociraptor/HeadingPublisher.swift`:
  - `struct CompassHeading: Equatable { let trueHeading: Double; let magneticHeading: Double; let accuracy: Double }`. Doc: trueHeading < 0 when unavailable; accuracy < 0 means invalid.
  - `protocol HeadingProviding: AnyObject`, with `var publisher: AnyPublisher<CompassHeading?, Never> { get }` ("current value replayed") and `func setInterfaceOrientation(_ orientation: UIInterfaceOrientation)`.
  - `final class CompassHeadingPublisher: NSObject, CLLocationManagerDelegate, HeadingProviding`:
    - Owns a `CLLocationManager` with `headingFilter = 1` and a `CurrentValueSubject<CompassHeading?, Never>(nil)`.
    - In `init`, if `CLLocationManager.headingAvailable()`, calls `startUpdatingHeading()`.
    - `didUpdateHeading` → send. `locationManagerShouldDisplayHeadingCalibration` → `false`.
    - `setInterfaceOrientation` maps `.portrait`→`.portrait`, `.portraitUpsideDown`→`.portraitUpsideDown`, `.landscapeLeft`→`.landscapeRight` and `.landscapeRight`→`.landscapeLeft` (interface vs device orientation are mirrored), and ignores `.unknown` (research R7).
- [X] T010 [P] Create `Velociraptor/TrackStore.swift`:
  - `protocol TrackStoring { func load() -> Track?; func save(_ track: Track) throws; func clear() }`.
  - `struct FileTrackStore: TrackStoring`:
    - `init(directory: URL)`. Add `static var applicationSupport: FileTrackStore` (directory from `FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)`).
    - The file is `directory/CurrentTrack.json`.
    - `save` creates the directory (`withIntermediateDirectories: true`), then writes `JSONEncoder` data with `.atomic`.
    - `load`: if the file is absent → nil. If it cannot be read or decoded → delete the file and return nil.
    - `clear` removes the file and ignores errors (research R13).
- [X] T011 Create `VelociraptorTests/TrackTestDoubles.swift` with:
  - `final class MockHeadingProvider: HeadingProviding`, holding a `CurrentValueSubject<CompassHeading?, Never>(nil)` with `send(_:)`; `setInterfaceOrientation` stores the last value in `private(set) var lastOrientation`.
  - `func makeTempDirectory() -> URL`: a unique dir under `FileManager.default.temporaryDirectory`, created.
  - `func gpx11(_ body: String, name: String? = nil) -> String` and `gpx10(_ body: String) -> String`, wrapping the body in `<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">…</gpx>` / the 1.0 namespace.
  - `func makeTrack(_ segments: [[(Double, Double)]], name: String = "Test") -> Track`.
  - `func largeGPX(points: Int = 50_000) -> String`: a deterministic zig-zag around 45.0, 7.0.

  Needs `Track` (T005), `LocationFix` (T008) and `HeadingProviding` (T009). `MockLocationProvider<T>` (existing, `VelociraptorTests/MockLocationProvider.swift`) and `MockAuthorizationProvider` (existing, `VelociraptorTests/LocationStatusViewModelTests.swift`) are reused, not redefined
- [X] T012 [P] Write `VelociraptorTests/FileTrackStoreTests.swift`, each test on its own `makeTempDirectory()`:
  - save then load returns an equal track (2 segments).
  - load with no file → nil.
  - save, clear, load → nil.
  - write garbage bytes to `CurrentTrack.json` → load is nil and the file no longer exists.
  - save into a not-yet-existing subdirectory succeeds.
  - a second save replaces the first.
- [X] T013 Gate: commit T005–T012 ("feat: track model, geo helpers, location fix, compass and track store")

**Checkpoint**: Shared types compile and are tested; no UI change yet.

---

## Phase 3: User Story 1 - Import a Track and See It Around Me (Priority: P1) 🎯 MVP

**Goal**:
- Import button, file picker, GPX parsing, persistence and close.
- A full-screen map centred on the user, with the track line, start/finish markers and direction chevrons.
- Compact speed and heart rate on top, and the screen kept awake.

**Independent Test**: Import a GPX file whose track passes within 500 m of the tester's location. Check that the track view appears, the position marker is in the centre, and the track inside the ~1 km view is drawn in the right place with chevrons and start/finish markers (quickstart Q1–Q5, Q9–Q11).

### Tests for User Story 1

- [X] T014 [P] [US1] Write `VelociraptorTests/GPXParserTests.swift`: one `@Test` per row of the fixture table in `contracts/gpx-import.md`, using inline strings via `gpx11`/`gpx10`. Rows:
  - 1.1 trk/trkseg/3 trkpt → 1 segment, 3 points, name from `trk/name`.
  - Same in 1.0 → same result.
  - 2 trkseg → 2 segments.
  - 2 trk → 2 segments, name from the first trk.
  - Only `rte` with 4 rtept → 1 segment of 4.
  - trk + rte → track points only.
  - Only `wpt` → `.failure(.noTrackPoints)`.
  - `lat="95"`, `lon="abc"` and a missing `lon` among valid points → dropped.
  - All points invalid → `.noTrackPoints`.
  - Empty trkseg + a valid one → 1 segment.
  - `metadata/name` "Loop" → "Loop".
  - No names, fileName "Morning ride.gpx" → "Morning ride".
  - PNG bytes `Data([0x89,0x50,0x4E,0x47])` → `.unreadable`.
  - Truncated XML → `.unreadable`.
  - Root `<kml>` → `.unreadable`.

  Also: `largeGPX()` parses to 50,000 points.
- [X] T015 [P] [US1] Write `VelociraptorTests/TrackGeometryTests.swift`, chevron part (`contracts/track-geometry.md` "Chevrons" table):
  - Use a `VisibleArea` 390×844 with zero insets, heading 0, width 1000, and `area.project` as the projection.
  - Straight north–south track spanning more than the screen, spacing 60 → consecutive chevron positions 60 ± 0.5 pt apart along the line, angles all pointing up (file order south→north).
  - Same track with the viewport centre moved 37 pt worth of metres → chevron positions shifted by the same 37 pt (not re-phased).
  - Track entirely outside the area → empty.
  - Two segments with a gap through the view → no chevron lies on the gap.
  - Points < 2 pt apart on screen do not change the chevron count by more than 1.
- [X] T016 [P] [US1] Write `VelociraptorTests/TrackViewModelTests.swift`, US1 part. Build the VM with:
  - `MockLocationProvider<LocationFix?>(initialValue: nil)`
  - `MockHeadingProvider()`
  - `MockAuthorizationProvider(status: .authorizedWhenInUse)`
  - `FileTrackStore(directory: makeTempDirectory())`

  Import tests write GPX strings to files in a temp dir and call `await vm.importFile(at: url)`. Tests:
  - **V1**: a store holding a track + `await vm.loadStoredTrack()` → `track` set, `mode == .following`, `viewport.width == 1000`. Empty store → `track == nil`, `alertMessage == nil`. Garbage file → `track == nil`, `alertMessage == nil`.
  - **V2**: import a valid file → `track` set, `mode == .following`, default width. A new VM on the same directory loads it.
  - **V3**: import an invalid file while a track is loaded → `alertMessage == "Couldn't load <file name>"`, `track` unchanged, and a new VM on the same directory still loads the old track. Import of a non-existent URL → same alert.
  - **V5**: `closeTrack()` → `track == nil`; a new VM loads nothing.
  - **V6**: Following + fix → `viewport.center` equals the fix; width unchanged.
  - **V10**: no fix yet → centre == `track.start`, `arrow == nil`, `locationMessage == .unknown`. Auth `.denied` → centre == start, `locationMessage == .denied`. Fix then `nil` → centre stays at the last fix, `locationMessage == .unknown`.
  - **V11**: Following, no fix → first fix moves the centre to it.
  - **V15**: a fix with `horizontalAccuracy` −1 is ignored: centre unchanged, `userLocation` unchanged, and `locationMessage` not set to `.unknown` by it.
  - **V10 recovery**: fix, then `nil` (message `.unknown`), then a valid fix → `locationMessage == nil`.
  - **V14**: the VM API exposes no heart-rate or speed state (nothing to test beyond compiling against the contract; skip).
  - Importing a second file replaces the first (`track.name` changes, US1-AS6).
  - `importButtonTapped()` → `isImporterPresented == true`.

### Implementation for User Story 1

- [X] T017 [P] [US1] Create `Velociraptor/GPXParser.swift`:
  - `enum GPXImportError: Error, Equatable { case unreadable, noTrackPoints }`.
  - `extension UTType { static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml) }`.
  - `enum GPXParser { static func parse(_ data: Data, fileName: String) -> Result<Track, GPXImportError> }`: an `XMLParser` delegate class with `shouldProcessNamespaces = true`, matching local element names (research R10, contract G1–G4).
    - Root must be `gpx`, else `.unreadable`.
    - Collect `trk/trkseg/trkpt` per trkseg, and `rte/rtept` per rte, into separate lists.
    - A point is valid if `lat`/`lon` attributes parse as `Double`, are finite, and are in −90…90 / −180…180. Drop invalid points, then drop empty segments.
    - Use the track segments if any are non-empty, else the route segments. Neither → `.noTrackPoints`.
    - Name: first non-empty `trk/name` (or `rte/name` when routes are used), then `metadata/name`, then top-level `gpx/name`, then `fileName` without extension (`(fileName as NSString).deletingPathExtension`).
    - Ignore `ele`, `time`, `extensions` and `wpt`.
    - `parse()` returning false → `.unreadable`.

  T014 must pass.
- [X] T018 [P] [US1] Create `Velociraptor/TrackGeometry.swift`, chevron part:
  - `struct Chevron: Equatable { let position: CGPoint; let angle: Angle }`.
  - `struct TrackGeometry` with `init(track:)` precomputing:
    - `segments: [[MKMapPoint]]`.
    - `chunks`: runs of ≤ 256 consecutive points within one segment; consecutive chunks share their boundary point. Each chunk has `boundingRect: MKMapRect`.
    - `cumulativeLength: [[Double]]`: map-point length from the segment start.
  - `func chevrons(in area: VisibleArea, project: (MKMapPoint) -> CGPoint, spacing: CGFloat) -> [Chevron]`:
    - Bounding `MKMapRect` of `area.corners`, slightly expanded.
    - For each chunk intersecting it, walk the edges.
    - Chevron phase is anchored to the track: positions at multiples of `spacingInMapPoints = spacing × area.metresPerPoint × MKMapPointsPerMeterAtLatitude(center.latitude)` measured along `cumulativeLength` from each segment start.
    - Emit those whose projected position lies inside `area.visibleRect`, with angle = direction of the projected edge.
    - Skip points < 2 pt on screen from the previous kept point (research R3).

  T015 must pass.
- [X] T019 [US1] Create `Velociraptor/TrackViewModel.swift`, US1 part, matching `contracts/track-view-model.md`:
  - Types: `enum TrackViewMode { case following, browsing }`, `enum LocationMessage: Equatable { case unknown, denied }`, `struct OffTrackArrow: Equatable { let bearing: Double; let distanceText: String }`.
  - `@MainActor final class TrackViewModel: ObservableObject`, with `init(location: any LocationProviding<LocationFix?>, heading: any HeadingProviding, authorization: any AuthorizationProviding, store: any TrackStoring)`.
  - Published outputs: `track`, `geometry`, `mode`, `viewport`, `displayedMapHeading` (initially 0; set in T032), `userLocation`, `arrow` (stays nil in US1), `locationMessage`, `isImporterPresented`, `alertMessage`. `var showsRecentreButton: Bool { mode == .browsing }`.
  - Inputs:
    - `loadStoredTrack() async`: load off-main via `Task.detached`, apply on main.
    - `importButtonTapped()`.
    - `importFile(at:) async`:
      - Call `startAccessingSecurityScopedResource()`. A `false` return is not a failure; call stop only if it returned true.
      - Read the data and parse off-main.
      - Success → save via store, set track and geometry, `mode = .following`, default view.
      - Any failure → `alertMessage = "Couldn't load \(url.lastPathComponent)"`, track unchanged.
    - `importFailed()` (same alert, generic name "the file").
    - `closeTrack()` → track/geometry nil, `store.clear()`.
  - Default-view centre rule (data-model.md): the last fix received since the track was loaded, even if location is lost now; else `track.start`; and `track.start` when auth is denied/restricted.
  - Subscribe to location fixes:
    - Ignore `horizontalAccuracy < 0`.
    - Set `userLocation`.
    - Following → `viewport.center = fix`.
    - `nil` → keep the centre and set `locationMessage = .unknown`.
    - A valid fix clears `locationMessage` (sets it to `nil`) unless access is denied/restricted, in which case it stays `.denied`.
  - Subscribe to authorization: `.denied`/`.restricted` → `.denied`.
  - Assign `@Published` values only when they change (V16).
  - Stub `userChangedCamera(center:width:)`, `recentreTapped()` and `visibleAreaChanged(_:)` as empty methods for later stories.

  T016 must pass.
- [X] T020 [US1] Create `Velociraptor/TrackMapView.swift`, US1 part: `struct TrackMapView: UIViewRepresentable` taking `track: Track`, `geometry: TrackGeometry`, `viewport: Viewport`, `insets: EdgeInsets`, `onVisibleAreaChanged: (VisibleArea) -> Void`, `onUserChangedCamera: (CLLocationCoordinate2D, Double) -> Void`.
  - **Container**: a `UIView` holding an `MKMapView` (accessibilityIdentifier `trackMap`) and, above it, a `ChevronLayerView` (`UIView` with a `CAShapeLayer`, `isUserInteractionEnabled = false`).
  - **Map setup**: `showsUserLocation = true`, `userTrackingMode = .none`, `isRotateEnabled = false`, `isPitchEnabled = false`, `showsCompass = false`; `layoutMargins` from insets.
  - **Overlays**: an `MKMultiPolyline` (one `MKPolyline` per segment) added twice:
    - a casing renderer: white, lineWidth 9;
    - a line renderer: `.systemPurple`, lineWidth 6, round caps/joins.

    Distinguish them with two `MKMultiPolyline` instances.
  - **Endpoints**: `TrackEndpointAnnotation: NSObject, MKAnnotation` with kind `.start`, `.finish` or `.startFinish` (when `track.isLoop`). Annotation views: `flag.fill` green (start), `flag.checkered` (finish), `flag.2.crossed.fill` (start/finish), fixed screen size, `displayPriority = .required`.
  - **Viewport application**:
    - Only after the map has a non-zero size.
    - Measure metres-per-point by converting two points on the horizontal centre line (or the vertical one when height < width, so the width is across the shorter side) to coordinates, then `Geo.distance`.
    - Set `camera.centerCoordinateDistance = current × target.width / currentWidth`, plus `centerCoordinate` and `heading`, inside `UIView.animate(withDuration: 0.25)` with `setCamera(_, animated: false)`.
    - Set a flag while applying, so the delegate can tell programmatic changes from user ones.
    - Re-apply when the size changes (research R4).
  - **Visible region**: in `mapViewDidChangeVisibleRegion`, build a `VisibleArea` (map size, insets, current camera centre/width/heading), call `onVisibleAreaChanged`, and redraw chevrons via `geometry.chevrons(in:project: area.project, spacing: 60)`. Each chevron is a 10 pt-wide filled triangle path, white fill and dark outline, rotated to its angle.
  - When `track` changes, replace overlays and annotations.
- [X] T021 [P] [US1] Add a `compact: Bool = false` parameter:
  - `Velociraptor/SpeedView.swift`: `SpeedView` uses digits 44 pt instead of 120 pt and the unit in `.caption`; the default path is byte-for-byte the same layout.
  - `Velociraptor/HeartRateView.swift`: `HeartRateView` passes a 72 pt gauge instead of 140 pt; the default unchanged.

  Existing 004 tests stay green.
- [X] T022 [US1] Create `Velociraptor/TrackView.swift`, US1 part: `struct TrackView: View` with `@ObservedObject var viewModel: TrackViewModel` and `insets: EdgeInsets`.
  - `TrackMapView`, full screen, `.ignoresSafeArea()`, wired to the VM (`onVisibleAreaChanged` → `viewModel.visibleAreaChanged`, `onUserChangedCamera` → `viewModel.userChangedCamera`).
  - The location message under the top inset (`trackLocationMessage`):
    - `.unknown` → "Waiting for your location…".
    - `.denied` → "Location access is off. Showing the start of the track." plus an "Open Settings" button (`trackOpenSettingsButton`, `UIApplication.openSettingsURLString` via `openURL`, as in `MonitorPickerView`).

  Texts per `contracts/ui.md`.
- [X] T023 [US1] Modify `ContentView` in `Velociraptor/VelociraptorApp.swift`. Add `@ObservedObject var trackViewModel: TrackViewModel`.
  - **No track**: the existing VStack unchanged, except the heart rate button row becomes `ViewThatFits { HStack { hrButton; importButton }; VStack { hrButton; importButton } }`. `importButton` = "Import GPX track", `.bordered`, `importTrackButton` (FR-001, contracts/ui.md).
  - **Track loaded**: a `ZStack` of
    - `TrackView`;
    - a top panel `.regularMaterial`: `HStack { SpeedView(compact: true); HeartRateView(compact: true) }` plus `LocationStatusView`;
    - a bottom bar `.regularMaterial`: `HStack { importButton; hrButton; closeButton }`, with `closeButton` = `Label("Close track", systemImage: "xmark")` and `closeTrackButton`.

    Measure the panel heights with `onGeometryChange` and pass them as `insets` to `TrackView` (research R11).
  - Attach to both layouts:
    - `.fileImporter(isPresented: $trackViewModel.isImporterPresented, allowedContentTypes: [.gpx], allowsMultipleSelection: false)`: success → `Task { await trackViewModel.importFile(at: url) }`; failure → `importFailed()`; cancel → nothing.
    - An alert bound to `trackViewModel.alertMessage`, with message "The file is not a GPX track or has no track points." and an OK button.

  The existing HR sheet and alert are unchanged.
- [X] T024 [US1] Modify `VelociraptorApp` in `Velociraptor/VelociraptorApp.swift`:
  - Add `@StateObject trackViewModel = TrackViewModel(location: LocationPublisher(behavior: LocationFixBehavior()), heading: CompassHeadingPublisher(), authorization: AuthorizationStatusPublisher(), store: FileTrackStore.applicationSupport)` and pass it to `ContentView`.
  - `.task { await trackViewModel.loadStoredTrack() }`.
  - Change the scenePhase handler to `.onChange(of: scenePhase, initial: true)`: keep `heartRateViewModel.sceneBecameActive()` on `.active`, and set `UIApplication.shared.isIdleTimerDisabled = (phase == .active)` (FR-024, R14).
  - Update the existing previews to pass a `TrackViewModel` built from mocks. Add a preview "Track loaded" with a sample 3-segment track injected via a temp `FileTrackStore`, plus `.task { await vm.loadStoredTrack() }` and a `MockLocationProvider` fix near the track. Add the `PreviewHeadingProvider` class next to `PreviewHeartRateService`.
- [ ] T025 [US1] Run quickstart Q1–Q5 and Q9–Q11 in the simulator. Fix anything that fails. Note the results in the gate's review request
  - 2026-10-01: done in the simulator: Q1 (no-track screen) and Q4/Q9 (track restored on relaunch from a planted `CurrentTrack.json`, map ~1 km wide centred on the user, line, chevrons on the line and not on the gap, start/finish flags, legal label). Fixed in the process: the view model didn't retain its location/compass providers; the map centre was offset by asymmetric layout margins; the bottom inset was measured wrong.
  - **Still to do by hand**: Q2, Q3 and Q5 (need the file picker), Q10 (deny location), Q11 (landscape; simulator rotation couldn't be automated).
- [X] T026 [US1] Gate: commit T014–T025 ("feat: import GPX track and show it on a map")

**Checkpoint**: MVP: a track can be imported, seen around the user, closed, and restored on relaunch.

---

## Phase 4: User Story 2 - Arrow Toward the Track When It Is Off-Screen (Priority: P1)

**Goal**: When no part of the track line is in the visible area, an arrow at the edge of the visible area points to the nearest track position, with the distance shown.

**Independent Test**: Simulator location 2 km from the track → arrow with "2.0 km"-style text pointing to the track; move near → arrow gone (quickstart Q6; device D3).

### Tests for User Story 2

- [X] T027 [P] [US2] Add to `VelociraptorTests/TrackGeometryTests.swift` the "Nearest position" table:
  - On a point → ≈ 0.
  - 300 m beside the middle of a 2 km straight edge → mid-edge, 300 ± 1 m.
  - Second segment nearer → on the second.
  - Never on the gap between segments.
  - Out-and-back → closest.
  - 2 km east of a N–S track → bearing 270 ± 5.
  - Single-point track.

  And the "Track in view" table, using `VisibleArea` 390×844, width 1000:
  - A point inside → true.
  - A long edge crossing with both ends outside → true.
  - A track only under a 150 pt top inset → false.
  - A track outside at heading 0 but inside a corner at heading 45 → true.
  - A gap between segments crossing the view → false.
- [X] T028 [P] [US2] Write `VelociraptorTests/ArrowPlacementTests.swift`: the "Arrow placement" table (rect 300×500 at the origin, margin 32: 0° → (150, 32), 90° → (268, 250), 180° → (150, 468), 45° → on the right or top edge, inside by 32), plus 270° → (32, 250). The distance-text rows already live in GeoTests (T007); do not duplicate them
- [X] T029 [P] [US2] Add to `VelociraptorTests/TrackViewModelTests.swift`. Use `vm.visibleAreaChanged(VisibleArea(mapSize: 390×844, insets: zero, viewport: vm.viewport))` to report the view.
  - **V13**:
    - Fix 2 km east of a N–S track with the track out of view → `arrow?.bearing` ≈ 270 ± 5 and `distanceText == "2.0 km"`.
    - Fix on the track → `arrow == nil`.
    - Location `nil` → `arrow == nil` (US2-AS6).
    - No track → nil.
  - **US2-AS5**: after `userChangedCamera` to a far-away centre, the arrow is still measured from the real fix.
  - **V17**: `visibleAreaChanged` with a viewport heading of 40 while the target `viewport.heading` is 90 → `displayedMapHeading == 40`. Before any area is reported → 0.
  - **V16**: sending the same visible area twice publishes `arrow` once (count `$arrow` emissions with `dropFirst()` collected into an array).

### Implementation for User Story 2

- [X] T030 [US2] Add to `Velociraptor/TrackGeometry.swift`:
  - `struct NearestTrackPosition: Equatable { let coordinate: CLLocationCoordinate2D; let distance: Double; let bearing: Double }`.
  - `func nearestPosition(to:) -> NearestTrackPosition`:
    - For every edge of every segment (a single-point segment counts as its point), find the closest point on the edge, clamped to the edge, in a local equirectangular metre frame around the user: x = Δlon·cos(lat)·R, y = Δlat·R.
    - Take the minimum.
    - Distance and bearing via `Geo` (research R9).
  - `func intersects(_ area: VisibleArea) -> Bool`:
    - Skip chunks whose bounding rect misses the bounding rect of `area.corners`.
    - Otherwise test each edge against the rotated quadrilateral `area.corners`: either endpoint inside (point-in-convex-polygon), or the edge intersects any of the 4 sides.

  T027 must pass.
- [X] T031 [P] [US2] Add `enum ArrowPlacement { static func position(in visibleRect: CGRect, screenAngle: Double, margin: CGFloat = 32) -> CGPoint }` to `Velociraptor/TrackView.swift`. Screen angle 0 = up, clockwise. Cast a ray from `visibleRect.insetBy(margin)`'s centre; return its intersection with that inset rect's border. T028 must pass
- [X] T032 [US2] In `Velociraptor/TrackViewModel.swift` implement `visibleAreaChanged(_:)`:
  - Store the area.
  - Publish `displayedMapHeading = area.viewport.heading` (the heading the map actually shows, reported by the adapter from its camera), only on change (V17).
  - Recompute `arrow` = nil if there is no track, no current fix (location lost counts), or `geometry.intersects(area)`. Otherwise `OffTrackArrow(bearing: nearest.bearing, distanceText: DistanceFormat.text(metres: nearest.distance))` from the **real fix**.
  - Also recompute on every fix.
  - Assign only on change (V16).

  T029 must pass.
- [X] T033 [US2] In `Velociraptor/TrackView.swift` overlay the arrow when `viewModel.arrow != nil`:
  - `Image(systemName: "location.north.fill")` rotated by `arrow.bearing − viewModel.displayedMapHeading`, with the distance text below it. Use `displayedMapHeading`, never `viewport.heading`: the target heading runs ahead of the map during the 0.5 s rotation and during gestures (M1), and the arrow must match what is on screen (SC-004).
  - Positioned at `ArrowPlacement.position(in: visibleRect, screenAngle: arrow.bearing − viewModel.displayedMapHeading)`, where `visibleRect` = the full rect minus `insets`.
  - Accessibility identifiers `offTrackArrow` and `offTrackDistance`; accessibility label "Track is <distance> away".
- [X] T034 [US2] Run quickstart Q6 (done 2026-10-01 in the simulator: arrow "1.9 km" pointing west at the left edge; gone after moving back, view followed; arrow margin is 44 pt rather than 32 so the larger arrow+label stays clear of the edge). Gate: commit T027–T034 ("feat: off-screen arrow toward the nearest track position")

**Checkpoint**: US1 + US2 are usable to follow a track north-up.

---

## Phase 5: User Story 3 - Track View Turns With Me (Priority: P2)

**Goal**: The top of the view is the travel direction when Moving and the compass direction when Stationary, with hysteresis, a fallback to the last heading (north initially), a 5° dead band, smooth rotation and a north indicator.

**Independent Test**: Walk straight → the travel direction is at the top; stop and turn the phone → the view turns with it; a north indicator appears when rotated (quickstart Q8, D1, D2).

### Tests for User Story 3

- [X] T035 [P] [US3] Write `VelociraptorTests/OrientationControllerTests.swift`:
  - One `@Test` per row of the "Motion transitions" and "Displayed heading" tables in data-model.md.
  - The extra contract rows: 2.5 km/h after Stationary stays Stationary; 2.5 km/h after Moving stays Moving; a candidate 4° away is not applied; a candidate exactly 5° away is applied; displayed 358 with candidate 2 is not applied; never had a heading and the source unavailable → 0.
  - Stationary with `trueHeading` −1 and `magneticHeading` 120 (accuracy 5) → 120.
  - Accuracy −1 → unchanged.
  - Speeds are given in m/s on `LocationFix` (3 km/h = 0.8333 m/s).
- [X] T036 [P] [US3] Add to `VelociraptorTests/TrackViewModelTests.swift` (V12, observable outcomes):
  - Fix at 10 km/h with course 90 → `viewport.heading == 90`.
  - Then 1 km/h + compass true 200 (accuracy 5) → 200.
  - Moving with course −1 → keeps the previous heading.
  - A fresh VM with nothing → 0.
  - The same course case after `userChangedCamera` (Browsing) → heading still 90 (US4-AS5).

### Implementation for User Story 3

- [X] T037 [US3] Create `Velociraptor/Orientation.swift`:
  - `enum MotionState { case stationary, moving }`.
  - `struct OrientationController { private(set) var motion: MotionState = .stationary; private(set) var displayedHeading: Double = 0; mutating func update(fix: LocationFix?, compass: CompassHeading?) }`.
  - **Motion**, km/h = `speed × 3.6`: ignore `speed < 0` or no fix; stationary→moving at ≥ 3; moving→stationary at < 2.
  - **Candidate**:
    - Moving → `fix.course` if ≥ 0.
    - Stationary → if `compass.accuracy >= 0`, use `trueHeading` when ≥ 0, else `magneticHeading`.
    - Otherwise no candidate.
  - **Apply**: only if `Geo.angularDistance(candidate, displayedHeading) >= 5`, then `displayedHeading = Geo.normalized(candidate)`.

  T035 must pass.
- [X] T038 [US3] In `Velociraptor/TrackViewModel.swift`, subscribe to `heading.publisher`. On every fix or compass value, call `orientation.update(fix: latestFix, compass: latestCompass)` and set `viewport.heading = orientation.displayedHeading` in both modes, only on change. T036 must pass
- [X] T039 [US3] In `Velociraptor/TrackMapView.swift`:
  - **Heading animation**: apply heading changes with `UIView.animate(withDuration: 0.5)` along the shortest arc (MapKit interpolates the camera heading; verify that 350→10 goes through 0).
  - **Interface orientation**: in `updateUIView` and on `UIDevice.orientationDidChangeNotification`, read `mapView.window?.windowScene?.interfaceOrientation`. When it changes and is not `.unknown`, call a new `onInterfaceOrientationChanged` callback. `TrackView` forwards it to a new `TrackViewModel.interfaceOrientationChanged(_:)`, which calls `heading.setInterfaceOrientation(_:)`.
  - **Test**: add a test that `MockHeadingProvider.lastOrientation` receives `.landscapeLeft` after `vm.interfaceOrientationChanged(.landscapeLeft)`.
- [X] T040 [US3] In `Velociraptor/TrackView.swift` add the north indicator (`northIndicator`): a small circle with "N" and a needle, rotated by `−viewModel.displayedMapHeading` (the map's actual heading, so it never runs ahead of the map; no extra animation needed since it follows the map frame by frame), at the top-leading corner of the visible area. Show it only when `Geo.angularDistance(displayedMapHeading, 0) >= 1`
- [X] T041 [US3] Run quickstart Q8 (done 2026-10-01 in the simulator: simulated run at 15 km/h heading NE → map rotated travel-up, north indicator shown, view followed, chevrons on the line. Still by hand on a device: D1/D2, and a direct landscapeLeft↔landscapeRight flip while stationary). Gate: commit T035–T040 ("feat: rotate track view by travel direction or compass")

**Checkpoint**: US1–US3 work; the view rotates.

---

## Phase 6: User Story 4 - Zoom, Pan, and Re-centre (Priority: P2)

**Goal**: Pinch zoom (100 m–20 km) and pan switch to Browsing and show "Re-centre". Tapping it restores the default view and resumes Following. The model never fights an active gesture.

**Independent Test**: Pinch → Re-centre appears; tap → 1 km centred view, button gone; same with pan and double-tap (quickstart Q7, Q12, D9, D10).

### Tests for User Story 4

- [X] T042 [P] [US4] Add to `VelociraptorTests/TrackViewModelTests.swift`:
  - **V7**: `userChangedCamera(center: X, width: 3000)` → `mode == .browsing`, `showsRecentreButton`, `viewport.center == X`, `width == 3000`. Width 50 → clamped to 100; 50_000 → 20_000. A zoom-only change (same centre) → Browsing too.
  - **V8**: Browsing + new fix → `viewport.center` unchanged, `userLocation` updated.
  - **V9**: `recentreTapped()` → `.following`, width 1000, centre = last fix; with no fix ever → `track.start`; with location lost after a fix → the last fix.
  - **V11**: Browsing, the first fix arrives → centre unchanged.
  - Importing a new track while Browsing → `.following` (data-model transitions).

### Implementation for User Story 4

- [X] T043 [US4] In `Velociraptor/TrackViewModel.swift` implement:
  - `userChangedCamera(center:width:)`: `mode = .browsing`, `viewport.center = center`, `viewport.width = Viewport.clampedWidth(width)`.
  - `recentreTapped()`: `.following`, `width = Viewport.defaultWidth`, centre per the default-view rule.

  Following-only centring already exists (T019). T042 must pass.
- [X] T044 [US4] In `Velociraptor/TrackMapView.swift` implement gestures and adapter rules M1–M5 (`contracts/track-view-model.md`, research R4/R5):
  - **Zoom range**: `cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance:maxCenterCoordinateDistance:)`, computed from the measured distance/width ratio for 100 m and 20 000 m. Recompute on size change.
  - **Gesture detection**: in `regionWillChangeAnimated`, the change is user-initiated if any gesture recognizer on the map view or any descendant (recursive walk) is in `.began`, `.changed` or `.ended` (the last covers double-tap and two-finger-tap zoom) and the programmatic flag is not set. Then:
    - set `gestureActive = true`;
    - call `onUserChangedCamera` with the current centre/width (Re-centre appears immediately);
    - drop any pending animation end state.
  - **Gesture end**: in `regionDidChangeAnimated`, if `gestureActive`, report the final centre/width via `onUserChangedCamera`, set `gestureActive = false`, then apply the newest model heading.
  - **M1**: while `gestureActive`, `updateUIView` applies nothing (remember the newest heading).
  - **M2**: when the incoming viewport differs only in heading, or the mode is Browsing, apply the heading on the map's current `centerCoordinate` and `centerCoordinateDistance`. Pass `mode` into `TrackMapView` for this.
  - **Fallback**: if recognizer detection proves unreliable on iOS 18 in Q7/Q12, add the adapter's own `UIPanGestureRecognizer` and `UIPinchGestureRecognizer` with `delegate.shouldRecognizeSimultaneouslyWith = true`, used only as a start signal.
- [X] T045 [US4] In `Velociraptor/TrackView.swift` add the "Re-centre" button (`recentreButton`, `Label("Re-centre", systemImage: "location.fill")`, `.borderedProminent`). Place it at the bottom centre of the visible area, above the bottom inset, shown when `viewModel.showsRecentreButton`. Action: `viewModel.recentreTapped()`
- [X] T046 [US4] Run quickstart Q7 (pinch, pan, double-tap, two-finger-tap, zoom limits), Q12, and on device D9 and D10 if a device is available, otherwise note them for T052. Gate: commit T042–T045 ("feat: zoom, pan and re-centre the track view")
  - 2026-10-01: a temporary XCUITest (deleted afterwards) on the simulator with a stored track: swipe, pinch and double-tap each showed Re-centre; it stayed through 3 s of location updates (no snap back); each Re-centre tap hid it. **Still by hand on a device**: zoom limits (100 m / 20 km), two-finger-tap zoom-out, Q12, D9, D10, a fling while the compass turns (the view must not stop mid-fling), a pinch where one finger lifts early followed by Re-centre, and rotating the screen while Browsing (width across the shorter side changes until Re-centre).

**Checkpoint**: US1–US4 work.

---

## Phase 7: User Story 5 - See Roads Under the Track (Priority: P3)

**Goal**: Streets and intersections under the track, with the track clearly visible on top. Plain background offline.

**Independent Test**: With data, streets line up under the track; in airplane mode in an unviewed area, the track, marker and arrow still show (quickstart D4, D5).

The street map itself comes from `MKMapView` (T020). This phase checks contrast and the offline fallback.

- [X] T047 [US5] In `Velociraptor/TrackMapView.swift`:
  - Set `preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)`, so roads stay visible but the purple line and chevrons dominate (US5-AS3, FR-008a).
  - Keep `pointOfInterestFilter = .excludingAll`, so POI labels don't clutter the track.
  - Confirm the light and dark appearance in the "Track loaded" preview in both colour schemes.
- [X] T048 [US5] On device: run D4 (track within 10 m of the road at 5 intersections, SC-007) and D5 (airplane mode in an uncached area: track, marker, arrow and following still work, FR-022). If MapKit shows nothing at all offline instead of its grid, set `mapView.backgroundColor = .secondarySystemBackground` so the plain background is explicit. Gate: commit T047–T048 ("feat: muted street map under the track")
  - 2026-10-01: muted map, no POIs, explicit plain background set; start/finish drawn as white badges (SF-symbol tinting rendered black under MKAnnotationView). Checked in light and dark in the simulator. **Still by hand on a device**: D4 (track within 10 m of the road at 5 intersections) and D5 (airplane mode in an uncached area).

**Checkpoint**: All user stories are functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T049 [P] Create `specs/005-gpx-track-follow/scripts/make-large-gpx.swift`: a standalone `#!/usr/bin/env swift` script that prints a valid GPX 1.1 file with 50,000 `trkpt`s (same zig-zag as `largeGPX()` in `VelociraptorTests/TrackTestDoubles.swift`, centred on an optional `lat lon` argument, default 45.0 7.0) to stdout
- [X] T050 [P] Add a performance test to `VelociraptorTests/GPXParserTests.swift` and `VelociraptorTests/TrackGeometryTests.swift`, asserting with generous simulator bounds to catch regressions (not to prove SC-002):
  - Done as `VelociraptorTests/PerformanceGuardTests.swift` (parse + geometry < 2 s, best of 3). The per-frame guard was removed: it was flaky under parallel test load. Frame rate is checked on device (D6).
  - parsing `largeGPX()` plus `TrackGeometry(track:)` takes < 2 s (`ContinuousClock`);
  - `nearestPosition` takes < 50 ms;
  - `intersects` + `chevrons` at a 20 km width takes < 16 ms.
- [X] T051 Verify that the "Heart rate monitor states" edge case and FR-009 still hold. Run the existing 004 previews and tests: the no-track screen is unchanged apart from the import button. Device D8 checks the heart rate with a track loaded
- [ ] T052 Run the full [quickstart.md](quickstart.md): the remaining simulator rows and device D1–D10, including D6 with `make-large-gpx.swift` output (appears < 3 s, ≥ 55 fps) and D7 (screen stays on in the foreground, auto-locks in the background). Record the pass/fail results in `specs/005-gpx-track-follow/checklists/validation.md`. Fix failures under the gates
  - **Open, needs a real iPhone**: the file picker (Q2, Q3, Q5), Q10, Q11 landscape, D1–D10 (incl. D6 with `scripts/make-large-gpx.swift`, D7 screen stays on).
- [X] T053 Gate: commit T049–T052 ("test: performance guards, large GPX generator, validation notes")

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T001 first.
- **Foundational (Phase 2)**: needs T001–T004. Blocks all stories.
- **US1 (Phase 3)**: needs Phase 2. This is the MVP.
- **US2 (Phase 4)**: needs US1 (uses `TrackViewModel`, `TrackView`, `TrackGeometry` and the map's visible-area reporting).
- **US3 (Phase 5)**: needs US1. Independent of US2, so it can run in parallel with US2 if staffed, though both edit `TrackViewModel.swift`/`TrackView.swift`, so it is sequential in practice.
- **US4 (Phase 6)**: needs US1. Its M2 rule interacts with US3's heading, so do it after US3.
- **US5 (Phase 7)**: needs US1 only.
- **Polish (Phase 8)**: needs all stories.

### Within Each Story

Tests first (they fail), then pure types, then the view model, then the adapter/views, then the quickstart run, then the gate.

### Parallel Opportunities

- Phase 2: T005, T006, T008, T009 and T010 are separate files, all [P]. Their tests T007 and T012 are [P] too. T011 (test doubles) follows T005, T008 and T009.
- US1: tests T014, T015, T016 [P]; T017, T018 and T021 [P] (separate files). T019 → T020 → T022 → T023 → T024 are sequential.
- US2: T027, T028, T029 [P]; T031 is [P] with T030.
- US3: T035, T036 [P].
- Polish: T049, T050 [P].

## Parallel Example: User Story 1

```bash
# Tests together:
Task: "GPXParserTests in VelociraptorTests/GPXParserTests.swift (T014)"
Task: "Chevron tests in VelociraptorTests/TrackGeometryTests.swift (T015)"
Task: "TrackViewModel US1 tests in VelociraptorTests/TrackViewModelTests.swift (T016)"

# Then independent implementation files together:
Task: "GPXParser in Velociraptor/GPXParser.swift (T017)"
Task: "TrackGeometry chevrons in Velociraptor/TrackGeometry.swift (T018)"
Task: "Compact SpeedView/HeartRateView (T021)"
```

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 + Phase 2.
2. Phase 3 (US1) → **STOP and VALIDATE** with quickstart Q1–Q5, Q9–Q11.
3. Usable as is: import, see the track around you north-up, relaunch-safe.

### Incremental Delivery

US1 → US2 (arrow: now usable from far away) → US3 (rotation) → US4 (zoom/pan/re-centre) → US5 (map contrast/offline check) → Polish. Each phase ends with a committed, green, reviewed gate.

## Notes

- Every Gate follows the Commit gates section; never commit with a red build/test or without reviewer approval.
- Do not modify feature 004 behaviour; only `compact` options are added to its views.
- The [P] tasks within one file group (e.g. tests in `TrackViewModelTests.swift` across stories) are only parallel *within* a phase, never across phases.
