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
    /// Digit size; smaller over the track map. The digits may shrink to fit the width, but never below
    /// 40 pt (⅓ of the full size, readable at arm's length).
    var digitSize: CGFloat = 120

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: digitSize >= 80 ? 8 : 4) {
            Text(viewModel.displayValue)
                .font(.system(size: digitSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(min(1, 40 / digitSize))
            Text("km/h")
                .font(digitSize >= 80 ? .title2 : .caption)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
}
