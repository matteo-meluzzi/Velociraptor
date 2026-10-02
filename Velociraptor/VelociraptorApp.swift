import SwiftUI
import CoreLocation
import Combine

struct ContentView : View {
    @ObservedObject var speedViewModel: OneValueModel
    @ObservedObject var locationStatusViewModel: LocationStatusViewModel
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @ObservedObject var trackViewModel: TrackViewModel

    @State private var topOverlayBottom: CGFloat = 0
    /// Measured in the top panel's own coordinates, so none of them depends on how far the band is pulled up.
    @State private var speedBottom: CGFloat = 0
    @State private var statusBottom: CGFloat = 0
    @State private var gaugeBottom: CGFloat = 0
    /// Where the distance labels start inside the band.
    @State private var labelsOffset: CGFloat = 0
    @State private var bottomBarTop: CGFloat = 0
    @State private var screen = ScreenMetrics()

    /// Share of the screen height (from the top edge) taken by speed and heart rate over the map.
    private static let topPanelShare: CGFloat = 0.3
    /// Share of the screen height taken by the distances band, directly under speed and heart rate (FR-006).
    private static let distanceBandShare: CGFloat = 0.15
    private static let topPanelPadding: CGFloat = 6
    private static let topPanelSpace = "topPanel"
    private static let topPanelSpacing: CGFloat = 16
    private static let bottomBarSpacing: CGFloat = 32

    private struct ScreenMetrics: Equatable {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var bottom: CGFloat = 0
        var safeTop: CGFloat = 0

        var isLandscape: Bool { width > height }
    }

    var body: some View {
        Group {
            if trackViewModel.track != nil {
                trackLayout
            } else {
                speedLayout
            }
        }
        .fileImporter(
            isPresented: $trackViewModel.isImporterPresented,
            allowedContentTypes: [.gpx],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await trackViewModel.importFile(at: url) } }
            case .failure:
                trackViewModel.importFailed()
            }
        }
        .alert(
            trackViewModel.alertMessage ?? "",
            isPresented: Binding(
                get: { trackViewModel.alertMessage != nil },
                set: { if !$0 { trackViewModel.alertMessage = nil } }
            )
        ) {
            Button("OK") { trackViewModel.alertMessage = nil }
        } message: {
            Text("The file is not a GPX track or has no track points.")
        }
        .sheet(isPresented: $heartRateViewModel.isPickerPresented, onDismiss: heartRateViewModel.pickerDismissed) {
            MonitorPickerView(viewModel: heartRateViewModel)
                .presentationDetents([.medium, .large])
        }
        .background {
            Color.clear.alert(
                heartRateViewModel.alertMessage ?? "",
                isPresented: Binding(
                    get: { heartRateViewModel.alertMessage != nil },
                    set: { if !$0 { heartRateViewModel.alertMessage = nil } }
                )
            ) {
                Button("OK") { heartRateViewModel.alertMessage = nil }
            }
        }
    }

    /// The speed screen as in feature 004, plus the import button.
    private var speedLayout: some View {
        VStack(spacing: 8) {
            Spacer()
            HeartRateView(viewModel: heartRateViewModel)
            SpeedView(viewModel: speedViewModel)
                .fixedSize()
                .layoutPriority(1)
            LocationStatusView(viewModel: locationStatusViewModel)
            Spacer()
            ViewThatFits(in: .horizontal) {
                HStack { heartRateButton; importButton }
                VStack { heartRateButton; importButton }
            }
            .labelStyle(.titleOnly)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Full-screen track map with compact speed, heart rate and distances on top (FR-009, 006 FR-006),
    /// and the buttons floating over the map, which runs to the bottom edge.
    private var trackLayout: some View {
        ZStack {
            TrackView(
                viewModel: trackViewModel,
                insets: EdgeInsets(top: topOverlayBottom, leading: 0, bottom: max(0, screen.bottom - bottomBarTop), trailing: 0)
            )

            VStack(spacing: 0) {
                Group {
                    if screen.isLandscape { landscapeTopBar } else { portraitTopPanel }
                }
                .background(.regularMaterial, ignoresSafeAreaEdges: [.top, .horizontal])
                // The map's visible area starts under the panel, so the user is centred in what can be seen (FR-012).
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topOverlayBottom = $0 }

                Spacer()

                // Large, well-spaced targets: easy to hit while moving.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Self.bottomBarSpacing) { floatingButtons }
                        .labelStyle(.titleOnly)
                    HStack(spacing: Self.bottomBarSpacing) { floatingButtons }
                        .labelStyle(.iconOnly)
                }
                .controlSize(.regular)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { bottomBarTop = $0 }
            }
        }
        // The map spans the whole screen, so insets and the panel share are measured against the full screen.
        .onGeometryChange(for: ScreenMetrics.self) { proxy in
            let frame = proxy.frame(in: .global)
            return ScreenMetrics(
                width: frame.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                height: frame.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom,
                bottom: frame.maxY + proxy.safeAreaInsets.bottom,
                safeTop: proxy.safeAreaInsets.top
            )
        } action: { screen = $0 }
    }

    /// Height available for speed and heart rate inside the top 30% of the screen.
    private var instrumentsHeight: CGFloat {
        max(0, Self.topPanelShare * screen.height - screen.safeTop - 2 * Self.topPanelPadding)
    }

    /// Speed and heart rate each get an equal share of the width; speed alone gets all of it.
    @ViewBuilder private var instruments: some View {
        let content = instrumentsHeight
        VStack(spacing: 2) {
            SpeedView(viewModel: speedViewModel, digitSize: min(120, content * 0.65))
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.topPanelSpace)).maxY } action: { speedBottom = $0 }
            LocationStatusView(viewModel: locationStatusViewModel)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height > 0 ? proxy.frame(in: .named(Self.topPanelSpace)).maxY : 0
                } action: { statusBottom = $0 }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        if heartRateViewModel.heartRateText != nil {
            // The gauge keeps its aspect ratio and shrinks to fit its share.
            HeartRateView(viewModel: heartRateViewModel, size: content)
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: content)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.topPanelSpace)).maxY } action: { gaugeBottom = $0 }
        }
    }

    /// Portrait: speed and heart rate in the top 30%, the distances band (15%) under them,
    /// pulled up to halve the empty space between the two.
    private var portraitTopPanel: some View {
        let panelHeight = max(0, Self.topPanelShare * screen.height - screen.safeTop)
        let bandHeight = Self.distanceBandShare * screen.height
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Self.topPanelSpacing) { instruments }
                .padding(.horizontal)
                .padding(.vertical, Self.topPanelPadding)
                .frame(maxWidth: .infinity)
                .frame(height: panelHeight)

            DistanceBand(
                distances: trackViewModel.distances ?? .unknown, height: bandHeight,
                onLabelsOffset: { labelsOffset = $0 }
            )
            .frame(maxWidth: .infinity)
            .frame(height: bandHeight)
            .padding(.top, -bandPull(panelHeight: panelHeight, bandHeight: bandHeight))
        }
        .coordinateSpace(.named(Self.topPanelSpace))
    }

    /// Half the visible gap between the instruments and the distance labels; 0 until everything is measured.
    /// Frames are corrected for SF Rounded metrics: the digits' frame reaches about 0.22 of the size below the
    /// digits (descender), and a label's frame starts about 0.2 of its size above the capitals.
    private func bandPull(panelHeight: CGFloat, bandHeight: CGFloat) -> CGFloat {
        guard speedBottom > 0, labelsOffset > 0 else { return 0 }
        let digitsBottom = speedBottom - 0.22 * min(120, instrumentsHeight * 0.65)
        let gauge = heartRateViewModel.heartRateText != nil ? gaugeBottom : 0
        let instrumentsBottom = max(digitsBottom, statusBottom, gauge)
        let labelsTop = panelHeight + labelsOffset + 0.2 * DistanceBand.labelSize(forHeight: bandHeight)
        return max(0, labelsTop - instrumentsBottom) / 2
    }

    /// Landscape: one bar with speed, heart rate and the distances side by side, so the map keeps most of the height.
    private var landscapeTopBar: some View {
        HStack(alignment: .center, spacing: Self.topPanelSpacing) {
            HStack(alignment: .center, spacing: Self.topPanelSpacing) { instruments }
                .frame(minWidth: 0, maxWidth: .infinity)
            DistanceBand(distances: trackViewModel.distances ?? .unknown, height: instrumentsHeight)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.vertical, Self.topPanelPadding)
        .frame(maxWidth: .infinity)
        .frame(height: max(0, Self.topPanelShare * screen.height - screen.safeTop))
    }

    /// The bottom buttons float over the map, each on its own material so it stays readable.
    @ViewBuilder private var floatingButtons: some View {
        Group { importButton; heartRateButton; closeTrackButton }
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }

    private var heartRateButton: some View {
        Button { heartRateViewModel.connectButtonTapped() } label: {
            Label(heartRateViewModel.buttonTitle, systemImage: "heart")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("heartRateMonitorButton")
    }

    private var importButton: some View {
        Button { trackViewModel.importButtonTapped() } label: {
            Label("Import GPX track", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("importTrackButton")
    }

    private var closeTrackButton: some View {
        Button(role: .destructive) { trackViewModel.closeTrack() } label: {
            Label("Close track", systemImage: "xmark")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("closeTrackButton")
    }
}

@main
struct VelociraptorApp: App {
    @StateObject private var speedViewModel: OneValueModel
    @StateObject private var locationStatusViewModel: LocationStatusViewModel
    @StateObject private var heartRateViewModel: HeartRateViewModel
    @StateObject private var trackViewModel: TrackViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _speedViewModel = StateObject(wrappedValue: OneValueModel(LocationPublisher(behavior: MetersPerSecondToKmh(inner: NilToZero(inner: SpeedBehavior())))))
        _locationStatusViewModel = StateObject(wrappedValue: LocationStatusViewModel(AuthorizationStatusPublisher()))
        _heartRateViewModel = StateObject(wrappedValue: HeartRateViewModel(service: BluetoothHeartRateService()))
        _trackViewModel = StateObject(wrappedValue: TrackViewModel(
            location: LocationPublisher(behavior: LocationFixBehavior()),
            heading: CompassHeadingPublisher(),
            authorization: AuthorizationStatusPublisher(),
            store: FileTrackStore.applicationSupport
        ))
        
        CLLocationManager().requestWhenInUseAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                speedViewModel: speedViewModel,
                locationStatusViewModel: locationStatusViewModel,
                heartRateViewModel: heartRateViewModel,
                trackViewModel: trackViewModel
            )
            .task { await trackViewModel.loadStoredTrack() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { heartRateViewModel.sceneBecameActive() }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                // Keep the screen on while the app is open (FR-024); normal auto-lock in the background.
                UIApplication.shared.isIdleTimerDisabled = phase == .active
            }
        }
    }
}

final class MockLocationProvider<T>: LocationProviding {
    private let valueSubject: CurrentValueSubject<T, Never>

    var publisher: AnyPublisher<T, Never> { valueSubject.eraseToAnyPublisher() }

    init(initialValue: T) {
        valueSubject = CurrentValueSubject(initialValue)
    }

    func send(value: T) { valueSubject.send(value) }
}
final class MockAuthorizationProvider: AuthorizationProviding {
    private let subject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var publisher: AnyPublisher<CLAuthorizationStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    init(status: CLAuthorizationStatus) {
        subject = CurrentValueSubject(status)
    }

    func send(_ status: CLAuthorizationStatus) { subject.send(status) }
}
final class PreviewHeartRateService: HeartRateMonitorProviding {
    private let availabilitySubject = CurrentValueSubject<BluetoothAvailability, Never>(.available)
    private let stateSubject = CurrentValueSubject<MonitorConnectionState, Never>(.none)
    private let monitorsSubject = CurrentValueSubject<[DiscoveredMonitor], Never>([])
    private let measurementSubject = CurrentValueSubject<HeartRateMeasurement?, Never>(nil)
    private let failureSubject = PassthroughSubject<String, Never>()
    private let id = UUID()

    var availability: AnyPublisher<BluetoothAvailability, Never> { availabilitySubject.eraseToAnyPublisher() }
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { stateSubject.eraseToAnyPublisher() }
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { monitorsSubject.eraseToAnyPublisher() }
    /// Replays the last measurement and re-emits it every second, like a live monitor, so the reading never goes stale.
    var measurements: AnyPublisher<HeartRateMeasurement, Never> {
        let repeated = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .compactMap { [weak self] _ in self?.measurementSubject.value }
        return measurementSubject.compactMap { $0 }.merge(with: repeated).eraseToAnyPublisher()
    }
    var connectionFailures: AnyPublisher<String, Never> { failureSubject.eraseToAnyPublisher() }

    func startScanning() {
        monitorsSubject.send([DiscoveredMonitor(id: id, name: "Polar H10", rssi: -50, lastSeen: Date())])
    }
    func stopScanning() {}
    func connect(to monitorID: UUID) { stateSubject.send(.connecting(monitorID: monitorID, name: "Polar H10", origin: .user)) }
    func reconnectIfNeeded() {}
    func disconnect() { stateSubject.send(.none) }

    static func connected(bpm: Int = 142) -> PreviewHeartRateService {
        let service = PreviewHeartRateService()
        service.measurementSubject.send(HeartRateMeasurement(bpm: bpm, contact: .detected))
        service.stateSubject.send(.connected(monitorID: service.id, name: "Polar H10"))
        return service
    }

    /// Shifts the reading by `delta` bpm, connecting first if needed so the reading is shown.
    func changeBPM(by delta: Int) {
        if case .connected = stateSubject.value {} else {
            stateSubject.send(.connected(monitorID: id, name: "Polar H10"))
        }
        let bpm = (measurementSubject.value?.bpm ?? 100) + delta
        measurementSubject.send(HeartRateMeasurement(bpm: bpm, contact: .detected))
    }

    func cycleState() {
        switch stateSubject.value {
        case .none: stateSubject.send(.connecting(monitorID: id, name: "Polar H10", origin: .user))
        case .connecting: stateSubject.send(.connected(monitorID: id, name: "Polar H10"))
            measurementSubject.send(HeartRateMeasurement(bpm: 142, contact: .detected))
        case .connected: stateSubject.send(.lost(monitorID: id, name: "Polar H10"))
        case .lost: stateSubject.send(.none)
        }
    }
}

final class PreviewHeadingProvider: HeadingProviding {
    private let subject = CurrentValueSubject<CompassHeading?, Never>(nil)
    var publisher: AnyPublisher<CompassHeading?, Never> { subject.eraseToAnyPublisher() }
    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation) {}
}

@MainActor
private func previewTrackViewModel(
    trackAround center: CLLocationCoordinate2D? = nil,
    location: MockLocationProvider<LocationFix?> = MockLocationProvider(initialValue: nil)
) -> TrackViewModel {
    let store = FileTrackStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    if let center {
        // Three segments heading north-east past `center`, with a gap between them.
        let segments = (0..<3).map { s in
            TrackSegment(points: (0..<20).map { i in
                let step = Double(s * 22 + i) - 30
                return TrackPoint(latitude: center.latitude + step * 0.0003, longitude: center.longitude + step * 0.0002)
            })
        }
        try? store.save(Track(name: "Preview loop", segments: segments))
    }
    return TrackViewModel(
        location: location,
        heading: PreviewHeadingProvider(),
        authorization: MockAuthorizationProvider(status: .authorizedAlways),
        store: store
    )
}

#Preview {
    let speedModel = MockLocationProvider(initialValue: 0.0)
    var speed = 0.0
    let heartRateService = PreviewHeartRateService()
    VStack {
        ContentView(
            speedViewModel: OneValueModel(speedModel),
            locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)),
            heartRateViewModel: HeartRateViewModel(service: heartRateService),
            trackViewModel: previewTrackViewModel()
        )
        
        VStack {
            HStack {
                Button("decelerate") {
                    speed -= 1
                    speedModel.send(value: speed)
                }
                Button("accelerate") {
                    speed += 1
                    speedModel.send(value: speed)
                }
            }
            HStack {
                Button("decrease bpm") { heartRateService.changeBPM(by: -5) }
                Button("increase bpm") { heartRateService.changeBPM(by: 5) }
            }
            Button("cycle heart rate state") { heartRateService.cycleState() }
        }
        .buttonStyle(.bordered)
    }
}

#Preview("Landscape, heart rate shown", traits: .landscapeLeft) {
    let heartRateService = PreviewHeartRateService.connected(bpm: 188)
    ContentView(
        speedViewModel: OneValueModel(MockLocationProvider(initialValue: 188.8)),
        locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)),
        heartRateViewModel: HeartRateViewModel(service: heartRateService),
        trackViewModel: previewTrackViewModel()
    )
}

#Preview("Track loaded") {
    let here = CLLocationCoordinate2D(latitude: 45.0703, longitude: 7.6869)
    let location = MockLocationProvider<LocationFix?>(initialValue: LocationFix(
        coordinate: here, horizontalAccuracy: 8, speed: 3, course: 30
    ))
    let trackViewModel = previewTrackViewModel(trackAround: here, location: location)
    ContentView(
        speedViewModel: OneValueModel(MockLocationProvider(initialValue: 10.8)),
        locationStatusViewModel: LocationStatusViewModel(MockAuthorizationProvider(status: .authorizedAlways)),
        heartRateViewModel: HeartRateViewModel(service: PreviewHeartRateService.connected(bpm: 151)),
        trackViewModel: trackViewModel
    )
    .task { await trackViewModel.loadStoredTrack() }
}
