import SwiftUI

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Text(viewModel.displaySpeed)
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()

            Text("km/h")
                .font(.title2)
                .foregroundStyle(.secondary)

            if !viewModel.isLocationAvailable {
                Text("Location unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
