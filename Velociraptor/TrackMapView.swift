import MapKit
import SwiftUI

/// MapKit street map showing the track. SwiftUI's `Map` has no per-frame overlay sync or gesture-start signal,
/// so this wraps `MKMapView` (Constitution V exception, see plan Complexity Tracking). It only applies the model's
/// viewport and reports what the map shows; all decisions live in `TrackViewModel`.
struct TrackMapView: UIViewRepresentable {
    static let chevronSpacing: CGFloat = 60

    let track: Track
    let geometry: TrackGeometry
    let viewport: Viewport
    let mode: TrackViewMode
    let insets: EdgeInsets
    let onVisibleAreaChanged: (VisibleArea) -> Void
    let onUserChangedCamera: (CLLocationCoordinate2D, Double) -> Void
    let onInterfaceOrientationChanged: (UIInterfaceOrientation) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TrackMapContainer {
        let container = TrackMapContainer()
        container.mapView.delegate = context.coordinator
        container.onLayout = { [weak coordinator = context.coordinator] in
            coordinator?.sizeChanged()
            coordinator?.checkInterfaceOrientation()
        }
        context.coordinator.container = container
        context.coordinator.observeDeviceRotation()
        return container
    }

    func updateUIView(_ container: TrackMapContainer, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isUpdating = true
        defer { coordinator.isUpdating = false }
        // MapKit centres the camera inside its layout margins; symmetric margins keep that centre at the
        // screen centre (where the projection and the user marker expect it) while lifting the legal label
        // above the bottom bar.
        let margin = max(insets.top, insets.bottom)
        container.mapView.layoutMargins = UIEdgeInsets(top: margin, left: 0, bottom: margin, right: 0)
        let trackChanged = coordinator.show(track)
        if trackChanged { coordinator.trackDidChange() }
        let insetsChanged = coordinator.lastInsets != insets
        coordinator.lastInsets = insets
        coordinator.apply(viewport)
        if trackChanged || insetsChanged { coordinator.refreshVisibleArea() }
        coordinator.checkInterfaceOrientation()
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TrackMapView?
        weak var container: TrackMapContainer?
        /// True while SwiftUI is updating the view; callbacks are then deferred so the model isn't changed mid-update.
        var isUpdating = false
        var lastInsets: EdgeInsets?

        private var shownTrack: Track?
        private var casing: MKMultiPolyline?
        private var appliedViewport: Viewport?
        private var hasSetInitialRegion = false
        private var interfaceOrientation: UIInterfaceOrientation = .unknown
        /// A user zoom/pan is in progress: the model is not applied until it ends (rule M1).
        private var gestureActive = false
        /// Set while this coordinator moves the camera, so those changes are never reported as the user's (M4).
        private var applyingProgrammatically = false
        private var needsZoomRangeUpdate = false

        private var mapView: MKMapView? { container?.mapView }

        /// Returns whether the shown track changed.
        @discardableResult
        func show(_ track: Track) -> Bool {
            guard let mapView, track != shownTrack else { return false }
            shownTrack = track
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations.filter { $0 is TrackEndpointAnnotation })

            let polylines = track.segments.map { segment in
                var coordinates = segment.points.map(\.coordinate)
                return MKPolyline(coordinates: &coordinates, count: coordinates.count)
            }
            let casing = MKMultiPolyline(polylines)
            self.casing = casing
            mapView.addOverlay(casing, level: .aboveRoads)
            mapView.addOverlay(MKMultiPolyline(polylines), level: .aboveRoads)

            if track.isLoop {
                mapView.addAnnotation(TrackEndpointAnnotation(kind: .startFinish, coordinate: track.start.coordinate))
            } else {
                mapView.addAnnotation(TrackEndpointAnnotation(kind: .start, coordinate: track.start.coordinate))
                mapView.addAnnotation(TrackEndpointAnnotation(kind: .finish, coordinate: track.finish.coordinate))
            }
            return true
        }

        private var rotationObserver: NSObjectProtocol?

        /// A landscapeLeft ↔ landscapeRight flip keeps the map's size, so layout alone wouldn't notice it.
        func observeDeviceRotation() {
            rotationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // The scene's interface orientation can update after the device notification; check a turn later.
                DispatchQueue.main.async { self?.checkInterfaceOrientation() }
            }
        }

        deinit {
            if let rotationObserver { NotificationCenter.default.removeObserver(rotationObserver) }
        }

        /// Reports screen rotations so the compass heading refers to the top of the screen; `.unknown` is ignored.
        func checkInterfaceOrientation() {
            guard let orientation = container?.window?.windowScene?.interfaceOrientation,
                  orientation != .unknown, orientation != interfaceOrientation else { return }
            interfaceOrientation = orientation
            if isUpdating {
                DispatchQueue.main.async { [parent] in parent?.onInterfaceOrientationChanged(orientation) }
            } else {
                parent?.onInterfaceOrientationChanged(orientation)
            }
        }

        /// A new track gets the default view anew, and the zoom range is re-measured at its latitude.
        func trackDidChange() {
            needsZoomRangeUpdate = true
        }

        func sizeChanged() {
            guard let target = appliedViewport ?? parent?.viewport else { return }
            appliedViewport = nil
            apply(target, animated: false)
            updateZoomRange()
        }

        func apply(_ viewport: Viewport, animated: Bool = true) {
            guard let mapView else { return }
            // A gesture whose last region change came while a finger was still down never got its end callback.
            // Once the model is back to Following (Re-centre, import) clear it silently: reporting now could undo
            // that change. While Browsing, wait — the map may still be decelerating from a fling.
            if gestureActive, parent?.mode == .following, !isFingerDown(mapView) { gestureActive = false }
            guard mapView.bounds.width > 0, mapView.bounds.height > 0,
                  !gestureActive, viewport != appliedViewport else { return }
            // M2: while browsing only the heading follows the model; the user's centre and zoom stay.
            if parent?.mode == .browsing, hasSetInitialRegion {
                appliedViewport = viewport
                guard Geo.angularDistance(viewport.heading, mapView.camera.heading) >= 0.5 else { return }
                let camera = mapView.camera.copy() as! MKMapCamera
                camera.heading = viewport.heading
                setCamera(camera, duration: animated ? 0.5 : 0)
                return
            }
            if !hasSetInitialRegion {
                // Start near the right scale; the distance correction below then makes it exact.
                hasSetInitialRegion = true
                mapView.setRegion(
                    MKCoordinateRegion(center: viewport.center, latitudinalMeters: viewport.width, longitudinalMeters: viewport.width),
                    animated: false
                )
            }
            let camera = mapView.camera.copy() as! MKMapCamera
            camera.centerCoordinate = viewport.center
            camera.heading = viewport.heading
            camera.pitch = 0
            // Rescale only for a real width change, so following doesn't compound measurement jitter.
            if let currentWidth = currentWidthInMetres(), currentWidth > 0, abs(viewport.width / currentWidth - 1) >= 0.01 {
                camera.centerCoordinateDistance = mapView.camera.centerCoordinateDistance * viewport.width / currentWidth
            }
            let headingChanged = Geo.angularDistance(viewport.heading, mapView.camera.heading) >= 0.5
            let firstApplication = appliedViewport == nil
            appliedViewport = viewport
            setCamera(camera, duration: animated ? (headingChanged ? 0.5 : 0.25) : 0)
            if firstApplication { updateZoomRange() }
        }

        private func setCamera(_ camera: MKMapCamera, duration: TimeInterval) {
            guard let mapView else { return }
            applyingProgrammatically = true
            defer { applyingProgrammatically = false }
            if duration > 0 {
                UIView.animate(withDuration: duration, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
                    mapView.camera = camera
                }
            } else {
                mapView.camera = camera
            }
        }

        /// Pinch limits of 100 m – 20 km view width, as camera distances (distance is proportional to width).
        private func updateZoomRange() {
            guard let mapView, let width = currentWidthInMetres(), width > 0 else { return }
            let distancePerMetre = mapView.camera.centerCoordinateDistance / width
            mapView.cameraZoomRange = MKMapView.CameraZoomRange(
                minCenterCoordinateDistance: Viewport.minWidth * distancePerMetre,
                maxCenterCoordinateDistance: Viewport.maxWidth * distancePerMetre
            )
        }

        private var currentCenterAndWidth: (CLLocationCoordinate2D, Double)? {
            guard let mapView, let width = currentWidthInMetres() else { return nil }
            let center = mapView.convert(CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY), toCoordinateFrom: mapView)
            return (center, width)
        }

        private func isFingerDown(_ mapView: MKMapView) -> Bool {
            func active(_ view: UIView) -> Bool {
                let down = view.gestureRecognizers?.contains { [.began, .changed].contains($0.state) } ?? false
                return down || view.subviews.contains(where: active)
            }
            return active(mapView)
        }

        /// Whether a map gesture is driving this change: pan/pinch in progress, or a tap zoom just recognised.
        private func isUserGesture(_ mapView: MKMapView) -> Bool {
            func active(_ view: UIView) -> Bool {
                let recognised = view.gestureRecognizers?.contains { [.began, .changed, .ended].contains($0.state) } ?? false
                return recognised || view.subviews.contains(where: active)
            }
            return active(mapView)
        }

        /// Ground distance across the shorter side of the map, measured on the live map in map points.
        private func currentWidthInMetres() -> Double? {
            guard let mapView else { return nil }
            let mapPointsPerPoint = currentMapPointsPerPoint(mapView)
            let shorterSide = Double(min(mapView.bounds.width, mapView.bounds.height))
            return mapPointsPerPoint * shorterSide / MKMapPointsPerMeterAtLatitude(mapView.centerCoordinate.latitude)
        }

        private func currentMapPointsPerPoint(_ mapView: MKMapView) -> Double {
            let mid = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
            let offset: CGFloat = 100
            let a = MKMapPoint(mapView.convert(mid, toCoordinateFrom: mapView))
            let b = MKMapPoint(mapView.convert(CGPoint(x: mid.x + offset, y: mid.y), toCoordinateFrom: mapView))
            return hypot(b.x - a.x, b.y - a.y) / Double(offset)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard !applyingProgrammatically, !gestureActive, isUserGesture(mapView) else { return }
            // M3: report at gesture start so "Re-centre" appears at once and following stops.
            gestureActive = true
            if let (center, width) = currentCenterAndWidth { parent?.onUserChangedCamera(center, width) }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Measured once the camera has settled, not mid-animation.
            if needsZoomRangeUpdate, !gestureActive {
                needsZoomRangeUpdate = false
                updateZoomRange()
            }
            // A cancelled animation can finish after the gesture started; wait until no finger is driving the map.
            guard gestureActive, !isFingerDown(mapView) else { return }
            gestureActive = false
            // M3: report the final view, then resume applying the model (e.g. a heading that changed meanwhile).
            if let (center, width) = currentCenterAndWidth { parent?.onUserChangedCamera(center, width) }
            appliedViewport = nil
            if let viewport = parent?.viewport { apply(viewport) }
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            refreshVisibleArea()
        }

        /// Redraws the chevrons and reports the visible area for what the map shows right now.
        func refreshVisibleArea() {
            guard let parent, let container, let mapView, mapView.bounds.width > 0,
                  let width = currentWidthInMetres() else { return }
            // The coordinate actually drawn at the screen centre, which is what `VisibleArea` projects around.
            let screenCenter = mapView.convert(CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY), toCoordinateFrom: mapView)
            let area = VisibleArea(
                mapSize: mapView.bounds.size,
                insets: parent.insets,
                viewport: Viewport(center: screenCenter, width: width, heading: mapView.camera.heading)
            )
            container.chevronView.chevrons = parent.geometry.chevrons(
                in: area, project: area.project, spacing: TrackMapView.chevronSpacing
            )
            if isUpdating {
                DispatchQueue.main.async { parent.onVisibleAreaChanged(area) }
            } else {
                parent.onVisibleAreaChanged(area)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let multi = overlay as? MKMultiPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKMultiPolylineRenderer(multiPolyline: multi)
            renderer.lineCap = .round
            renderer.lineJoin = .round
            if multi === casing {
                renderer.strokeColor = .white
                renderer.lineWidth = 9
            } else {
                renderer.strokeColor = .systemPurple
                renderer.lineWidth = 6
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let endpoint = annotation as? TrackEndpointAnnotation else { return nil }
            let id = "endpoint"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: endpoint, reuseIdentifier: id)
            view.annotation = endpoint
            view.image = endpoint.kind.image
            view.centerOffset = CGPoint(x: (view.image?.size.width ?? 0) / 2 - 4, y: -(view.image?.size.height ?? 0) / 2)
            view.displayPriority = .required
            view.accessibilityLabel = endpoint.kind.label
            return view
        }
    }
}

final class TrackMapContainer: UIView {
    let mapView = MKMapView()
    let chevronView = ChevronLayerView()
    var onLayout: (() -> Void)?
    private var lastSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.insetsLayoutMarginsFromSafeArea = false
        mapView.accessibilityIdentifier = "trackMap"
        chevronView.isUserInteractionEnabled = false
        addSubview(mapView)
        addSubview(chevronView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        chevronView.frame = bounds
        if bounds.size != lastSize {
            lastSize = bounds.size
            onLayout?()
        }
    }
}

/// Draws the direction chevrons in screen space, above the map.
final class ChevronLayerView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
    private var shapeLayer: CAShapeLayer { layer as! CAShapeLayer }

    var chevrons: [Chevron] = [] {
        didSet { shapeLayer.path = Self.path(for: chevrons) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor(white: 0.15, alpha: 1).cgColor
        shapeLayer.lineWidth = 1
        shapeLayer.lineJoin = .round
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// An arrowhead 10 pt wide pointing "up" before rotation.
    private static let shape: [CGPoint] = [
        CGPoint(x: 0, y: -6), CGPoint(x: 5, y: 4), CGPoint(x: 0, y: 1), CGPoint(x: -5, y: 4),
    ]

    private static func path(for chevrons: [Chevron]) -> CGPath {
        let path = CGMutablePath()
        for chevron in chevrons {
            let transform = CGAffineTransform(translationX: chevron.position.x, y: chevron.position.y)
                .rotated(by: chevron.angle.radians)
            path.addLines(between: shape, transform: transform)
            path.closeSubpath()
        }
        return path
    }
}

final class TrackEndpointAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case start, finish, startFinish

        var label: String {
            switch self {
            case .start: "Track start"
            case .finish: "Track finish"
            case .startFinish: "Track start and finish"
            }
        }

        var image: UIImage? {
            let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            let (name, color): (String, UIColor) = switch self {
            case .start: ("flag.fill", .systemGreen)
            case .finish: ("flag.checkered", .label)
            case .startFinish: ("flag.2.crossed.fill", .systemGreen)
            }
            return UIImage(systemName: name, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
    }

    let kind: Kind
    let coordinate: CLLocationCoordinate2D

    init(kind: Kind, coordinate: CLLocationCoordinate2D) {
        self.kind = kind
        self.coordinate = coordinate
    }
}
