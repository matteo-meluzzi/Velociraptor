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
