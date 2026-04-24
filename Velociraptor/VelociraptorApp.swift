import SwiftUI

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: SpeedViewModel
    @StateObject private var altitudeViewModel: AltitudeViewModel

    init() {
        let manager = LocationManager()
        _speedViewModel = StateObject(wrappedValue: SpeedViewModel(locationProvider: manager))
        _altitudeViewModel = StateObject(wrappedValue: AltitudeViewModel(locationProvider: manager))
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Spacer()
                SpeedView(viewModel: speedViewModel)
                AltitudeView(viewModel: altitudeViewModel)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
