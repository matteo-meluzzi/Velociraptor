import CoreGraphics
import Testing
@testable import Velociraptor

struct ArrowPlacementTests {
    private let rect = CGRect(x: 0, y: 0, width: 300, height: 500)

    private func position(_ angle: Double) -> CGPoint {
        ArrowPlacement.position(in: rect, screenAngle: angle, margin: 32)
    }

    @Test(arguments: [
        (0.0, CGPoint(x: 150, y: 32)),
        (90.0, CGPoint(x: 268, y: 250)),
        (180.0, CGPoint(x: 150, y: 468)),
        (270.0, CGPoint(x: 32, y: 250)),
    ])
    func cardinalAngles(angle: Double, expected: CGPoint) {
        let point = position(angle)
        #expect(abs(point.x - expected.x) < 0.01)
        #expect(abs(point.y - expected.y) < 0.01)
    }

    @Test func diagonalLandsOnTheInsetBorder() {
        let point = position(45)
        let inner = rect.insetBy(dx: 32, dy: 32)
        #expect(abs(point.x - inner.maxX) < 0.01 || abs(point.y - inner.minY) < 0.01)
        #expect(point.x > 150 && point.y < 250)
        #expect(inner.insetBy(dx: -0.01, dy: -0.01).contains(point))
    }

    // MARK: From the user's position (006 FR-014)

    private let user = CGPoint(x: 150, y: 440)

    @Test func rayStartsAtTheUser() {
        let point = ArrowPlacement.position(in: rect, screenAngle: 0, margin: 32, from: user)
        #expect(abs(point.x - 150) < 0.01)
        #expect(abs(point.y - 32) < 0.01)
    }

    @Test(arguments: [180.0, 170, 190])
    func arrowBehindTheUserStaysClearOfTheirDot(angle: Double) {
        let point = ArrowPlacement.position(in: rect, screenAngle: angle, margin: 32, from: user)
        #expect(hypot(point.x - user.x, point.y - user.y) >= ArrowPlacement.userClearance - 0.01)
        #expect(rect.insetBy(dx: 32, dy: 32).insetBy(dx: -0.01, dy: -0.01).contains(point))
    }

    @Test func arrowBehindAndLeftMovesLeft() {
        let point = ArrowPlacement.position(in: rect, screenAngle: 200, margin: 32, from: user)
        #expect(point.x < user.x)
    }

    // The app's geometry: the user is drawn 40 pt above the buttons, below the arrow's inset rectangle.
    private let lowUser = CGPoint(x: 150, y: 460)

    private func behind(_ angle: Double) -> CGPoint {
        ArrowPlacement.position(in: rect, screenAngle: angle, margin: 44, from: lowUser)
    }

    @Test func straightBehindSitsAboveTheDot() {
        let point = behind(180)
        #expect(abs(point.x - lowUser.x) < 0.01)
        #expect(abs(point.y - (lowUser.y - ArrowPlacement.userClearance)) < 0.01)
    }

    @Test func smallChangesBehindTheUserDoNotFlipTheArrow() {
        let left = behind(179), right = behind(181)
        #expect(hypot(left.x - right.x, left.y - right.y) < 5)
    }

    @Test func everyAngleBehindTheUserStaysClearOfTheDot() {
        for angle in stride(from: 90.0, through: 270, by: 5) {
            let point = behind(angle)
            #expect(hypot(point.x - lowUser.x, point.y - lowUser.y) >= ArrowPlacement.userClearance - 0.01, "angle \(angle)")
        }
    }

    @Test func offsetRectIsRespected() {
        let point = ArrowPlacement.position(in: CGRect(x: 0, y: 120, width: 300, height: 500), screenAngle: 0, margin: 32)
        #expect(abs(point.y - 152) < 0.01)
    }
}
