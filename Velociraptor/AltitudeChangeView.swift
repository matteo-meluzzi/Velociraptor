import Combine
import CoreLocation
import SwiftUI
import Charts

struct AltitudeChangeView: View {
    @ObservedObject var viewModel: SamplesModel

    var body: some View {
        Chart(viewModel.altitudeSamples) { sample in
            LineMark(x: .value("Time", sample.date), y: .value("Altitude", sample.value))
        }
    }
}
