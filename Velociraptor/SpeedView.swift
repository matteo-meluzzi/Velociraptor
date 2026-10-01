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
    /// Smaller size used over the track map; digits stay ≥ ⅓ of the full size so they read at arm's length.
    var compact = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: compact ? 4 : 8) {
            Text(viewModel.displayValue)
                .font(.system(size: compact ? 44 : 120, weight: compact ? .light : .thin, design: .rounded))
                .monospacedDigit()
            Text("km/h")
                .font(compact ? .caption : .title2)
                .foregroundStyle(.secondary)
        }
    }
}
