import Combine
import CoreLocation
import Foundation
import UIKit

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
    private var visibleArea: VisibleArea?
    /// Nearest-position result for the current fix and track; recomputed per fix, not per frame.
    private var cachedNearest: (fix: LocationFix, arrow: OffTrackArrow)?
    private var orientation = OrientationController()
    private var latestCompass: CompassHeading?

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
        heading.publisher
            .sink { [weak self] in
                self?.latestCompass = $0
                self?.updateOrientation()
            }
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

    func recentreTapped() {
        assign(\.mode, .following)
        assign(\.viewport, Viewport(center: defaultCenter, width: Viewport.defaultWidth, heading: viewport.heading))
    }

    /// The user zoomed or panned: stop following and keep the view they chose.
    func userChangedCamera(center: CLLocationCoordinate2D, width: Double) {
        assign(\.mode, .browsing)
        assign(\.viewport, Viewport(center: center, width: Viewport.clampedWidth(width), heading: viewport.heading))
    }

    /// Tells the compass which way the screen is turned, so its heading refers to the top of the screen.
    func interfaceOrientationChanged(_ orientation: UIInterfaceOrientation) {
        heading.setInterfaceOrientation(orientation)
    }

    func visibleAreaChanged(_ area: VisibleArea) {
        visibleArea = area
        assign(\.displayedMapHeading, area.viewport.heading)
        updateArrow()
    }

    // MARK: - Location

    private func received(_ fix: LocationFix?) {
        if let fix, fix.horizontalAccuracy < 0 { return }
        assign(\.userLocation, fix)
        if let fix {
            lastKnownCoordinate = fix.coordinate
            if mode == .following, !accessDenied { setCenter(fix.coordinate) }
        }
        updateOrientation()
        updateLocationMessage()
        updateArrow()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted: accessDenied = true
        case .authorizedWhenInUse, .authorizedAlways: accessDenied = false
        default: return
        }
        if mode == .following, track != nil { setCenter(defaultCenter) }
        updateLocationMessage()
        updateArrow()
    }

    /// Travel direction while moving, compass while stationary (both modes).
    private func updateOrientation() {
        orientation.update(fix: userLocation, compass: latestCompass)
        guard orientation.displayedHeading != viewport.heading else { return }
        var updated = viewport
        updated.heading = orientation.displayedHeading
        assign(\.viewport, updated)
    }

    /// Arrow toward the nearest track position, from the real fix, when no part of the track is in view.
    private func updateArrow() {
        guard !accessDenied, let geometry, let fix = userLocation, let visibleArea, !geometry.intersects(visibleArea) else {
            assign(\.arrow, nil)
            return
        }
        if cachedNearest?.fix != fix {
            let nearest = geometry.nearestPosition(to: fix.coordinate)
            cachedNearest = (fix, OffTrackArrow(bearing: nearest.bearing, distanceText: DistanceFormat.text(metres: nearest.distance)))
        }
        assign(\.arrow, cachedNearest?.arrow)
    }

    private func updateLocationMessage() {
        let message: LocationMessage? = accessDenied ? .denied : (userLocation == nil ? .unknown : nil)
        assign(\.locationMessage, message)
    }

    // MARK: - View state

    private func show(_ track: Track, _ geometry: TrackGeometry) {
        self.track = track
        self.geometry = geometry
        cachedNearest = nil
        lastKnownCoordinate = userLocation?.coordinate
        assign(\.mode, .following)
        assign(\.viewport, Viewport(center: defaultCenter, width: Viewport.defaultWidth, heading: viewport.heading))
        updateLocationMessage()
        updateArrow()
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
