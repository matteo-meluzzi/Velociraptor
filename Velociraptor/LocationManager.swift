import Combine
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate, LocationProviding {
    private let manager = CLLocationManager()
    private let speedSubject = CurrentValueSubject<Double?, Never>(nil)
    private let altitudeSubject = CurrentValueSubject<Double?, Never>(nil)
    private let authorizationSubject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var speedPublisher: AnyPublisher<Double?, Never> {
        speedSubject.eraseToAnyPublisher()
    }

    var altitudePublisher: AnyPublisher<Double?, Never> {
        altitudeSubject.eraseToAnyPublisher()
    }

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }

    override init() {
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
        let speed = locations.last?.speed
        speedSubject.send(speed.flatMap { $0 >= 0 ? $0 : nil })
        altitudeSubject.send(locations.last?.altitude)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationSubject.send(status)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        speedSubject.send(nil)
        altitudeSubject.send(nil)
    }
}
