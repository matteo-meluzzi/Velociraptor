import Testing
import Combine
import CoreLocation
@testable import Velociraptor

final class MockLocationProvider: LocationProviding {
    private let speedSubject = CurrentValueSubject<Double, Never>(-1)
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)

    var speedPublisher: AnyPublisher<Double, Never> { speedSubject.eraseToAnyPublisher() }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { authorizationSubject.eraseToAnyPublisher() }

    func requestAuthorization() {}
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}

    func send(speed: Double) { speedSubject.send(speed) }
    func send(status: CLAuthorizationStatus) { authorizationSubject.send(status) }
}

@MainActor
struct SpeedViewModelTests {
    @Test func unavailableSpeedShowsDashes() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: -1)
        #expect(vm.displaySpeed == "– –")
        #expect(vm.isLocationAvailable == false)
    }

    @Test func lowSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: 3.2 / 3.6)
        #expect(vm.displaySpeed == "3.2")
        #expect(vm.isLocationAvailable == true)
    }

    @Test func higherSpeedFormatsCorrectly() {
        let provider = MockLocationProvider()
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(speed: 87.4 / 3.6)
        #expect(vm.displaySpeed == "87.4")
        #expect(vm.isLocationAvailable == true)
    }
}
