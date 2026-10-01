import Foundation
import Testing
@testable import Velociraptor

struct GPXParserTests {
    private func parse(_ xml: String, fileName: String = "track.gpx") -> Result<Track, GPXImportError> {
        GPXParser.parse(Data(xml.utf8), fileName: fileName)
    }

    private func track(_ xml: String, fileName: String = "track.gpx") throws -> Track {
        try parse(xml, fileName: fileName).get()
    }

    private let threePoints = """
    <trkpt lat="45.0" lon="7.0"><ele>200</ele><time>2026-01-01T00:00:00Z</time></trkpt>
    <trkpt lat="45.001" lon="7.001"/>
    <trkpt lat="45.002" lon="7.002"/>
    """

    @Test func gpx11SingleSegment() throws {
        let track = try track(gpx11("<trk><name>Morning</name><trkseg>\(threePoints)</trkseg></trk>"))
        #expect(track == makeTrack([[(45.0, 7.0), (45.001, 7.001), (45.002, 7.002)]], name: "Morning"))
    }

    @Test func gpx10GivesSameResult() throws {
        let body = "<trk><name>Morning</name><trkseg>\(threePoints)</trkseg></trk>"
        #expect(try track(gpx10(body)) == track(gpx11(body)))
    }

    @Test func noNamespaceIsAccepted() throws {
        let track = try track("<gpx><trk><trkseg>\(threePoints)</trkseg></trk></gpx>")
        #expect(track.segments.first?.points.count == 3)
    }

    @Test func twoSegmentsStaySeparate() throws {
        let track = try track(gpx11("""
        <trk><trkseg><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg>
        <trkseg><trkpt lat="3" lon="3"/></trkseg></trk>
        """))
        #expect(track.segments.map(\.points.count) == [2, 1])
    }

    @Test func twoTracksGiveTwoSegmentsNamedAfterFirst() throws {
        let track = try track(gpx11("""
        <trk><name>First</name><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>
        <trk><name>Second</name><trkseg><trkpt lat="2" lon="2"/></trkseg></trk>
        """))
        #expect(track.segments.count == 2)
        #expect(track.name == "First")
    }

    @Test func routeOnlyIsUsedAsTrack() throws {
        let track = try track(gpx11("""
        <rte><name>Route</name><rtept lat="1" lon="1"/><rtept lat="2" lon="2"/><rtept lat="3" lon="3"/><rtept lat="4" lon="4"/></rte>
        """))
        #expect(track.segments.map(\.points.count) == [4])
        #expect(track.name == "Route")
    }

    @Test func trackPointsWinOverRoute() throws {
        let track = try track(gpx11("""
        <rte><rtept lat="9" lon="9"/></rte>
        <trk><trkseg><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg></trk>
        """))
        #expect(track == makeTrack([[(1, 1), (2, 2)]], name: "track"))
    }

    @Test func waypointsOnlyHasNoTrackPoints() {
        #expect(parse(gpx11(#"<wpt lat="1" lon="1"><name>Hut</name></wpt>"#)) == .failure(.noTrackPoints))
    }

    @Test func invalidPointsAreDropped() throws {
        let track = try track(gpx11("""
        <trk><trkseg>
        <trkpt lat="1" lon="1"/><trkpt lat="95" lon="1"/><trkpt lat="1" lon="abc"/>
        <trkpt lat="1"/><trkpt lat="2" lon="181"/><trkpt lat="2" lon="2"/>
        </trkseg></trk>
        """))
        #expect(track.segments == [TrackSegment(points: [TrackPoint(latitude: 1, longitude: 1), TrackPoint(latitude: 2, longitude: 2)])])
    }

    @Test func allPointsInvalidHasNoTrackPoints() {
        #expect(parse(gpx11(#"<trk><trkseg><trkpt lat="95" lon="1"/><trkpt lat="nan" lon="1"/></trkseg></trk>"#)) == .failure(.noTrackPoints))
    }

    @Test func emptySegmentIsDropped() throws {
        let track = try track(gpx11(#"<trk><trkseg></trkseg><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#))
        #expect(track.segments.count == 1)
    }

    @Test func metadataNameUsedWhenTrackHasNone() throws {
        let track = try track(gpx11(#"<trk><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#, name: "Loop"))
        #expect(track.name == "Loop")
    }

    @Test func gpx10TopLevelNameUsedWhenTrackHasNone() throws {
        let track = try track(gpx10(#"<name>Old</name><trk><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#))
        #expect(track.name == "Old")
    }

    @Test func fileNameUsedWhenNoNames() throws {
        let track = try track(gpx11(#"<trk><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#), fileName: "Morning ride.gpx")
        #expect(track.name == "Morning ride")
    }

    @Test func cdataNameIsRead() throws {
        let track = try track(gpx11(#"<trk><name><![CDATA[Col & Lac]]></name><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#))
        #expect(track.name == "Col & Lac")
    }

    @Test func pointNameDoesNotBecomeTrackName() throws {
        let track = try track(
            gpx11(#"<trk><trkseg><trkpt lat="1" lon="1"><name>Point</name></trkpt></trkseg></trk>"#),
            fileName: "Ride.gpx"
        )
        #expect(track.name == "Ride")
    }

    @Test func pngBytesAreUnreadable() {
        #expect(GPXParser.parse(Data([0x89, 0x50, 0x4E, 0x47]), fileName: "x.gpx") == .failure(.unreadable))
    }

    @Test func truncatedXMLIsUnreadable() {
        #expect(parse(#"<?xml version="1.0"?><gpx><trk><trkseg><trkpt lat="1" lon="1"/>"#) == .failure(.unreadable))
    }

    @Test func otherRootElementIsUnreadable() {
        #expect(parse(#"<kml><trk><trkseg><trkpt lat="1" lon="1"/></trkseg></trk></kml>"#) == .failure(.unreadable))
    }

    @Test func largeFileParsesAllPoints() throws {
        let track = try track(largeGPX())
        #expect(track.segments.first?.points.count == 50_000)
    }
}
