import Testing
import CoreLocation
@testable import Velociraptor

@MainActor
struct SpeedViewModelTests {
    @Test func unavailableSpeedShowsZero() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: nil)
        #expect(vm.displaySpeed == "0.0")
    }

    @Test func lowSpeedFormatsCorrectly() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: 3.2 / 3.6)
        #expect(vm.displaySpeed == "3.2")
    }

    @Test func higherSpeedFormatsCorrectly() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(value: 87.4 / 3.6)
        #expect(vm.displaySpeed == "87.4")
    }

    @Test func deniedAuthHidesLocation() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = SpeedViewModel(locationProvider: provider)
        provider.send(status: .denied)
        #expect(vm.isLocationAvailable == false)
    }

    @Test func authorizedAuthShowsLocation() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = SpeedViewModel(locationProvider: provider)
        #expect(vm.isLocationAvailable == true)
    }
}
