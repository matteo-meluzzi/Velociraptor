import Combine
import CoreLocation

protocol LocationProviding<Value>: AnyObject {
    associatedtype Value
    var valuePublisher: AnyPublisher<Value, Never> { get }
    func requestAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

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

final class LocationPublisher<Behavior: LocationBehavior>: NSObject, CLLocationManagerDelegate, LocationProviding {
    typealias Value = Behavior.Value

    private let clManager = CLLocationManager()
    private let behavior: Behavior
    private let valueSubject: CurrentValueSubject<Behavior.Value, Never>

    var valuePublisher: AnyPublisher<Behavior.Value, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    init(behavior: Behavior) {
        self.behavior = behavior
        valueSubject = CurrentValueSubject(behavior.initialValue)
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
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        valueSubject.send(behavior.initialValue)
    }
}

final class AuthorizationStatusPublisher: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()
    private let subject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    override init() {
        subject = CurrentValueSubject(clManager.authorizationStatus)
        super.init()
        clManager.delegate = self
        clManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        subject.send(clManager.authorizationStatus)
    }
}
