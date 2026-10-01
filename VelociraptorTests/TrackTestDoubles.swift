import Combine
import CoreLocation
import Foundation
import UIKit
@testable import Velociraptor

final class MockHeadingProvider: HeadingProviding {
    private let subject = CurrentValueSubject<CompassHeading?, Never>(nil)
    private(set) var lastOrientation: UIInterfaceOrientation?

    var publisher: AnyPublisher<CompassHeading?, Never> { subject.eraseToAnyPublisher() }

    func send(_ heading: CompassHeading?) { subject.send(heading) }
    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation) { lastOrientation = orientation }
}

func makeTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func gpx11(_ body: String, name: String? = nil) -> String {
    let metadata = name.map { "<metadata><name>\($0)</name></metadata>" } ?? ""
    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="tests" xmlns="http://www.topografix.com/GPX/1/1">\(metadata)\(body)</gpx>
    """
}

func gpx10(_ body: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.0" creator="tests" xmlns="http://www.topografix.com/GPX/1/0">\(body)</gpx>
    """
}

func makeTrack(_ segments: [[(Double, Double)]], name: String = "Test") -> Track {
    Track(name: name, segments: segments.map { points in
        TrackSegment(points: points.map { TrackPoint(latitude: $0.0, longitude: $0.1) })
    })
}

/// A deterministic 50,000-point zig-zag north from (45.0, 7.0), about 1.1 m between points.
func largeGPX(points: Int = 50_000) -> String {
    var body = "<trk><name>Large</name><trkseg>"
    body.reserveCapacity(points * 48)
    for i in 0..<points {
        let lat = 45.0 + Double(i) * 0.00001
        let lon = 7.0 + 0.001 * sin(Double(i) / 50)
        body += "<trkpt lat=\"\(lat)\" lon=\"\(lon)\"/>"
    }
    body += "</trkseg></trk>"
    return gpx11(body)
}

/// A coordinate `metres` away from `origin` along `bearing` (flat-earth; fine for test distances).
func offset(_ origin: CLLocationCoordinate2D, metres: Double, bearing: Double) -> CLLocationCoordinate2D {
    let radians = bearing * .pi / 180
    let north = metres * cos(radians), east = metres * sin(radians)
    return CLLocationCoordinate2D(
        latitude: origin.latitude + north / 111_320,
        longitude: origin.longitude + east / (111_320 * cos(origin.latitude * .pi / 180))
    )
}

func fix(_ coordinate: CLLocationCoordinate2D, accuracy: Double = 5, kmh: Double = 0, course: Double = -1) -> LocationFix {
    LocationFix(coordinate: coordinate, horizontalAccuracy: accuracy, speed: kmh / 3.6, course: course)
}
