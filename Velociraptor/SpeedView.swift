import Combine
import SwiftUI

@MainActor
final class OneValueModel: ObservableObject {
    @Published var displayValue: String = "–"

    private let locationProvider: any LocationProviding<Double>
    private var cancellable: AnyCancellable?

    init(_ locationProvider: any LocationProviding<Double>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] value in
                self?.displayValue = String(format: "%.1f", value)
            }
    }
}

struct SpeedView: View {
    @ObservedObject var viewModel: OneValueModel

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(viewModel.displayValue)
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text("km/h")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
