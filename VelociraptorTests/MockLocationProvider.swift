import Combine
import CoreLocation
@testable import Velociraptor

final class MockLocationProvider<T>: LocationProviding {
    private let valueSubject: CurrentValueSubject<T, Never>

    var valuePublisher: AnyPublisher<T, Never> { valueSubject.eraseToAnyPublisher() }

    init(initialValue: T) {
        valueSubject = CurrentValueSubject(initialValue)
    }

    func requestAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}

    func send(value: T) { valueSubject.send(value) }
}
