import Testing
import Combine
import CoreLocation
@testable import Velociraptor

@MainActor
struct AltitudeViewModelTests {
    @Test func nilAltitudeShowsPlaceholder() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = AltitudeViewModel(locationProvider: provider)
        provider.send(value: nil)
        #expect(vm.displayAltitude == "–")
    }

    @Test func positiveAltitudeFormatsCorrectly() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = AltitudeViewModel(locationProvider: provider)
        provider.send(value: 52.4)
        #expect(vm.displayAltitude == "52")
    }

    @Test func negativeAltitudeFormatsCorrectly() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = AltitudeViewModel(locationProvider: provider)
        provider.send(value: -3.7)
        #expect(vm.displayAltitude == "-4")
    }

    @Test func transitionFromNilToRealReading() {
        let provider = MockLocationProvider<Double?>(initialValue: nil)
        let vm = AltitudeViewModel(locationProvider: provider)
        #expect(vm.displayAltitude == "–")
        provider.send(value: 52.0)
        #expect(vm.displayAltitude == "52")
    }
}
