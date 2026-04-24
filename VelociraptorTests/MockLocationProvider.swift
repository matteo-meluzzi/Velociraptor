import Combine
import CoreLocation
@testable import Velociraptor

final class MockLocationProvider<T>: LocationProviding {
    private let valueSubject: CurrentValueSubject<T, Never>
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)

    var valuePublisher: AnyPublisher<T, Never> { valueSubject.eraseToAnyPublisher() }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { authorizationSubject.eraseToAnyPublisher() }

    init(initialValue: T) {
        valueSubject = CurrentValueSubject(initialValue)
    }

    func requestAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}

    func send(value: T) { valueSubject.send(value) }
    func send(status: CLAuthorizationStatus) { authorizationSubject.send(status) }
}
