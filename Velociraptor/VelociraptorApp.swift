import SwiftUI

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: SpeedViewModel
    @StateObject private var altitudeViewModel: AltitudeViewModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel

    init() {
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(AuthorizationStatusPublisher()))
        _speedViewModel = StateObject(wrappedValue: SpeedViewModel(locationProvider: LocationPublisher(behavior: SpeedBehavior())))
        _altitudeViewModel = StateObject(wrappedValue: AltitudeViewModel(locationProvider: LocationPublisher(behavior: AltitudeBehavior())))
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
