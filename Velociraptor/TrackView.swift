import SwiftUI

/// The full-screen track map with its overlays. `insets` are the heights of the panels drawn on top of it.
struct TrackView: View {
    @ObservedObject var viewModel: TrackViewModel
    let insets: EdgeInsets
    /// Where the map places the user when following; see `TrackMapView.cameraInsets`.
    var cameraInsets: EdgeInsets? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            if let track = viewModel.track, let geometry = viewModel.geometry {
                TrackMapView(
                    track: track,
                    geometry: geometry,
                    viewport: viewModel.viewport,
                    mode: viewModel.mode,
                    insets: insets,
                    cameraInsets: cameraInsets ?? insets,
                    onVisibleAreaChanged: { viewModel.visibleAreaChanged($0) },
                    onUserChangedCamera: { viewModel.userChangedCamera(center: $0, width: $1) },
                    onInterfaceOrientationChanged: { viewModel.interfaceOrientationChanged($0) }
                )
                .ignoresSafeArea()
            }
            if Geo.angularDistance(viewModel.displayedMapHeading, 0) >= 1 {
                NorthIndicator(heading: viewModel.displayedMapHeading)
                    .padding(.top, insets.top + 12)
                    .padding(.leading, insets.leading + 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            if let arrow = viewModel.arrow {
                GeometryReader { proxy in
                    let visibleRect = CGRect(
                        x: insets.leading, y: insets.top,
                        width: max(0, proxy.size.width - insets.leading - insets.trailing),
                        height: max(0, proxy.size.height - insets.top - insets.bottom)
                    )
                    let screenAngle = arrow.bearing - viewModel.displayedMapHeading
                    // From the camera centre: where the map draws the user while Following, so the arrow never
                    // lands on their dot (006 FR-014). While Browsing it is wherever the user panned to.
                    let camera = cameraInsets ?? insets
                    let user = CGPoint(
                        x: (camera.leading + proxy.size.width - camera.trailing) / 2,
                        y: (camera.top + proxy.size.height - camera.bottom) / 2
                    )
                    OffTrackArrowView(arrow: arrow, screenAngle: screenAngle)
                        .position(ArrowPlacement.position(in: visibleRect, screenAngle: screenAngle, margin: 44, from: user))
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            if viewModel.showsRecentreButton {
                Button { viewModel.recentreTapped() } label: {
                    Label("Re-centre", systemImage: "location.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("recentreButton")
                .padding(.bottom, insets.bottom + 16)
                .padding(.leading, insets.leading)
                .padding(.trailing, insets.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
            }
            if let message = viewModel.locationMessage {
                locationMessage(message)
                    .padding(.top, insets.top + 8)
                    .padding(.leading, insets.leading + 16)
                    .padding(.trailing, insets.trailing + 16)
                    .ignoresSafeArea()
            }
        }
    }

    private func locationMessage(_ message: LocationMessage) -> some View {
        VStack(spacing: 6) {
            switch message {
            case .unknown:
                Text("Waiting for your location…")
            case .denied:
                Text("Location access is off. Showing the start of the track.")
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .accessibilityIdentifier("trackOpenSettingsButton")
            }
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trackLocationMessage")
    }
}

/// Shows where north is while the map is rotated. Follows the map's actual heading frame by frame.
private struct NorthIndicator: View {
    let heading: Double

    var body: some View {
        ZStack {
            Circle().fill(.regularMaterial)
            VStack(spacing: 0) {
                Text("N")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .rotationEffect(.degrees(-heading))
        }
        .frame(width: 40, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("North indicator")
        .accessibilityIdentifier("northIndicator")
    }
}

/// Arrow toward the nearest part of the track, with the distance to it.
private struct OffTrackArrowView: View {
    let arrow: OffTrackArrow
    let screenAngle: Double

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.purple)
                .rotationEffect(.degrees(screenAngle))
            Text(arrow.distanceText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Track is \(arrow.distanceText) away")
        .accessibilityValue(arrow.distanceText)
        .accessibilityIdentifier("offTrackArrow")
    }
}

enum ArrowPlacement {
    /// How close to the user the arrow may sit before it moves aside, so it doesn't cover their dot.
    static let userClearance: CGFloat = 64

    /// Where a ray from `origin` (default: the centre of `visibleRect`; kept inside the inset rectangle) at
    /// `screenAngle` (degrees, 0 = up, clockwise) meets the border of `visibleRect` inset by `margin`.
    /// When that point is within `userClearance` of `origin` (the track is behind a user drawn low on the map),
    /// the arrow sits `userClearance` from `origin` along the ray turned upwards: above the dot for straight behind,
    /// beside it for sideways. That keeps it continuous as the angle changes, with no flip across the dot.
    static func position(in visibleRect: CGRect, screenAngle: Double, margin: CGFloat = 32, from origin: CGPoint? = nil) -> CGPoint {
        let inner = visibleRect.insetBy(dx: margin, dy: margin)
        let start = origin.map {
            CGPoint(x: min(max($0.x, inner.minX), inner.maxX), y: min(max($0.y, inner.minY), inner.maxY))
        } ?? CGPoint(x: inner.midX, y: inner.midY)
        let radians = screenAngle * .pi / 180
        let dx = sin(radians), dy = -cos(radians)
        var t = CGFloat.infinity
        if abs(dx) > 1e-9 { t = min(t, (dx > 0 ? inner.maxX - start.x : inner.minX - start.x) / dx) }
        if abs(dy) > 1e-9 { t = min(t, (dy > 0 ? inner.maxY - start.y : inner.minY - start.y) / dy) }
        if !t.isFinite { return start }
        var point = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        if let origin, hypot(point.x - origin.x, point.y - origin.y) < userClearance {
            point = CGPoint(
                x: min(max(origin.x + userClearance * dx, inner.minX), inner.maxX),
                y: min(max(origin.y - userClearance * abs(dy), inner.minY), inner.maxY)
            )
        }
        return point
    }
}
