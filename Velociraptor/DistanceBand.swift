import SwiftUI

/// "Done" and "Left" along the track, under the speed and heart rate (FR-006–FR-009).
struct DistanceBand: View {
    let distances: TrackDistances
    /// The band's height; type sizes follow it so the digits fill the band at any screen size.
    let height: CGFloat
    /// Reports where the labels start inside the band, so the layout can close up the space above them.
    var onLabelsOffset: ((CGFloat) -> Void)?

    private static let space = "distanceBand"

    static func labelSize(forHeight height: CGFloat) -> CGFloat { max(11, height * 0.14) }

    var body: some View {
        HStack(spacing: 0) {
            value(label: "Done", text: distances.done, identifier: "distanceTravelled")
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: { onLabelsOffset?($0) }
            Divider().padding(.vertical, height * 0.15)
            value(label: "Left", text: distances.left, identifier: "distanceRemaining")
        }
        .padding(.horizontal)
        // Fill the band, so the labels' offset reflects their centring in it.
        .frame(maxHeight: .infinity)
        .coordinateSpace(.named(Self.space))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("distanceBand")
    }

    private func value(label: String, text: String, identifier: String) -> some View {
        let digitSize = height * 0.36
        let isKnown = text != TrackDistances.unknownText
        // One Text, so the number and unit shrink together instead of the number being cut off.
        let number = Text(text).font(.system(size: digitSize, weight: .regular, design: .rounded).monospacedDigit())
        let unit = Text(" km").font(.system(size: digitSize / 2, weight: .regular, design: .rounded)).foregroundStyle(.secondary)
        return VStack(spacing: 0) {
            Text(label)
                .font(.system(size: Self.labelSize(forHeight: height), weight: .medium))
                .foregroundStyle(.secondary)
            (isKnown ? number + unit : number)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
