import Combine
import SwiftUI

struct AltitudeView: View {
    @ObservedObject var viewModel: OneValueModel

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(viewModel.displayValue)
                .font(.title2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("m")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
