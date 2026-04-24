import Testing
import Combine
import CoreLocation
@testable import Velociraptor

final class MockAuthorizationProvider: AuthorizationProviding {
    private let subject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var publisher: AnyPublisher<CLAuthorizationStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(status: CLAuthorizationStatus) {
        subject = CurrentValueSubject(status)
    }

    func send(_ status: CLAuthorizationStatus) { subject.send(status) }
}

@MainActor
struct LocationStatusViewModelTests {
    @Test func deniedAuthMarksUnavailable() {
        let publisher = MockAuthorizationProvider(status: .denied)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == false)
    }

    @Test func authorizedWhenInUseMarksAvailable() {
        let publisher = MockAuthorizationProvider(status: .authorizedWhenInUse)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == true)
    }

    @Test func authorizedAlwaysMarksAvailable() {
        let publisher = MockAuthorizationProvider(status: .authorizedAlways)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == true)
    }

    @Test func transitionFromDeniedToAuthorized() {
        let publisher = MockAuthorizationProvider(status: .denied)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == false)
        publisher.send(.authorizedWhenInUse)
        #expect(vm.isAvailable == true)
    }
}
