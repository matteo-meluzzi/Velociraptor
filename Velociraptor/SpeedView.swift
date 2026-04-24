import Combine
import SwiftUI

@MainActor
final class SpeedViewModel: ObservableObject {
    @Published var displaySpeed: String = "0.0"

    private let locationProvider: any LocationProviding<Double?>
    private var cancellables = Set<AnyCancellable>()

    init(locationProvider: any LocationProviding<Double?>) {
        self.locationProvider = locationProvider
        locationProvider.valuePublisher
            .sink { [weak self] speed in
                self?.displaySpeed = String(format: "%.1f", (speed ?? 0) * 3.6)
            }
            .store(in: &cancellables)
    }
}

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(viewModel.displaySpeed)
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text("km/h")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
