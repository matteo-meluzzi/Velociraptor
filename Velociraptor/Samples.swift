//
//  Sample.swift
//  Velociraptor
//
//  Created by Matteo Meluzzi on 24/04/26.
//

import Combine
import CoreLocation
import SwiftUI
import Charts

struct Sample: Identifiable {
    var id: Int {
        return index
    }
    
    let index: Int
    let date: Date
    let value: Double
}

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

@MainActor
final class SamplesModel: ObservableObject {
    @Published var samples: [Sample] = []

    private let locationProvider: any LocationProviding<TimestampedValue<Double>>
    private var cancellable: AnyCancellable?
    
    init(_ locationProvider: any LocationProviding<TimestampedValue<Double>>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] timestampedAltitude in
                guard let self else { return }
                samples.append(Sample(index: samples.count, date: timestampedAltitude.0, value: timestampedAltitude.1))
                samples = Array(samples.drop(while: {
                    timestampedAltitude.0.timeIntervalSince($0.date) > 60.0
                }))
            }
    }
}

@MainActor
final class SkipFirstSamplesModel: ObservableObject {
    @Published var samples: [Sample] = []

    private let samplesModel: SamplesModel
    private var cancellable: AnyCancellable?
    private var skipIndex: Int?
    
    init(_ samplesModel: SamplesModel) {
        self.samplesModel = samplesModel
        cancellable = samplesModel.$samples
            .sink { [weak self] samples in
                guard let self else { return }
                guard let firstSample = samples.first else { return }
                guard let skipIndex = self.skipIndex else {
                    self.skipIndex = firstSample.id
                    return
                }
                self.samples = samples.filter({ sample in
                    sample.id != skipIndex
                })
            }
    }
}

@MainActor
final class FirstDerivativeSamplesModel: ObservableObject {
    @Published var samples: [Sample] = []

    private let samplesModel: SamplesModel
    private var cancellable: AnyCancellable?
    
    init(_ samplesModel: SamplesModel) {
        self.samplesModel = samplesModel
        cancellable = samplesModel.$samples
            .sink { [weak self] timestampedSpeeds in
                guard let self else { return }
                samples = zip(timestampedSpeeds, timestampedSpeeds.dropFirst()).map { (prev, next) in
                    return Sample(index: next.index, date: next.date, value: (next.value - prev.value) / (next.date.timeIntervalSince(prev.date)))
                }
            }
    }
}
