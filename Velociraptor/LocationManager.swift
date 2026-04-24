import Combine
import CoreLocation

protocol LocationBehavior {
    func value(from location: CLLocation) -> Double?
}

struct SpeedBehavior: LocationBehavior {
    func value(from location: CLLocation) -> Double? {
        let speed = location.speed
        return speed >= 0 ? speed : nil
    }
}

struct AltitudeBehavior: LocationBehavior {
    func value(from location: CLLocation) -> Double? {
        location.altitude
    }
}

final class LocationManager: NSObject, CLLocationManagerDelegate, LocationProviding {
    private let manager = CLLocationManager()
    private let behavior: any LocationBehavior
    private let valueSubject = CurrentValueSubject<Double?, Never>(nil)
    private let authorizationSubject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var valuePublisher: AnyPublisher<Double?, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    init(behavior: any LocationBehavior) {
        self.behavior = behavior
        authorizationSubject = CurrentValueSubject(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        requestAuthorization()
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        valueSubject.send(behavior.value(from: location))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationSubject.send(status)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        valueSubject.send(nil)
    }
}
