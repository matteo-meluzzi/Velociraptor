import SwiftUI

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: SpeedViewModel
    @StateObject private var altitudeViewModel: AltitudeViewModel

    init() {
        _speedViewModel = StateObject(wrappedValue: SpeedViewModel(locationProvider: LocationManager(behavior: SpeedBehavior())))
        _altitudeViewModel = StateObject(wrappedValue: AltitudeViewModel(locationProvider: LocationManager(behavior: AltitudeBehavior())))
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
