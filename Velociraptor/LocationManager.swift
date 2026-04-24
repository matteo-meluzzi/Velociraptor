import Combine
import CoreLocation

protocol LocationBehavior {
    associatedtype Value
    var initialValue: Value { get }
    func value(from location: CLLocation) -> Value
}

struct SpeedBehavior: LocationBehavior {
    var initialValue: Double? { nil }
    func value(from location: CLLocation) -> Double? {
        let speed = location.speed
        return speed >= 0 ? speed : nil
    }
}

struct AltitudeBehavior: LocationBehavior {
    var initialValue: Double? { nil }
    func value(from location: CLLocation) -> Double? {
        location.altitude
    }
}

final class LocationManager<Behavior: LocationBehavior>: NSObject, CLLocationManagerDelegate, LocationProviding {
    typealias Value = Behavior.Value

    private let clManager = CLLocationManager()
    private let behavior: Behavior
    private let valueSubject: CurrentValueSubject<Behavior.Value, Never>
    private let authorizationSubject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var valuePublisher: AnyPublisher<Behavior.Value, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    init(behavior: Behavior) {
        self.behavior = behavior
        valueSubject = CurrentValueSubject(behavior.initialValue)
        authorizationSubject = CurrentValueSubject(clManager.authorizationStatus)
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        clManager.activityType = .automotiveNavigation
        requestAuthorization()
    }

    func requestAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        clManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        clManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        valueSubject.send(behavior.value(from: location))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = clManager.authorizationStatus
        authorizationSubject.send(status)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        valueSubject.send(behavior.initialValue)
    }
}
