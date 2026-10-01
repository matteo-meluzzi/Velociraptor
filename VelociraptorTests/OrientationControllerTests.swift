import CoreLocation
import Testing
@testable import Velociraptor

struct OrientationControllerTests {
    private let here = CLLocationCoordinate2D(latitude: 45, longitude: 7)

    private func moving(_ kmh: Double, course: Double = -1) -> LocationFix {
        fix(here, kmh: kmh, course: course)
    }

    private func compass(_ trueHeading: Double, magnetic: Double = 0, accuracy: Double = 5) -> CompassHeading {
        CompassHeading(trueHeading: trueHeading, magneticHeading: magnetic, accuracy: accuracy)
    }

    private func controller(after updates: [(LocationFix?, CompassHeading?)]) -> OrientationController {
        var controller = OrientationController()
        for (fix, compass) in updates { controller.update(fix: fix, compass: compass) }
        return controller
    }

    // MARK: Motion transitions

    @Test func startsStationaryAndNorthUp() {
        let controller = OrientationController()
        #expect(controller.motion == .stationary)
        #expect(controller.displayedHeading == 0)
    }

    @Test func unknownSpeedKeepsState() {
        let unknown = LocationFix(coordinate: here, horizontalAccuracy: 5, speed: -1, course: -1)
        #expect(controller(after: [(moving(10), nil), (unknown, nil)]).motion == .moving)
        #expect(controller(after: [(moving(10), nil), (nil, nil)]).motion == .moving)
    }

    @Test func becomesMovingAtThreeKmh() {
        #expect(controller(after: [(moving(3), nil)]).motion == .moving)
        #expect(controller(after: [(moving(2.9), nil)]).motion == .stationary)
    }

    @Test func becomesStationaryBelowTwoKmh() {
        #expect(controller(after: [(moving(10), nil), (moving(1.9), nil)]).motion == .stationary)
        #expect(controller(after: [(moving(10), nil), (moving(2), nil)]).motion == .moving)
    }

    @Test func betweenThresholdsKeepsPreviousState() {
        #expect(controller(after: [(moving(2.5), nil)]).motion == .stationary)
        #expect(controller(after: [(moving(10), nil), (moving(2.5), nil)]).motion == .moving)
    }

    // MARK: Displayed heading

    @Test func movingUsesCourse() {
        #expect(controller(after: [(moving(10, course: 90), compass(200))]).displayedHeading == 90)
    }

    @Test func movingWithoutCourseKeepsLastHeading() {
        let result = controller(after: [(moving(10, course: 90), nil), (moving(10, course: -1), compass(200))])
        #expect(result.displayedHeading == 90)
    }

    @Test func stationaryUsesTrueHeading() {
        #expect(controller(after: [(moving(0), compass(200, magnetic: 198))]).displayedHeading == 200)
    }

    @Test func stationaryFallsBackToMagneticHeading() {
        #expect(controller(after: [(nil, compass(-1, magnetic: 120))]).displayedHeading == 120)
    }

    @Test func invalidCompassKeepsLastHeading() {
        let result = controller(after: [(nil, compass(200)), (nil, compass(100, accuracy: -1))])
        #expect(result.displayedHeading == 200)
    }

    @Test func noCompassKeepsLastHeading() {
        #expect(controller(after: [(nil, compass(200)), (nil, nil)]).displayedHeading == 200)
    }

    @Test func neverHadHeadingStaysNorth() {
        #expect(controller(after: [(moving(10, course: -1), nil), (moving(0), nil)]).displayedHeading == 0)
    }

    // MARK: Dead band

    @Test func smallChangeIsIgnored() {
        #expect(controller(after: [(nil, compass(100)), (nil, compass(104))]).displayedHeading == 100)
    }

    @Test func fiveDegreeChangeIsApplied() {
        #expect(controller(after: [(nil, compass(100)), (nil, compass(105))]).displayedHeading == 105)
    }

    @Test func deadBandWrapsAroundNorth() {
        let result = controller(after: [(nil, compass(350)), (nil, compass(358)), (nil, compass(2))])
        #expect(result.displayedHeading == 358) // 358 → 2 is only 4° apart
    }

    @Test func slowDriftTurnsOnceItAddsUpToFiveDegrees() {
        let result = controller(after: [(nil, compass(100)), (nil, compass(102)), (nil, compass(104)), (nil, compass(106))])
        #expect(result.displayedHeading == 106)
    }
}
