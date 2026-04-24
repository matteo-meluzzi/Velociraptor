import SwiftUI
import CoreLocation
import Combine

struct ContentView : View {
    @ObservedObject var speedViewModel: OneValueModel
    @ObservedObject var altitudeViewModel: OneValueModel
    @ObservedObject var altitudeChangeViewModel: SamplesModel
    @ObservedObject var locationStatusViewModel: LocationStatusViewModel
    @ObservedObject var accelerationViewModel: FirstDerivativeSamplesModel

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            AltitudeView(viewModel: altitudeViewModel)
            AltitudeChangeView(viewModel: altitudeChangeViewModel)
            SpeedView(viewModel: speedViewModel)
            AccelerationView(viewModel: accelerationViewModel)
            LocationStatusView(viewModel: locationStatusViewModel)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: OneValueModel
    @StateObject private var altitudeViewModel: OneValueModel
    @StateObject private var altitudeChangeViewModel: SamplesModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel
    @StateObject private var accelerationViewModel: FirstDerivativeSamplesModel

    init() {
        _speedViewModel = StateObject(wrappedValue: OneValueModel(LocationPublisher(behavior: MetersPerSecondToKmh(inner: NilToZero(inner: SpeedBehavior())))))
        _altitudeViewModel = StateObject(wrappedValue: OneValueModel(LocationPublisher(behavior: NilToZero(inner: AltitudeBehavior()))))
        _altitudeChangeViewModel = StateObject(wrappedValue: SamplesModel(LocationPublisher(behavior: Timestamped(inner: NilToZero(inner: AltitudeBehavior())))))
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(AuthorizationStatusPublisher()))
        _accelerationViewModel = StateObject(wrappedValue: FirstDerivativeSamplesModel(SamplesModel(LocationPublisher(behavior: Timestamped(inner: NilToZero(inner: SpeedBehavior()))))))
        
        CLLocationManager().requestWhenInUseAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(speedViewModel: speedViewModel, altitudeViewModel: altitudeViewModel, altitudeChangeViewModel: altitudeChangeViewModel, locationStatusViewModel: locationStatusViewModel, accelerationViewModel: accelerationViewModel)
        }
    }
}

final class MockLocationProvider<T>: LocationProviding {
    private let valueSubject: CurrentValueSubject<T, Never>

    var publisher: AnyPublisher<T, Never> { valueSubject.eraseToAnyPublisher() }

    init(initialValue: T) {
        valueSubject = CurrentValueSubject(initialValue)
    }

    func send(value: T) { valueSubject.send(value) }
}
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
#Preview {
    let speedModel = MockLocationProvider(initialValue: 0.0)
    let altitudeModel = MockLocationProvider(initialValue: 0.0)
    let altitudeChangeModel = MockLocationProvider(initialValue: (Date(), 0.0))
    let accelModel = MockLocationProvider(initialValue: (Date(), 0.0))
    var speed = 0.0
    var altitude = 0.0
    VStack {
        ContentView(speedViewModel: OneValueModel(speedModel), altitudeViewModel: OneValueModel(altitudeModel), altitudeChangeViewModel: SamplesModel(altitudeChangeModel), locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)), accelerationViewModel: FirstDerivativeSamplesModel(SamplesModel(accelModel)))
        
        HStack {
            VStack {
                Button {
                    speedModel.send(value: speed)
                    accelModel.send(value: (Date(), speed))
                    speed += 1
                } label: {
                    Text("accelerate")
                }
                Button {
                    speedModel.send(value: speed)
                    accelModel.send(value: (Date(), speed))
                    speed -= 1
                } label: {
                    Text("decelerate")
                }
            }
            VStack {
                Button {
                    altitudeModel.send(value: altitude)
                    altitudeChangeModel.send(value: (Date(), altitude))
                    altitude += 1
                } label: {
                    Text("higher")
                }
                Button {
                    altitudeModel.send(value: altitude)
                    altitudeChangeModel.send(value: (Date(), altitude))
                    altitude -= 1
                } label: {
                    Text("lower")
                }
            }
        }
    }
}
