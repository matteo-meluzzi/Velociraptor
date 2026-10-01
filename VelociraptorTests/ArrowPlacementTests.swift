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

    @Test func offsetRectIsRespected() {
        let point = ArrowPlacement.position(in: CGRect(x: 0, y: 120, width: 300, height: 500), screenAngle: 0, margin: 32)
        #expect(abs(point.y - 152) < 0.01)
    }
}
