import Combine
import CoreLocation
import SwiftUI
import Charts

struct AltitudeChangeSample: Identifiable {
    var id: Int {
        return index
    }
    
    let index: Int
    let date: Date
    let altitude: Double
}

@MainActor
final class AltitudeChangeViewModel: ObservableObject {
    @Published var altitudeSamples: [AltitudeChangeSample] = []

    private let locationProvider: any LocationProviding<TimestampedValue<Double>>
    private var cancellable: AnyCancellable?
    
    init(_ locationProvider: any LocationProviding<TimestampedValue<Double>>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] timestampedAltitude in
                guard let self else { return }
                altitudeSamples.append(AltitudeChangeSample(index: altitudeSamples.count, date: timestampedAltitude.0, altitude: timestampedAltitude.1))
                altitudeSamples = Array(altitudeSamples.drop(while: {
                    timestampedAltitude.0.timeIntervalSince($0.date) > 60.0
                }))
            }
    }
}

struct AltitudeChangeView: View {
    @ObservedObject var viewModel: AltitudeChangeViewModel

    var body: some View {
        Chart(viewModel.altitudeSamples) { sample in
            LineMark(x: .value("Time", sample.date), y: .value("Altitude", sample.altitude))
        }
    }
}
