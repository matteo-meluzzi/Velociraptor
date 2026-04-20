import Combine
import CoreLocation
import Foundation

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
        locationProvider.speedPublisher
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
