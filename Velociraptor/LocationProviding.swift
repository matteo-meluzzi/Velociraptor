import Combine
import CoreLocation

protocol LocationProviding: AnyObject {
    var speedPublisher: AnyPublisher<Double?, Never> { get }
    var altitudePublisher: AnyPublisher<Double?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    func requestAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
