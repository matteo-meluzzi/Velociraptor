import Combine
import CoreLocation
import SwiftUI
import Charts

struct AltitudeChangeView: View {
    @ObservedObject var viewModel: SkipFirstSamplesModel

    var body: some View {
        Chart(viewModel.samples) { sample in
            LineMark(x: .value("Time", sample.date), y: .value("Altitude", sample.value))
        }
    }
}
