import Combine
import CoreLocation
import UIKit

struct CompassHeading: Equatable {
    /// Degrees from true north; < 0 when unavailable.
    let trueHeading: Double
    let magneticHeading: Double
    /// Degrees; < 0 means the heading is invalid (e.g. needs calibration).
    let accuracy: Double
}

protocol HeadingProviding: AnyObject {
    /// Current value replayed; `nil` while there is no compass reading.
    var publisher: AnyPublisher<CompassHeading?, Never> { get }
    /// Which way the screen is turned, so the heading refers to the top of the screen.
    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation)
}

final class CompassHeadingPublisher: NSObject, CLLocationManagerDelegate, HeadingProviding {
    private let clManager = CLLocationManager()
    private let subject = CurrentValueSubject<CompassHeading?, Never>(nil)

    var publisher: AnyPublisher<CompassHeading?, Never> { subject.eraseToAnyPublisher() }

    override init() {
        super.init()
        clManager.delegate = self
        clManager.headingFilter = 1
        if CLLocationManager.headingAvailable() {
            clManager.startUpdatingHeading()
        }
    }

    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        // Interface and device landscape orientations are mirrored.
        switch orientation {
        case .portrait: clManager.headingOrientation = .portrait
        case .portraitUpsideDown: clManager.headingOrientation = .portraitUpsideDown
        case .landscapeLeft: clManager.headingOrientation = .landscapeRight
        case .landscapeRight: clManager.headingOrientation = .landscapeLeft
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        subject.send(CompassHeading(
            trueHeading: newHeading.trueHeading,
            magneticHeading: newHeading.magneticHeading,
            accuracy: newHeading.headingAccuracy
        ))
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        false
    }
}
