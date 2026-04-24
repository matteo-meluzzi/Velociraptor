import Combine
import CoreLocation

protocol LocationProviding: AnyObject {
    var valuePublisher: AnyPublisher<Double?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    func requestAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
