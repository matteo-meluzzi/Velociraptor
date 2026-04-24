import Testing
import Combine
import CoreLocation
@testable import Velociraptor

final class MockAuthorizationStatusPublisher: AuthorizationStatusPublisher {
    private let subject: CurrentValueSubject<CLAuthorizationStatus, Never>

    override var publisher: AnyPublisher<CLAuthorizationStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(status: CLAuthorizationStatus) {
        subject = CurrentValueSubject(status)
        super.init()
    }

    func send(_ status: CLAuthorizationStatus) { subject.send(status) }
}

@MainActor
struct LocationStatusViewModelTests {
    @Test func deniedAuthMarksUnavailable() {
        let publisher = MockAuthorizationStatusPublisher(status: .denied)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == false)
    }

    @Test func authorizedWhenInUseMarksAvailable() {
        let publisher = MockAuthorizationStatusPublisher(status: .authorizedWhenInUse)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == true)
    }

    @Test func authorizedAlwaysMarksAvailable() {
        let publisher = MockAuthorizationStatusPublisher(status: .authorizedAlways)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == true)
    }

    @Test func transitionFromDeniedToAuthorized() {
        let publisher = MockAuthorizationStatusPublisher(status: .denied)
        let vm = LocationStatusViewModel(publisher)
        #expect(vm.isAvailable == false)
        publisher.send(.authorizedWhenInUse)
        #expect(vm.isAvailable == true)
    }
}
