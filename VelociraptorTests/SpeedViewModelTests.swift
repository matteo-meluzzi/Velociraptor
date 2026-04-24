import Testing
import Combine
import CoreLocation
@testable import Velociraptor

final class MockLocationProvider: LocationProviding {
    private let valueSubject = CurrentValueSubject<Double?, Never>(nil)
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)

    var valuePublisher: AnyPublisher<Double?, Never> { valueSubject.eraseToAnyPublisher() }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { authorizationSubject.eraseToAnyPublisher() }

    func requestAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}

    func send(value: Double?) { valueSubject.send(value) }
    func send(status: CLAuthorizationStatus) { authorizationSubject.send(status) }
}

@MainActor
struct SpeedViewModelTests {
    @Test func unavailableSpeedShowsZero() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: nil)
        #expect(vm.displaySpeed == "0.0")
    }

    @Test func lowSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: 3.2 / 3.6)
        #expect(vm.displaySpeed == "3.2")
    }

    @Test func higherSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: 87.4 / 3.6)
        #expect(vm.displaySpeed == "87.4")
    }

    @Test func deniedAuthHidesLocation() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(status: .denied)
        #expect(vm.isLocationAvailable == false)
    }

    @Test func authorizedAuthShowsLocation() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        #expect(vm.isLocationAvailable == true)
    }
}
