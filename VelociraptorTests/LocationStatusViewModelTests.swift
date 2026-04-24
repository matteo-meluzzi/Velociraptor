import Testing
import Combine
import CoreLocation
@testable import Velociraptor

@MainActor
struct LocationStatusViewModelTests {
    @Test func deniedAuthMarksUnavailable() {
        let subject = CurrentValueSubject<CLAuthorizationStatus, Never>(.denied)
        let vm = LocationStatusViewModel(authorizationPublisher: subject.eraseToAnyPublisher())
        #expect(vm.isAvailable == false)
    }

    @Test func authorizedWhenInUseMarksAvailable() {
        let subject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)
        let vm = LocationStatusViewModel(authorizationPublisher: subject.eraseToAnyPublisher())
        #expect(vm.isAvailable == true)
    }

    @Test func authorizedAlwaysMarksAvailable() {
        let subject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedAlways)
        let vm = LocationStatusViewModel(authorizationPublisher: subject.eraseToAnyPublisher())
        #expect(vm.isAvailable == true)
    }

    @Test func transitionFromDeniedToAuthorized() {
        let subject = CurrentValueSubject<CLAuthorizationStatus, Never>(.denied)
        let vm = LocationStatusViewModel(authorizationPublisher: subject.eraseToAnyPublisher())
        #expect(vm.isAvailable == false)
        subject.send(.authorizedWhenInUse)
        #expect(vm.isAvailable == true)
    }
}
