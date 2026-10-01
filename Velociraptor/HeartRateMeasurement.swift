import Foundation

enum SensorContact: Equatable {
    case detected, notDetected, notSupported
}

struct HeartRateMeasurement: Equatable {
    let bpm: Int
    let contact: SensorContact

    /// Parses a Heart Rate Measurement (0x2A37) payload. Returns nil if it is too short.
    static func parse(_ data: Data) -> HeartRateMeasurement? {
        let start = data.startIndex
        guard data.count >= 2 else { return nil }
        let flags = data[start]
        let bpm: Int
        if flags & 0x01 == 0 {
            bpm = Int(data[start + 1])
        } else {
            guard data.count >= 3 else { return nil }
            bpm = Int(data[start + 1]) | (Int(data[start + 2]) << 8)
        }
        let contact: SensorContact
        switch (flags >> 1) & 0b11 {
        case 0b11: contact = .detected
        case 0b10: contact = .notDetected
        default: contact = .notSupported
        }
        return HeartRateMeasurement(bpm: bpm, contact: contact)
    }

    var isValid: Bool { bpm > 0 && contact != .notDetected }
}
