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
    @Published var altitudeSamples: [Sample] = []

    private let locationProvider: any LocationProviding<TimestampedValue<Double>>
    private var cancellable: AnyCancellable?
    
    init(_ locationProvider: any LocationProviding<TimestampedValue<Double>>) {
        self.locationProvider = locationProvider
        cancellable = locationProvider.publisher
            .sink { [weak self] timestampedAltitude in
                guard let self else { return }
                altitudeSamples.append(Sample(index: altitudeSamples.count, date: timestampedAltitude.0, value: timestampedAltitude.1))
                altitudeSamples = Array(altitudeSamples.drop(while: {
                    timestampedAltitude.0.timeIntervalSince($0.date) > 60.0
                }))
            }
    }
}

@MainActor
final class FirstDerivativeSamplesModel: ObservableObject {
    @Published var derivedSamples: [Sample] = []

    private let samplesModel: SamplesModel
    private var cancellable: AnyCancellable?
    
    init(_ samplesModel: SamplesModel) {
        self.samplesModel = samplesModel
        cancellable = samplesModel.$altitudeSamples
            .sink { [weak self] timestampedSpeeds in
                guard let self else { return }
                derivedSamples = zip(timestampedSpeeds, timestampedSpeeds.dropFirst()).map { (prev, next) in
                    return Sample(index: next.index, date: next.date, value: (next.value - prev.value) / (next.date.timeIntervalSince(prev.date)))
                }
            }
    }
}
