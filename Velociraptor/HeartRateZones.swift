import Foundation

/// Five heart rate zones spanning 50–100% of max heart rate, each 10% wide:
/// 1 Warm Up 50–60%, 2 Easy 60–70%, 3 Aerobic 70–80%, 4 Threshold 80–90%, 5 Maximum 90–100%.
struct HeartRateZones: Equatable {
    static let count = 5
    static let defaultMaxHeartRate = 200

    let maxHeartRate: Int

    init(maxHeartRate: Int = Self.defaultMaxHeartRate) {
        self.maxHeartRate = maxHeartRate
    }

    /// Position on the gauge in 0...1; zone 1 starts at 50% of max, zone 5 ends at max.
    func position(for bpm: Int) -> Double {
        let position = Double(2 * bpm - maxHeartRate) / Double(maxHeartRate)
        return min(max(position, 0), 1)
    }

    /// Zero-based zone index in 0..<count.
    func zone(for bpm: Int) -> Int {
        // Tenths of max HR, computed from integers so exact boundaries don't round down.
        let tenths = Int((Double(bpm * 10) / Double(maxHeartRate)).rounded(.down))
        return min(max(tenths - 5, 0), Self.count - 1)
    }
}
