import SwiftUI

/// The full-screen track map with its overlays. `insets` are the heights of the panels drawn on top of it.
struct TrackView: View {
    @ObservedObject var viewModel: TrackViewModel
    let insets: EdgeInsets
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            if let track = viewModel.track, let geometry = viewModel.geometry {
                TrackMapView(
                    track: track,
                    geometry: geometry,
                    viewport: viewModel.viewport,
                    insets: insets,
                    onVisibleAreaChanged: { viewModel.visibleAreaChanged($0) },
                    onUserChangedCamera: { viewModel.userChangedCamera(center: $0, width: $1) }
                )
                .ignoresSafeArea()
            }
            if let arrow = viewModel.arrow {
                GeometryReader { proxy in
                    let visibleRect = CGRect(
                        x: 0, y: insets.top,
                        width: proxy.size.width,
                        height: max(0, proxy.size.height - insets.top - insets.bottom)
                    )
                    let screenAngle = arrow.bearing - viewModel.displayedMapHeading
                    OffTrackArrowView(arrow: arrow, screenAngle: screenAngle)
                        .position(ArrowPlacement.position(in: visibleRect, screenAngle: screenAngle, margin: 44))
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            if let message = viewModel.locationMessage {
                locationMessage(message)
                    .padding(.top, insets.top + 8)
                    .padding(.horizontal)
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
    /// Where a ray from the centre of `visibleRect` (inset by `margin`) at `screenAngle`
    /// (degrees, 0 = up, clockwise) meets the inset rectangle's border.
    static func position(in visibleRect: CGRect, screenAngle: Double, margin: CGFloat = 32) -> CGPoint {
        let inner = visibleRect.insetBy(dx: margin, dy: margin)
        let center = CGPoint(x: inner.midX, y: inner.midY)
        let radians = screenAngle * .pi / 180
        let dx = sin(radians), dy = -cos(radians)
        var t = CGFloat.infinity
        if abs(dx) > 1e-9 { t = min(t, (dx > 0 ? inner.maxX - center.x : inner.minX - center.x) / dx) }
        if abs(dy) > 1e-9 { t = min(t, (dy > 0 ? inner.maxY - center.y : inner.minY - center.y) / dy) }
        if !t.isFinite { return center }
        return CGPoint(x: center.x + t * dx, y: center.y + t * dy)
    }
}
