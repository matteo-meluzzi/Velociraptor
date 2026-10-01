import Combine
import SwiftUI

enum PickerMessage: Equatable {
    case searching, noneFound, bluetoothOff, bluetoothDenied, bluetoothUnsupported

    var text: String {
        switch self {
        case .searching: "Searching for heart rate monitors…"
        case .noneFound: "No heart rate monitors found"
        case .bluetoothOff: "Turn on Bluetooth to connect a heart rate monitor"
        case .bluetoothDenied: "Velociraptor needs Bluetooth access to connect a heart rate monitor"
        case .bluetoothUnsupported: "Bluetooth is not available on this device"
        }
    }
}

struct HeartRateReading: Equatable {
    let bpm: Int
    let receivedAt: Date
}

@MainActor
final class HeartRateViewModel: ObservableObject {
    static let readingLifetime: TimeInterval = 5
    static let searchDuration: TimeInterval = 5

    @Published private(set) var heartRateText: String?
    @Published private(set) var heartRateBPM: Int?
    @Published private(set) var showsUnit = false
    @Published private(set) var buttonTitle = "Connect heart rate monitor"
    @Published private(set) var monitors: [DiscoveredMonitor] = []
    @Published private(set) var pickerMessage: PickerMessage? = .searching
    @Published var isPickerPresented = false
    @Published var alertMessage: String?

    var connectedMonitorID: UUID? {
        if case .connected(let id, _) = state { id } else { nil }
    }

    private let service: any HeartRateMonitorProviding
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()

    private var availability: BluetoothAvailability = .notDetermined
    @Published private var state: MonitorConnectionState = .none
    private var reading: HeartRateReading?
    private var searchStartedAt: Date?

    init(
        service: any HeartRateMonitorProviding,
        now: @escaping () -> Date = Date.init,
        ticks: AnyPublisher<Date, Never> = Timer.publish(every: 1, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
    ) {
        self.service = service
        self.now = now

        service.availability
            .sink { [weak self] in self?.availabilityChanged($0) }
            .store(in: &cancellables)
        service.connectionState
            .sink { [weak self] in self?.stateChanged($0) }
            .store(in: &cancellables)
        service.discoveredMonitors
            .sink { [weak self] in
                self?.monitors = $0
                self?.refresh()
            }
            .store(in: &cancellables)
        service.measurements
            .sink { [weak self] in self?.received($0) }
            .store(in: &cancellables)
        service.connectionFailures
            .sink { [weak self] in self?.alertMessage = "Couldn't connect to \($0)" }
            .store(in: &cancellables)
        ticks
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        refresh()
    }

    func connectButtonTapped() {
        isPickerPresented = true
        searchStartedAt = availability == .available ? now() : nil
        service.startScanning()
        refresh()
    }

    func select(_ monitor: DiscoveredMonitor) {
        service.connect(to: monitor.id)
        isPickerPresented = false
    }

    func pickerDismissed() {
        searchStartedAt = nil
        service.stopScanning()
        refresh()
    }

    func sceneBecameActive() {
        service.reconnectIfNeeded()
    }

    func refresh() {
        let current = now()
        if let reading, current.timeIntervalSince(reading.receivedAt) > Self.readingLifetime {
            self.reading = nil
        }
        updateMonitorTexts()
        updatePickerMessage(at: current)
    }

    // MARK: - Service events

    private func availabilityChanged(_ newValue: BluetoothAvailability) {
        let becameAvailable = newValue == .available && availability != .available
        availability = newValue
        if newValue != .available {
            searchStartedAt = nil
        } else if becameAvailable && isPickerPresented {
            searchStartedAt = now()
        }
        refresh()
    }

    private func stateChanged(_ newValue: MonitorConnectionState) {
        guard newValue != state else { return }
        state = newValue
        reading = nil
        refresh()
    }

    private func received(_ measurement: HeartRateMeasurement) {
        guard case .connected = state else { return }
        reading = measurement.isValid ? HeartRateReading(bpm: measurement.bpm, receivedAt: now()) : nil
        refresh()
    }

    // MARK: - Derived presentation

    private func updateMonitorTexts() {
        heartRateBPM = if case .connected = state { reading?.bpm } else { nil }
        switch state {
        case .none:
            heartRateText = nil
            showsUnit = false
            buttonTitle = "Connect heart rate monitor"
        case .connecting:
            heartRateText = "Connecting…"
            showsUnit = false
            buttonTitle = "Change heart rate monitor"
        case .connected:
            heartRateText = reading.map { String($0.bpm) } ?? "–"
            showsUnit = true
            buttonTitle = "Change heart rate monitor"
        case .lost:
            heartRateText = "–"
            showsUnit = true
            buttonTitle = "Change heart rate monitor"
        }
    }

    private func updatePickerMessage(at current: Date) {
        switch availability {
        case .poweredOff: pickerMessage = .bluetoothOff
        case .denied: pickerMessage = .bluetoothDenied
        case .unsupported: pickerMessage = .bluetoothUnsupported
        case .notDetermined, .pending: pickerMessage = .searching
        case .available:
            if !monitors.isEmpty {
                pickerMessage = nil
            } else if let started = searchStartedAt, current.timeIntervalSince(started) >= Self.searchDuration {
                pickerMessage = .noneFound
            } else {
                pickerMessage = .searching
            }
        }
    }
}

struct HeartRateView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    /// Smaller size used over the track map.
    var compact = false

    var body: some View {
        if let text = viewModel.heartRateText {
            HeartRateDisplay(text: text, bpm: viewModel.heartRateBPM, showsUnit: viewModel.showsUnit, compact: compact)
        }
    }
}

struct HeartRateDisplay: View {
    let text: String
    let bpm: Int?
    let showsUnit: Bool
    var compact = false

    var body: some View {
        Group {
            if showsUnit {
                ZStack {
                    HeartRateGauge(bpm: bpm, scale: compact ? 0.4 : 1)
                    VStack(spacing: 0) {
                        valueText(text)
                        Text("bpm")
                            .font(compact ? .caption2 : .title2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("heartRateUnit")
                    }
                    .padding(compact ? 14 : 40)
                }
                .frame(maxWidth: compact ? 72 : 320, maxHeight: compact ? 72 : 320)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, compact ? 0 : nil)
            } else {
                valueText(text)
            }
        }
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: compact ? 24 : 120, weight: compact ? .regular : .thin, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .accessibilityIdentifier("heartRateValue")
    }
}

/// Garmin-style ring of five colored zone arcs with a marker at the current heart rate.
struct HeartRateGauge: View {
    let bpm: Int?
    var zones = HeartRateZones()
    /// Scales strokes and marker for small gauges.
    var scale: CGFloat = 1

    private static let colors: [Color] = [.gray, .blue, .green, .orange, .red]
    /// SwiftUI angles: 0° is 3 o'clock, increasing clockwise. The gap is centered at 6 o'clock.
    private static let startAngle = 130.0
    private static let sweep = 280.0
    private static let segmentGap = 4.0
    private static let lineWidth: CGFloat = 10
    private static let activeLineWidth: CGFloat = 18

    var body: some View {
        let activeZone = bpm.map(zones.zone(for:))
        ZStack {
            ForEach(0..<HeartRateZones.count, id: \.self) { index in
                ZoneArc(index: index)
                    .stroke(
                        Self.colors[index],
                        style: StrokeStyle(lineWidth: (index == activeZone ? Self.activeLineWidth : Self.lineWidth) * scale)
                    )
                    .padding(Self.activeLineWidth * scale / 2)
            }
            if let bpm {
                GaugeMarker(size: 16 * scale)
                    .fill(.primary)
                    .padding((Self.activeLineWidth + 4) * scale)
                    .rotationEffect(.degrees(Self.startAngle + zones.position(for: bpm) * Self.sweep))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: bpm)
        .accessibilityHidden(true)
    }

    private struct ZoneArc: Shape {
        let index: Int

        func path(in rect: CGRect) -> Path {
            let segment = HeartRateGauge.sweep / Double(HeartRateZones.count)
            let start = HeartRateGauge.startAngle + Double(index) * segment + HeartRateGauge.segmentGap / 2
            let end = start + segment - HeartRateGauge.segmentGap
            var path = Path()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: min(rect.width, rect.height) / 2,
                startAngle: .degrees(start),
                endAngle: .degrees(end),
                clockwise: false
            )
            return path
        }
    }

    /// Triangle at the 3 o'clock edge pointing outward; rotated into place by the gauge.
    private struct GaugeMarker: Shape {
        let size: CGFloat

        func path(in rect: CGRect) -> Path {
            let radius = min(rect.width, rect.height) / 2
            let tipX = rect.midX + radius
            var path = Path()
            path.move(to: CGPoint(x: tipX, y: rect.midY))
            path.addLine(to: CGPoint(x: tipX - size, y: rect.midY - size * 0.6))
            path.addLine(to: CGPoint(x: tipX - size, y: rect.midY + size * 0.6))
            path.closeSubpath()
            return path
        }
    }
}

#Preview("Zones") {
    VStack {
        ForEach([nil, 85, 106, 150, 185], id: \.self) { bpm in
            HeartRateGauge(bpm: bpm).frame(width: 140, height: 140)
        }
    }
}

struct MonitorPickerView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.monitors) { monitor in
                    Button {
                        viewModel.select(monitor)
                    } label: {
                        HStack {
                            Text(monitor.name)
                            Spacer()
                            if viewModel.connectedMonitorID == monitor.id {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(viewModel.connectedMonitorID == monitor.id ? .isSelected : [])
                    .accessibilityIdentifier("monitorRow")
                }
                if let message = viewModel.pickerMessage {
                    HStack(spacing: 12) {
                        if message == .searching { ProgressView() }
                        Text(message.text)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("monitorPickerMessage")
                    }
                    if message == .bluetoothDenied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .accessibilityIdentifier("openSettingsButton")
                    }
                }
            }
            .navigationTitle("Heart rate monitors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isPickerPresented = false }
                }
            }
        }
    }
}
