import Foundation
import UniformTypeIdentifiers

enum GPXImportError: Error, Equatable {
    case unreadable, noTrackPoints
}

extension UTType {
    /// Declared in Velociraptor-Info.plist under UTImportedTypeDeclarations.
    static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}

enum GPXParser {
    /// Reads track points (or, when there are none, route points) from GPX 1.0 or 1.1. Pure; safe off the main actor.
    static func parse(_ data: Data, fileName: String) -> Result<Track, GPXImportError> {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        guard parser.parse(), delegate.sawGPXRoot else { return .failure(.unreadable) }

        let useTrack = !delegate.trackSegments.isEmpty
        let segments = useTrack ? delegate.trackSegments : delegate.routeSegments
        guard !segments.isEmpty else { return .failure(.noTrackPoints) }

        let fileBaseName = (fileName as NSString).deletingPathExtension
        let candidates = [
            useTrack ? delegate.trackName : delegate.routeName,
            delegate.metadataName,
            delegate.rootName,
            fileBaseName,
        ]
        let name = candidates.compactMap { $0 }.first { !$0.isEmpty } ?? fileBaseName
        return .success(Track(name: name, segments: segments.map { TrackSegment(points: $0) }))
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var sawGPXRoot = false
        private(set) var trackSegments: [[TrackPoint]] = []
        private(set) var routeSegments: [[TrackPoint]] = []
        private(set) var trackName: String?
        private(set) var routeName: String?
        private(set) var metadataName: String?
        private(set) var rootName: String?

        private var path: [String] = []
        private var currentPoints: [TrackPoint] = []
        private var text = ""

        func parser(
            _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
            qualifiedName qName: String?, attributes: [String: String] = [:]
        ) {
            if path.isEmpty {
                guard elementName == "gpx" else {
                    parser.abortParsing()
                    return
                }
                sawGPXRoot = true
            }
            path.append(elementName)
            text = ""
            switch elementName {
            case "trkseg", "rte":
                currentPoints = []
            case "trkpt" where parentIs("trkseg"), "rtept" where parentIs("rte"):
                if let point = Self.point(from: attributes) { currentPoints.append(point) }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            text += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(
            _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?
        ) {
            path.removeLast()
            switch elementName {
            case "trkseg":
                if !currentPoints.isEmpty { trackSegments.append(currentPoints) }
            case "rte":
                if !currentPoints.isEmpty { routeSegments.append(currentPoints) }
            case "name":
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                switch path.last {
                case "trk" where trackName?.isEmpty ?? true: trackName = value
                case "rte" where routeName?.isEmpty ?? true: routeName = value
                case "metadata": metadataName = value
                case "gpx": rootName = value
                default: break
                }
            default:
                break
            }
            text = ""
        }

        private func parentIs(_ name: String) -> Bool {
            path.count >= 2 && path[path.count - 2] == name
        }

        private static func point(from attributes: [String: String]) -> TrackPoint? {
            guard let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init),
                  lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
            return TrackPoint(latitude: lat, longitude: lon)
        }
    }
}
