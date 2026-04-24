import Testing
import Combine
import CoreLocation
@testable import Velociraptor

final class MockLocationProvider: LocationProviding {
    private let speedSubject = CurrentValueSubject<Double?, Never>(nil)
    private let altitudeSubject = CurrentValueSubject<Double?, Never>(nil)
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)

    var speedPublisher: AnyPublisher<Double?, Never> { speedSubject.eraseToAnyPublisher() }
    var altitudePublisher: AnyPublisher<Double?, Never> { altitudeSubject.eraseToAnyPublisher() }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { authorizationSubject.eraseToAnyPublisher() }

    func requestAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}

    func send(speed: Double?) { speedSubject.send(speed) }
    func send(altitude: Double?) { altitudeSubject.send(altitude) }
    func send(status: CLAuthorizationStatus) { authorizationSubject.send(status) }
}

@MainActor
struct SpeedViewModelTests {
    @Test func unavailableSpeedShowsZero() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: nil)
        #expect(vm.displaySpeed == "0.0")
    }

    @Test func lowSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: 3.2 / 3.6)
        #expect(vm.displaySpeed == "3.2")
    }

    @Test func higherSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: 87.4 / 3.6)
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
