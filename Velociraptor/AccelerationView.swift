import Combine
import CoreLocation
import SwiftUI
import Charts

struct SpeedSample: Identifiable {
    var id: Int {
        return index
    }
    
    let index: Int
    let date: Date
    let acceleration: Double
}

@MainActor
final class AccelerationViewModel: ObservableObject {
    private var speedSamples: [TimestampedValue<Double>] = []
    @Published var accelerationSamples: [SpeedSample] = []

    private let locationProvider: any LocationProviding<TimestampedValue<Double>>
    private var cancellable: AnyCancellable?
    
    init(_ locationProvider: any LocationProviding<TimestampedValue<Double>>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] timestampedSpeed in
                guard let self else { return }
                speedSamples.append(timestampedSpeed)
                speedSamples = Array(speedSamples.drop(while: {
                    timestampedSpeed.0.timeIntervalSince($0.0) > 60.0
                }))
                accelerationSamples = zip(speedSamples, speedSamples.dropFirst()).enumerated().map { (index, samples) in
                    let (prev, next) = samples
                    return SpeedSample(index: index, date: next.0, acceleration: (next.1 - prev.1) / (next.0.timeIntervalSince(prev.0)))
                }
            }
    }
}

struct AccelerationView: View {
    @ObservedObject var viewModel: AccelerationViewModel

    var body: some View {
        Chart(viewModel.accelerationSamples) { sample in
            LineMark(x: .value("Time", sample.date), y: .value("Acceleration", sample.acceleration))
        }
    }
}
