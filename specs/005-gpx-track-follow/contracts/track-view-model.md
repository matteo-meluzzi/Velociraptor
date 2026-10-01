# Contract: TrackViewModel and its boundaries

## Boundaries (protocols; real + test implementations)

```swift
// Existing: LocationProviding<Value>, AuthorizationProviding
// New behaviour for the existing LocationPublisher:
struct LocationFixBehavior: LocationBehavior { /* Value = LocationFix?; initial nil */ }

protocol HeadingProviding: AnyObject {
    var publisher: AnyPublisher<CompassHeading?, Never> { get }   // current value replayed
    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation)  // maps to CLDeviceOrientation
}
// App: CompassHeadingPublisher (CLLocationManager.startUpdatingHeading, headingFilter 1)
// Tests: MockHeadingProvider

protocol TrackStoring {
    func load() -> Track?          // nil when absent or unreadable (unreadable file removed)
    func save(_ track: Track) throws
    func clear()
}
// App: FileTrackStore(directory: Application Support); Tests: FileTrackStore(directory: per-test temp dir)
```

## TrackViewModel

```swift
@MainActor
final class TrackViewModel: ObservableObject {
    init(location: any LocationProviding<LocationFix?>,
         heading: any HeadingProviding,
         authorization: any AuthorizationProviding,
         store: any TrackStoring)

    // Outputs
    @Published private(set) var track: Track?
    @Published private(set) var geometry: TrackGeometry?
    @Published private(set) var mode: TrackViewMode
    @Published private(set) var viewport: Viewport           // target for the map
    @Published private(set) var displayedMapHeading: Double  // heading the map actually shows (from the last VisibleArea); drives arrow + north indicator
    @Published private(set) var userLocation: LocationFix?
    @Published private(set) var arrow: OffTrackArrow?
    @Published private(set) var locationMessage: LocationMessage?   // .unknown | .denied
    @Published var isImporterPresented: Bool
    @Published var alertMessage: String?

    var showsRecentreButton: Bool { mode == .browsing }

    // Inputs
    func loadStoredTrack() async               // called once from .task at launch; decodes off-main
    func importButtonTapped()
    func importFile(at url: URL) async         // reads (security-scoped), parses off-main, applies
    func importFailed()                        // picker returned an error
    func closeTrack()
    func recentreTapped()
    func userChangedCamera(center: CLLocationCoordinate2D, width: Double)
    func visibleAreaChanged(_ area: VisibleArea)  // map size/insets/viewport after any change
}
```

## Guarantees

| # | Guarantee | Spec |
|---|---|---|
| V1 | `loadStoredTrack()` loads the stored track if any → `track` set, `mode = .following`, default view; nothing shown and no alert if absent/unreadable | FR-007, Edge case relaunch |
| V2 | Successful import → replaces `track`, saves it, `mode = .following`, default view | US1-AS3, FR-005 |
| V3 | Failed import (unreadable, no points, file read error) → `alertMessage = "Couldn't load <file name>"`, previous `track` unchanged, store unchanged | FR-004, US1-AS5 |
| V4 | Picker cancelled → no state change (the view simply does not call `importFile`) | US1-AS4 |
| V5 | `closeTrack()` → `track = nil`, store cleared; relaunch shows no track | FR-006, FR-007 |
| V6 | Following: every non-nil fix sets `viewport.center` to it; width stays | FR-011 |
| V7 | `userChangedCamera` → `mode = .browsing`, viewport centre/width = reported (width clamped 100…20,000) | FR-017..FR-019 |
| V8 | Browsing: fixes update `userLocation` and `arrow` but not `viewport.center` | US4-AS3 |
| V9 | `recentreTapped()` → `.following`, width 1,000, centre = last fix received since the track was loaded, else track start | FR-020, US1-AS9 |
| V10 | No fix received yet since the track was loaded, or auth denied/restricted → Following centre = track start. Location lost after a fix → centre stays on the last fix. In both cases `arrow = nil`; `locationMessage` = `.denied` when access is denied/restricted, else `.unknown`. The next valid fix clears `.unknown` | FR-023, US2-AS6 |
| V11 | Location becomes known: Following → centre moves to fix; Browsing → unchanged | US1-AS10 |
| V12 | Orientation outcomes in both modes, e.g. fix at 10 km/h with course 90 → `viewport.heading` 90; then speed 1 km/h + compass 200 → 200; course unknown while moving → previous heading; never had one → 0. Same results while Browsing | US3, US4-AS5 |
| V13 | `arrow` is non-nil iff track loaded, location known, and the track does not intersect the last reported visible area; bearing/distance from the real fix | US2, FR-012..FR-015 |
| V14 | The view model never touches heart rate or speed state | Edge case HR states |
| V15 | Fixes with `horizontalAccuracy < 0` are ignored | — |
| V16 | `arrow`, `mode`, `viewport` and `locationMessage` are reassigned only when their value changes (per-frame `visibleAreaChanged` does not re-publish identical values) | SC-002 |
| V17 | `displayedMapHeading` equals the heading of the last reported `VisibleArea` (0 before any), not the target `viewport.heading`; the arrow and north indicator rotate by it | SC-004, FR-016 |

All guarantees are tested in `TrackViewModelTests` through the public interface with `MockLocationProvider<LocationFix?>`, `MockHeadingProvider` and `MockAuthorizationProvider` (Core Location boundaries the view model does not own; Constitution II). Storage uses the real `FileTrackStore` on a per-test temporary directory, since the filesystem is the real boundary. Import tests write fixture files to a temporary directory and pass real file URLs.

## Map adapter rules (`TrackMapView`, verified manually: quickstart Q7, Q12, D1)

| # | Rule |
|---|---|
| M1 | While a map gesture is active, no model viewport (centre, width or heading) is applied; the newest heading is applied when the gesture ends |
| M2 | In Browsing, heading-only changes keep the map's current centre and camera distance |
| M3 | At gesture start → `userChangedCamera` with the current camera; at gesture end → `userChangedCamera` with the final centre/width, then model application resumes |
| M4 | Programmatic camera changes are never reported as user changes |
| M5 | `visibleAreaChanged` after every visible-region change; overlay insets from the panels' measured heights |
