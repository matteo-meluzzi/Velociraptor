import Combine
import CoreLocation
import Foundation

enum TrackViewMode {
    case following, browsing
}

enum LocationMessage: Equatable {
    case unknown, denied
}

struct OffTrackArrow: Equatable {
    /// Degrees from north, from the user's real position to the nearest track position.
    let bearing: Double
    let distanceText: String
}

@MainActor
final class TrackViewModel: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var geometry: TrackGeometry?
    @Published private(set) var mode: TrackViewMode = .following
    /// Where the map should be; the map adapter applies it.
    @Published private(set) var viewport = Viewport(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0), width: Viewport.defaultWidth, heading: 0
    )
    /// The heading the map actually shows (from the last reported visible area).
    @Published private(set) var displayedMapHeading: Double = 0
    /// The latest valid fix; `nil` while location is unknown.
    @Published private(set) var userLocation: LocationFix?
    @Published private(set) var arrow: OffTrackArrow?
    @Published private(set) var locationMessage: LocationMessage?
    @Published var isImporterPresented = false
    @Published var alertMessage: String?

    var showsRecentreButton: Bool { mode == .browsing }

    private let store: any TrackStoring
    // Kept alive: the Core Location wrappers stop delivering when released.
    private let location: any LocationProviding<LocationFix?>
    private let heading: any HeadingProviding
    private let authorization: any AuthorizationProviding
    private var cancellables = Set<AnyCancellable>()
    private var accessDenied = false
    /// Last valid position received since the current track was loaded, kept while location is lost.
    private var lastKnownCoordinate: CLLocationCoordinate2D?

    init(
        location: any LocationProviding<LocationFix?>,
        heading: any HeadingProviding,
        authorization: any AuthorizationProviding,
        store: any TrackStoring
    ) {
        self.store = store
        self.location = location
        self.heading = heading
        self.authorization = authorization
        location.publisher
            .sink { [weak self] in self?.received($0) }
            .store(in: &cancellables)
        authorization.publisher
            .sink { [weak self] in self?.authorizationChanged($0) }
            .store(in: &cancellables)
    }

    // MARK: - Inputs

    func loadStoredTrack() async {
        let store = self.store
        let loaded = await Task.detached { store.load().map { ($0, TrackGeometry(track: $0)) } }.value
        if let (track, geometry) = loaded { show(track, geometry) }
    }

    func importButtonTapped() {
        isImporterPresented = true
    }

    func importFile(at url: URL) async {
        let fileName = url.lastPathComponent
        let store = self.store
        let result = await Task.detached { () -> Result<(Track, TrackGeometry), GPXImportError> in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return .failure(.unreadable) }
            return GPXParser.parse(data, fileName: fileName).map { track in
                // Best effort: if saving fails the track still shows, it just won't come back after a relaunch.
                try? store.save(track)
                return (track, TrackGeometry(track: track))
            }
        }.value
        switch result {
        case .success(let (track, geometry)):
            show(track, geometry)
        case .failure:
            alertMessage = "Couldn't load \(fileName)"
        }
    }

    func importFailed() {
        alertMessage = "Couldn't load the file"
    }

    func closeTrack() {
        track = nil
        geometry = nil
        assign(\.arrow, nil)
        store.clear()
    }

    func recentreTapped() {}

    func userChangedCamera(center: CLLocationCoordinate2D, width: Double) {}

    func visibleAreaChanged(_ area: VisibleArea) {}

    // MARK: - Location

    private func received(_ fix: LocationFix?) {
        if let fix, fix.horizontalAccuracy < 0 { return }
        assign(\.userLocation, fix)
        if let fix {
            lastKnownCoordinate = fix.coordinate
            if mode == .following, !accessDenied { setCenter(fix.coordinate) }
        }
        updateLocationMessage()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted: accessDenied = true
        case .authorizedWhenInUse, .authorizedAlways: accessDenied = false
        default: return
        }
        if mode == .following, track != nil { setCenter(defaultCenter) }
        updateLocationMessage()
    }

    private func updateLocationMessage() {
        let message: LocationMessage? = accessDenied ? .denied : (userLocation == nil ? .unknown : nil)
        assign(\.locationMessage, message)
    }

    // MARK: - View state

    private func show(_ track: Track, _ geometry: TrackGeometry) {
        self.track = track
        self.geometry = geometry
        lastKnownCoordinate = userLocation?.coordinate
        assign(\.mode, .following)
        assign(\.viewport, Viewport(center: defaultCenter, width: Viewport.defaultWidth, heading: viewport.heading))
        updateLocationMessage()
    }

    /// The user's last position since the track was loaded, else the track start (also when access is denied).
    private var defaultCenter: CLLocationCoordinate2D {
        guard let track else { return viewport.center }
        if accessDenied { return track.start.coordinate }
        return lastKnownCoordinate ?? track.start.coordinate
    }

    private func setCenter(_ center: CLLocationCoordinate2D) {
        var updated = viewport
        updated.center = center
        assign(\.viewport, updated)
    }

    /// Publishes only real changes, so per-frame inputs don't re-render the views.
    private func assign<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<TrackViewModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
