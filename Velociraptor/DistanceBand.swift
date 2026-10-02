import SwiftUI

/// "Done" and "Left" along the track, under the speed and heart rate (FR-006–FR-009).
struct DistanceBand: View {
    let distances: TrackDistances
    /// The band's height; type sizes follow it so the digits fill the band at any screen size.
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            value(label: "Done", text: distances.done, identifier: "distanceTravelled")
            Divider().padding(.vertical, height * 0.15)
            value(label: "Left", text: distances.left, identifier: "distanceRemaining")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("distanceBand")
    }

    private func value(label: String, text: String, identifier: String) -> some View {
        let digitSize = height * 0.45
        let isKnown = text != TrackDistances.unknownText
        return VStack(spacing: 0) {
            Text(label)
                .font(.system(size: max(11, height * 0.14), weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(text)
                    .font(.system(size: digitSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if isKnown {
                    Text("km")
                        .font(.system(size: digitSize / 2, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isKnown ? "\(text) kilometres" : "unknown")
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Distances", traits: .sizeThatFitsLayout) {
    VStack(spacing: 0) {
        DistanceBand(distances: TrackDistances(done: "3.47", left: "128.1"), height: 128)
            .frame(width: 393, height: 128)
            .background(.regularMaterial)
        DistanceBand(distances: .unknown, height: 128)
            .frame(width: 393, height: 128)
            .background(.regularMaterial)
    }
}
