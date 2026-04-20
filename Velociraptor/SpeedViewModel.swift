import Combine
import CoreLocation
import Foundation

@MainActor
final class SpeedViewModel: ObservableObject {
    @Published var displaySpeed: String = "– –"
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
                if speed < 0 {
                    self.displaySpeed = "– –"
                    self.isLocationAvailable = false
                } else {
                    self.displaySpeed = String(format: "%.1f", speed * 3.6)
                    self.isLocationAvailable = true
                }
            }
            .store(in: &cancellables)

        locationProvider.authorizationStatusPublisher
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    break
                case .denied, .restricted:
                    self.isLocationAvailable = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
