import Combine
import SwiftUI

@MainActor
final class AltitudeViewModel: ObservableObject {
    @Published var displayAltitude: String = "–"

    private let locationProvider: any LocationProviding<Double?>
    private var cancellable: AnyCancellable?

    init(locationProvider: any LocationProviding<Double?>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] altitude in
                self?.displayAltitude = altitude.map { "\(Int($0.rounded()))" } ?? "–"
            }
    }
}

struct AltitudeView: View {
    @ObservedObject var viewModel: AltitudeViewModel

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(viewModel.displayAltitude)
                .font(.title2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("m")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
