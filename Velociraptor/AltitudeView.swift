import Combine
import SwiftUI

@MainActor
final class AltitudeViewModel: ObservableObject {
    @Published var displayAltitude: String = "– m"

    private let locationProvider: any LocationProviding<Double?>
    private var cancellables = Set<AnyCancellable>()

    init(locationProvider: any LocationProviding<Double?>) {
        self.locationProvider = locationProvider
        bindPublishers()
    }

    private func bindPublishers() {
        locationProvider.valuePublisher
            .sink { [weak self] altitude in
                guard let self else { return }
                if let altitude {
                    self.displayAltitude = "\(Int(altitude.rounded())) m"
                } else {
                    self.displayAltitude = "– m"
                }
            }
            .store(in: &cancellables)
    }
}

struct AltitudeView: View {
    @ObservedObject var viewModel: AltitudeViewModel

    var body: some View {
        Text(viewModel.displayAltitude)
            .font(.title2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
