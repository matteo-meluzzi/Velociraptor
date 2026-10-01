import Testing
@testable import Velociraptor

@MainActor
struct SpeedViewModelTests {
    @Test func initialValueIsFormatted() {
        let provider = MockLocationProvider<Double>(initialValue: 0.0)
        let vm = OneValueModel(provider)
        #expect(vm.displayValue == "0.0")
    }

    @Test func lowSpeedFormatsCorrectly() {
        let provider = MockLocationProvider<Double>(initialValue: 0.0)
        let vm = OneValueModel(provider)
        provider.send(value: 3.2)
        #expect(vm.displayValue == "3.2")
    }

    @Test func higherSpeedFormatsCorrectly() {
        let provider = MockLocationProvider<Double>(initialValue: 0.0)
        let vm = OneValueModel(provider)
        provider.send(value: 87.4)
        #expect(vm.displayValue == "87.4")
    }

    @Test func valueIsRoundedToOneDecimal() {
        let provider = MockLocationProvider<Double>(initialValue: 0.0)
        let vm = OneValueModel(provider)
        provider.send(value: 12.36)
        #expect(vm.displayValue == "12.4")
    }
}
