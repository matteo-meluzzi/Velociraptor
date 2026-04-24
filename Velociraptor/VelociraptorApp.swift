import SwiftUI

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: SpeedViewModel
    @StateObject private var altitudeViewModel: AltitudeViewModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel

    init() {
        let speedManager = LocationManager(behavior: SpeedBehavior())
        _speedViewModel = StateObject(wrappedValue: SpeedViewModel(locationProvider: speedManager))
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(authorizationPublisher: speedManager.authorizationStatusPublisher))
        _altitudeViewModel = StateObject(wrappedValue: AltitudeViewModel(locationProvider: LocationManager(behavior: AltitudeBehavior())))
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Spacer()
                SpeedView(viewModel: speedViewModel)
                AltitudeView(viewModel: altitudeViewModel)
                LocationStatusView(viewModel: locationStatusViewModel)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
