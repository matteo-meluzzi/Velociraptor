import Foundation
import Testing
@testable import Velociraptor

struct HeartRateMeasurementTests {
    @Test func uint8Bpm() {
        let m = HeartRateMeasurement.parse(Data([0x00, 0x48]))
        #expect(m == HeartRateMeasurement(bpm: 72, contact: .notSupported))
        #expect(m?.isValid == true)
    }

    @Test func uint16Bpm() {
        #expect(HeartRateMeasurement.parse(Data([0x01, 0x48, 0x00]))?.bpm == 72)
    }

    @Test func uint16BpmHighByte() {
        #expect(HeartRateMeasurement.parse(Data([0x01, 0x2C, 0x01]))?.bpm == 300)
    }

    @Test func contactDetected() {
        let m = HeartRateMeasurement.parse(Data([0x06, 0x50]))
        #expect(m == HeartRateMeasurement(bpm: 80, contact: .detected))
        #expect(m?.isValid == true)
    }

    @Test func contactNotDetectedIsInvalid() {
        let m = HeartRateMeasurement.parse(Data([0x04, 0x50]))
        #expect(m == HeartRateMeasurement(bpm: 80, contact: .notDetected))
        #expect(m?.isValid == false)
    }

    @Test func rrBytesIgnored() {
        #expect(HeartRateMeasurement.parse(Data([0x10, 0x48, 0x00, 0x03]))?.bpm == 72)
    }

    @Test func zeroBpmIsInvalid() {
        let m = HeartRateMeasurement.parse(Data([0x00, 0x00]))
        #expect(m?.bpm == 0)
        #expect(m?.isValid == false)
    }

    @Test func tooShortPayloadsReturnNil() {
        #expect(HeartRateMeasurement.parse(Data()) == nil)
        #expect(HeartRateMeasurement.parse(Data([0x00])) == nil)
        #expect(HeartRateMeasurement.parse(Data([0x01, 0x48])) == nil)
    }

    @Test func contactSupportBitWithoutDetectionTreatedAsNotSupported() {
        let m = HeartRateMeasurement.parse(Data([0x02, 0x50]))
        #expect(m?.contact == .notSupported)
        #expect(m?.isValid == true)
    }

    @Test func slicedDataIsParsedCorrectly() {
        let base = Data([0xFF, 0xFF, 0x00, 0x48])
        #expect(HeartRateMeasurement.parse(base.dropFirst(2))?.bpm == 72)
    }
}
