import Combine
import CoreLocation
import SwiftUI
import Charts

struct AccelerationView: View {
    @ObservedObject var viewModel: FirstDerivativeSamplesModel

    var body: some View {
        Chart(viewModel.derivedSamples) { sample in
            LineMark(x: .value("Time", sample.date), y: .value("Acceleration", sample.value))
        }
    }
}
