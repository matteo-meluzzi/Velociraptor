import Combine
import SwiftUI

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
