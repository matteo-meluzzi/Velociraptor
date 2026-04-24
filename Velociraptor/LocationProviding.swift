import Combine
import CoreLocation

protocol LocationProviding<Value>: AnyObject {
    associatedtype Value
    var valuePublisher: AnyPublisher<Value, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    func requestAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
