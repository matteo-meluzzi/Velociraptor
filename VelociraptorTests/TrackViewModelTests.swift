import CoreLocation
import Foundation
import SwiftUI
import Testing
@testable import Velociraptor

@MainActor
struct TrackViewModelTests {
    private let location = MockLocationProvider<LocationFix?>(initialValue: nil)
    private let heading = MockHeadingProvider()
    private let authorization = MockAuthorizationProvider(status: .authorizedWhenInUse)
    private let directory = makeTempDirectory()

    private let start = CLLocationCoordinate2D(latitude: 45, longitude: 7)
    private var simpleGPX: String {
        gpx11(#"<trk><name>Simple</name><trkseg><trkpt lat="45" lon="7"/><trkpt lat="45.01" lon="7"/></trkseg></trk>"#)
    }

    private func makeViewModel() -> TrackViewModel {
        TrackViewModel(
            location: location, heading: heading, authorization: authorization,
            store: FileTrackStore(directory: directory)
        )
    }

    private func file(_ contents: String, named name: String = "track.gpx") throws -> URL {
        let url = makeTempDirectory().appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func loadedViewModel() async throws -> TrackViewModel {
        let vm = makeViewModel()
        await vm.importFile(at: try file(simpleGPX))
        return vm
    }

    private func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 1e-9 && abs(a.longitude - b.longitude) < 1e-9
    }

    // MARK: V1 – relaunch

    @Test func storedTrackIsShownAfterLoading() async throws {
        try FileTrackStore(directory: directory).save(makeTrack([[(45, 7), (45.01, 7)]], name: "Stored"))
        let vm = makeViewModel()
        await vm.loadStoredTrack()
        #expect(vm.track?.name == "Stored")
        #expect(vm.mode == .following)
        #expect(vm.viewport.width == 1000)
    }

    @Test func nothingShownWhenStoreIsEmpty() async {
        let vm = makeViewModel()
        await vm.loadStoredTrack()
        #expect(vm.track == nil)
        #expect(vm.alertMessage == nil)
    }

    @Test func unreadableStoredTrackShowsNothingAndNoAlert() async throws {
        try Data("garbage".utf8).write(to: directory.appendingPathComponent("CurrentTrack.json"))
        let vm = makeViewModel()
        await vm.loadStoredTrack()
        #expect(vm.track == nil)
        #expect(vm.alertMessage == nil)
    }

    // MARK: V2, V3, V5 – import and close

    @Test func importButtonOpensPicker() {
        let vm = makeViewModel()
        vm.importButtonTapped()
        #expect(vm.isImporterPresented)
    }

    @Test func validImportShowsTrackAndIsRemembered() async throws {
        let vm = try await loadedViewModel()
        #expect(vm.track?.name == "Simple")
        #expect(vm.geometry != nil)
        #expect(vm.mode == .following)
        #expect(vm.viewport.width == 1000)

        let relaunched = makeViewModel()
        await relaunched.loadStoredTrack()
        #expect(relaunched.track?.name == "Simple")
    }

    @Test func invalidImportKeepsPreviousTrack() async throws {
        let vm = try await loadedViewModel()
        await vm.importFile(at: try file(gpx11(#"<wpt lat="1" lon="1"/>"#), named: "waypoints.gpx"))
        #expect(vm.alertMessage == "Couldn't load waypoints.gpx")
        #expect(vm.track?.name == "Simple")

        let relaunched = makeViewModel()
        await relaunched.loadStoredTrack()
        #expect(relaunched.track?.name == "Simple")
    }

    @Test func missingFileShowsAlert() async {
        let vm = makeViewModel()
        await vm.importFile(at: makeTempDirectory().appendingPathComponent("gone.gpx"))
        #expect(vm.alertMessage == "Couldn't load gone.gpx")
        #expect(vm.track == nil)
    }

    @Test func pickerFailureShowsAlert() {
        let vm = makeViewModel()
        vm.importFailed()
        #expect(vm.alertMessage == "Couldn't load the file")
        #expect(vm.track == nil)
    }

    @Test func newImportReplacesTrack() async throws {
        let vm = try await loadedViewModel()
        await vm.importFile(at: try file(gpx11(#"<trk><name>Other</name><trkseg><trkpt lat="1" lon="1"/></trkseg></trk>"#)))
        #expect(vm.track?.name == "Other")
    }

    @Test func closedTrackDoesNotComeBack() async throws {
        let vm = try await loadedViewModel()
        vm.closeTrack()
        #expect(vm.track == nil)
        #expect(vm.geometry == nil)

        let relaunched = makeViewModel()
        await relaunched.loadStoredTrack()
        #expect(relaunched.track == nil)
    }

    // MARK: V6, V10, V11, V15 – following and location

    @Test func followingCentresOnEachFix() async throws {
        let vm = try await loadedViewModel()
        let here = CLLocationCoordinate2D(latitude: 45.003, longitude: 7.001)
        location.send(value: fix(here))
        #expect(sameCoordinate(vm.viewport.center, here))
        #expect(vm.viewport.width == 1000)
        #expect(vm.userLocation?.coordinate.latitude == here.latitude)
    }

    @Test func centresOnTrackStartUntilFirstFix() async throws {
        let vm = try await loadedViewModel()
        #expect(sameCoordinate(vm.viewport.center, start))
        #expect(vm.locationMessage == .unknown)
        #expect(vm.arrow == nil)

        let here = CLLocationCoordinate2D(latitude: 45.02, longitude: 7.02)
        location.send(value: fix(here))
        #expect(sameCoordinate(vm.viewport.center, here))
        #expect(vm.locationMessage == nil)
    }

    @Test func deniedAccessCentresOnTrackStartWithMessage() async throws {
        authorization.send(.denied)
        let vm = try await loadedViewModel()
        #expect(sameCoordinate(vm.viewport.center, start))
        #expect(vm.locationMessage == .denied)
    }

    @Test func lostLocationKeepsLastCentre() async throws {
        let vm = try await loadedViewModel()
        let here = CLLocationCoordinate2D(latitude: 45.02, longitude: 7.02)
        location.send(value: fix(here))
        location.send(value: nil)
        #expect(sameCoordinate(vm.viewport.center, here))
        #expect(vm.locationMessage == .unknown)
        #expect(vm.userLocation == nil)
    }

    @Test func messageClearsWhenLocationRecovers() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(CLLocationCoordinate2D(latitude: 45.02, longitude: 7.02)))
        location.send(value: nil)
        location.send(value: fix(CLLocationCoordinate2D(latitude: 45.03, longitude: 7.02)))
        #expect(vm.locationMessage == nil)
    }

    @Test func fixWithInvalidAccuracyIsIgnored() async throws {
        let vm = try await loadedViewModel()
        let here = CLLocationCoordinate2D(latitude: 45.02, longitude: 7.02)
        location.send(value: fix(here))
        location.send(value: fix(CLLocationCoordinate2D(latitude: 46, longitude: 8), accuracy: -1))
        #expect(sameCoordinate(vm.viewport.center, here))
        #expect(vm.userLocation?.coordinate.latitude == here.latitude)
        #expect(vm.locationMessage == nil)
    }

    @Test func fixReceivedBeforeImportCentresTheNewTrackOnTheUser() async throws {
        let here = CLLocationCoordinate2D(latitude: 45.02, longitude: 7.02)
        location.send(value: fix(here))
        let vm = try await loadedViewModel()
        #expect(sameCoordinate(vm.viewport.center, here))
    }

    // MARK: V13, V16, V17 – off-track arrow

    /// A 6 km north-south track through `start`, and the visible area the map would report for `center`.
    private func northSouthViewModel() async throws -> TrackViewModel {
        let south = offset(start, metres: 3000, bearing: 180), north = offset(start, metres: 3000, bearing: 0)
        let vm = makeViewModel()
        await vm.importFile(at: try file(gpx11(
            "<trk><trkseg><trkpt lat=\"\(south.latitude)\" lon=\"\(south.longitude)\"/><trkpt lat=\"\(north.latitude)\" lon=\"\(north.longitude)\"/></trkseg></trk>"
        )))
        return vm
    }

    private func area(center: CLLocationCoordinate2D, heading: Double = 0) -> VisibleArea {
        VisibleArea(
            mapSize: CGSize(width: 390, height: 844), insets: EdgeInsets(),
            viewport: Viewport(center: center, width: 1000, heading: heading)
        )
    }

    @Test func arrowPointsToTrackWhenOutOfView() async throws {
        let vm = try await northSouthViewModel()
        let user = offset(start, metres: 2000, bearing: 90)
        location.send(value: fix(user))
        vm.visibleAreaChanged(area(center: user))
        #expect(Geo.angularDistance(vm.arrow?.bearing ?? -100, 270) < 5)
        #expect(vm.arrow?.distanceText == "2.0 km")
    }

    @Test func noArrowWhenTrackIsInView() async throws {
        let vm = try await northSouthViewModel()
        location.send(value: fix(start))
        vm.visibleAreaChanged(area(center: start))
        #expect(vm.arrow == nil)
    }

    @Test func noArrowWhenLocationUnknown() async throws {
        let vm = try await northSouthViewModel()
        vm.visibleAreaChanged(area(center: offset(start, metres: 2000, bearing: 90)))
        #expect(vm.arrow == nil)

        location.send(value: fix(offset(start, metres: 2000, bearing: 90)))
        location.send(value: nil)
        #expect(vm.arrow == nil)
    }

    @Test func noArrowWithoutTrack() {
        let vm = makeViewModel()
        let user = offset(start, metres: 2000, bearing: 90)
        location.send(value: fix(user))
        vm.visibleAreaChanged(area(center: user))
        #expect(vm.arrow == nil)
    }

    @Test func arrowIsMeasuredFromTheRealPositionWhenViewIsElsewhere() async throws {
        let vm = try await northSouthViewModel()
        location.send(value: fix(offset(start, metres: 1500, bearing: 270)))
        vm.visibleAreaChanged(area(center: offset(start, metres: 9000, bearing: 90)))
        #expect(Geo.angularDistance(vm.arrow?.bearing ?? -100, 90) < 5)
        #expect(vm.arrow?.distanceText == "1.5 km")
    }

    @Test func noArrowWhenAccessIsDenied() async throws {
        let vm = try await northSouthViewModel()
        let user = offset(start, metres: 2000, bearing: 90)
        location.send(value: fix(user))
        vm.visibleAreaChanged(area(center: user))
        #expect(vm.arrow != nil)
        authorization.send(.denied)
        #expect(vm.arrow == nil)
    }

    @Test func sameVisibleAreaPublishesArrowOnce() async throws {
        let vm = try await northSouthViewModel()
        let user = offset(start, metres: 2000, bearing: 90)
        location.send(value: fix(user))
        var published: [OffTrackArrow?] = []
        let subscription = vm.$arrow.dropFirst().sink { published.append($0) }
        vm.visibleAreaChanged(area(center: user))
        vm.visibleAreaChanged(area(center: user))
        #expect(published.count == 1)
        subscription.cancel()
    }

    @Test func displayedMapHeadingFollowsTheMapNotTheTarget() async throws {
        let vm = try await northSouthViewModel()
        #expect(vm.displayedMapHeading == 0)
        location.send(value: fix(start, kmh: 10, course: 90))
        vm.visibleAreaChanged(area(center: start, heading: 40))
        #expect(vm.viewport.heading == 90)
        #expect(vm.displayedMapHeading == 40)
    }

    // MARK: V12 – orientation

    @Test func movingTurnsTheViewToTheCourse() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start, kmh: 10, course: 90))
        #expect(vm.viewport.heading == 90)
    }

    @Test func stationaryTurnsTheViewToTheCompass() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start, kmh: 10, course: 90))
        location.send(value: fix(start, kmh: 1))
        heading.send(CompassHeading(trueHeading: 200, magneticHeading: 198, accuracy: 5))
        #expect(vm.viewport.heading == 200)
    }

    @Test func movingWithoutCourseKeepsHeading() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start, kmh: 10, course: 90))
        location.send(value: fix(start, kmh: 10, course: -1))
        #expect(vm.viewport.heading == 90)
    }

    @Test func invalidFixDoesNotStopMovingOrientation() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start, kmh: 10, course: 90))
        heading.send(CompassHeading(trueHeading: 200, magneticHeading: 198, accuracy: 5))
        location.send(value: fix(start, accuracy: -1, kmh: 0))
        #expect(vm.viewport.heading == 90)
    }

    @Test func northUpUntilAHeadingIsKnown() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start, kmh: 10, course: -1))
        #expect(vm.viewport.heading == 0)
    }

    @Test func orientationStillAppliesWhileBrowsing() async throws {
        let vm = try await loadedViewModel()
        vm.userChangedCamera(center: offset(start, metres: 500, bearing: 0), width: 3000)
        location.send(value: fix(start, kmh: 10, course: 90))
        #expect(vm.mode == .browsing)
        #expect(vm.viewport.heading == 90)
    }

    @Test func interfaceOrientationIsPassedToTheCompass() {
        let vm = makeViewModel()
        vm.interfaceOrientationChanged(.landscapeLeft)
        #expect(heading.lastOrientation == .landscapeLeft)
    }

    // MARK: V7, V8, V9, V11 – browsing and re-centre

    @Test func userZoomOrPanSwitchesToBrowsing() async throws {
        let vm = try await loadedViewModel()
        let elsewhere = offset(start, metres: 800, bearing: 45)
        vm.userChangedCamera(center: elsewhere, width: 3000)
        #expect(vm.mode == .browsing)
        #expect(vm.showsRecentreButton)
        #expect(sameCoordinate(vm.viewport.center, elsewhere))
        #expect(vm.viewport.width == 3000)
    }

    @Test func zoomOnlyAlsoSwitchesToBrowsing() async throws {
        let vm = try await loadedViewModel()
        vm.userChangedCamera(center: vm.viewport.center, width: 500)
        #expect(vm.mode == .browsing)
        #expect(vm.viewport.width == 500)
    }

    @Test(arguments: [(50.0, 100.0), (50_000.0, 20_000.0)])
    func zoomIsClamped(requested: Double, expected: Double) async throws {
        let vm = try await loadedViewModel()
        vm.userChangedCamera(center: start, width: requested)
        #expect(vm.viewport.width == expected)
    }

    @Test func browsingIgnoresNewFixesForCentring() async throws {
        let vm = try await loadedViewModel()
        let elsewhere = offset(start, metres: 800, bearing: 45)
        vm.userChangedCamera(center: elsewhere, width: 3000)
        let here = offset(start, metres: 100, bearing: 0)
        location.send(value: fix(here))
        #expect(sameCoordinate(vm.viewport.center, elsewhere))
        #expect(vm.userLocation?.coordinate.latitude == here.latitude)
    }

    @Test func recentreRestoresDefaultViewOnTheUser() async throws {
        let vm = try await loadedViewModel()
        let here = offset(start, metres: 100, bearing: 0)
        location.send(value: fix(here))
        vm.userChangedCamera(center: offset(start, metres: 800, bearing: 45), width: 3000)
        vm.recentreTapped()
        #expect(vm.mode == .following)
        #expect(!vm.showsRecentreButton)
        #expect(vm.viewport.width == 1000)
        #expect(sameCoordinate(vm.viewport.center, here))
    }

    @Test func recentreWithoutAnyFixGoesToTrackStart() async throws {
        let vm = try await loadedViewModel()
        vm.userChangedCamera(center: offset(start, metres: 800, bearing: 45), width: 3000)
        vm.recentreTapped()
        #expect(sameCoordinate(vm.viewport.center, start))
    }

    @Test func recentreAfterLocationLostGoesToLastFix() async throws {
        let vm = try await loadedViewModel()
        let here = offset(start, metres: 100, bearing: 0)
        location.send(value: fix(here))
        location.send(value: nil)
        vm.userChangedCamera(center: offset(start, metres: 800, bearing: 45), width: 3000)
        vm.recentreTapped()
        #expect(sameCoordinate(vm.viewport.center, here))
    }

    @Test func firstFixWhileBrowsingDoesNotMoveTheView() async throws {
        let vm = try await loadedViewModel()
        let elsewhere = offset(start, metres: 800, bearing: 45)
        vm.userChangedCamera(center: elsewhere, width: 3000)
        location.send(value: fix(offset(start, metres: 100, bearing: 0)))
        #expect(sameCoordinate(vm.viewport.center, elsewhere))
    }

    @Test func importWhileBrowsingReturnsToFollowing() async throws {
        let vm = try await loadedViewModel()
        vm.userChangedCamera(center: offset(start, metres: 800, bearing: 45), width: 3000)
        await vm.importFile(at: try file(simpleGPX))
        #expect(vm.mode == .following)
        #expect(vm.viewport.width == 1000)
    }

    // MARK: D1–D12 – distances along the track (feature 006)

    /// The same store as `makeViewModel()`, with its own location provider (a relaunched app has no fix yet).
    private func relaunchedViewModel(location: MockLocationProvider<LocationFix?> = MockLocationProvider(initialValue: nil)) async -> TrackViewModel {
        let vm = TrackViewModel(
            location: location, heading: heading, authorization: authorization,
            store: FileTrackStore(directory: directory)
        )
        await vm.loadStoredTrack()
        return vm
    }

    private func north(_ metres: Double) -> CLLocationCoordinate2D { offset(start, metres: metres, bearing: 0) }

    private func kilometres(_ text: String?) -> Double { text.flatMap(Double.init) ?? .nan }

    private var otherGPX: String {
        gpx11(#"<trk><name>Other</name><trkseg><trkpt lat="1" lon="1"/><trkpt lat="1.01" lon="1"/></trkseg></trk>"#)
    }

    @Test func d1NoDistancesWithoutTrack() {
        let vm = makeViewModel()
        location.send(value: fix(start))
        #expect(vm.distances == nil)
    }

    @Test func d2UnknownUntilTheFirstFix() async throws {
        let vm = try await loadedViewModel()
        #expect(vm.distances == .unknown)
    }

    @Test func d3d4FixesShowDoneAndLeftAlongTheTrack() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start))
        #expect(vm.distances == TrackDistances(done: "0.00", left: "1.11"))

        location.send(value: fix(north(555)))
        let done = kilometres(vm.distances?.done), left = kilometres(vm.distances?.left)
        #expect(abs(done - 0.55) <= 0.01)
        #expect(abs(done + left - 1.11) <= 0.011)
    }

    @Test func d5aLostLocationKeepsEstablishedValues() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(north(300)))
        let shown = vm.distances
        location.send(value: nil)
        #expect(vm.distances == shown)
        #expect(shown != .unknown)
    }

    @Test func d5bLostLocationBeforeProgressIsEstablishedShowsUnknown() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(offset(start, metres: 200, bearing: 90)))
        #expect(vm.distances?.done == "0.00")
        location.send(value: nil)
        #expect(vm.distances == .unknown)
    }

    @Test func d6ClosingRemovesDistancesAndProgress() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(north(300)))
        vm.closeTrack()
        #expect(vm.distances == nil)
        #expect(FileTrackStore(directory: directory).loadProgress() == nil)
    }

    @Test func d7ProgressComesBackAfterRelaunch() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start))
        location.send(value: fix(north(500)))
        let shown = vm.distances

        let relaunched = await relaunchedViewModel()
        #expect(relaunched.distances == shown)
    }

    @Test func d8NewImportStartsOverAndForgetsOldProgress() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(north(500)))
        await vm.importFile(at: try file(otherGPX))
        // The known fix is far north of the new track: its closest point (the finish) is shown, but not established.
        #expect(vm.distances == TrackDistances(done: "1.11", left: "0.00"))

        let relaunched = await relaunchedViewModel()
        #expect(relaunched.track?.name == "Other")
        #expect(relaunched.distances == .unknown)
    }

    @Test func d9DeniedAccessShowsRestoredValues() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(north(500)))
        let shown = vm.distances
        authorization.send(.denied)

        let relaunched = await relaunchedViewModel()
        #expect(relaunched.distances == shown)
    }

    @Test func d10KnownFixCountsAsSoonAsATrackIsImported() async throws {
        location.send(value: fix(start))
        let vm = try await loadedViewModel()
        #expect(vm.distances == TrackDistances(done: "0.00", left: "1.11"))
    }

    @Test func d11BrowsingStillFollowsTheRealFix() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(start))
        vm.userChangedCamera(center: offset(start, metres: 3000, bearing: 90), width: 3000)
        location.send(value: fix(north(500)))
        #expect(abs(kilometres(vm.distances?.done) - 0.5) <= 0.01)
    }

    @Test func d12FixesDuringAnImportDoNotLeaveOldProgressBehind() async throws {
        let vm = try await loadedViewModel()
        location.send(value: fix(north(500)))
        let importing = Task { await vm.importFile(at: try file(otherGPX)) }
        await Task.yield()
        location.send(value: fix(north(600)))
        try await importing.value

        let relaunched = await relaunchedViewModel()
        #expect(relaunched.track?.name == "Other")
        #expect(relaunched.distances == .unknown)
    }
}
