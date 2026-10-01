import SwiftUI
import CoreLocation
import Combine

struct ContentView : View {
    @ObservedObject var speedViewModel: OneValueModel
    @ObservedObject var locationStatusViewModel: LocationStatusViewModel

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            SpeedView(viewModel: speedViewModel)
            LocationStatusView(viewModel: locationStatusViewModel)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: OneValueModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel

    init() {
        _speedViewModel = StateObject(wrappedValue: OneValueModel(LocationPublisher(behavior: MetersPerSecondToKmh(inner: NilToZero(inner: SpeedBehavior())))))
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(AuthorizationStatusPublisher()))
        
        CLLocationManager().requestWhenInUseAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(speedViewModel: speedViewModel, locationStatusViewModel: locationStatusViewModel)
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
    var speed = 0.0
    VStack {
        ContentView(speedViewModel: OneValueModel(speedModel), locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)))
        
        VStack {
            Button {
                speedModel.send(value: speed)
                speed += 1
            } label: {
                Text("accelerate")
            }
            Button {
                speedModel.send(value: speed)
                speed -= 1
            } label: {
                Text("decelerate")
            }
        }
    }
}
