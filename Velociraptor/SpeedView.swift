import Combine
import SwiftUI

@MainActor
final class SpeedViewModel: ObservableObject {
    @Published var displaySpeed: String = "0.0"
    @Published var isLocationAvailable: Bool = false

    private let locationProvider: LocationProviding
    private var cancellables = Set<AnyCancellable>()

    init(locationProvider: LocationProviding) {
        self.locationProvider = locationProvider
        bindPublishers()
    }

    private func bindPublishers() {
        locationProvider.valuePublisher
            .sink { [weak self] speed in
                guard let self else { return }
                self.displaySpeed = String(format: "%.1f", (speed ?? 0) * 3.6)
            }
            .store(in: &cancellables)

        locationProvider.authorizationStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    self.isLocationAvailable = true
                case .denied, .restricted:
                    self.isLocationAvailable = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text(viewModel.displaySpeed)
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()

            Text("km/h")
                .font(.title2)
                .foregroundStyle(.secondary)

            if !viewModel.isLocationAvailable {
                Text("Location unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}
