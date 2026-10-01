---

description: "Task list for BLE Heart Rate Monitor"
---

# Tasks: BLE Heart Rate Monitor

**Input**: Design documents from `specs/004-ble-heart-rate-monitor/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/heart-rate-service.md, quickstart.md

**Tests**: Included. The plan requires unit tests for the parser, the connection machine and the view model (Constitution II), using Swift Testing (`import Testing`, `@Test`, `#expect`, `@testable import Velociraptor`). CoreBluetooth itself is verified manually (quickstart.md).

**Organization**: Tasks are grouped by user story. Both stories are P1; US1 (connect and show heart rate) is the feature, US2 (speed unaffected) hardens and verifies the layout and independence once US1's UI exists.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1, US2)

## Path Conventions

- App sources: `Velociraptor/` (flat; `fileSystemSynchronizedGroups`, so new files are picked up automatically, no `project.pbxproj` file-reference edits needed)
- Unit tests: `VelociraptorTests/`
- Build settings: `Velociraptor.xcodeproj/project.pbxproj`

## Commit gates (apply to every "Gate" task)

Per the constitution, in order: (1) `xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` exits 0; (2) `xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'` passes; (3) a reviewer agent reviews `git diff` + `git diff --cached` and approves; fix any blocking feedback and re-run (1)–(3); (4) commit. A task is not complete until its gate passes.

---

## Phase 1: Setup (Repair the test target — plan Task 0, research R11)

**Purpose**: `xcodebuild test` currently fails to compile; nothing can be committed until it is green.

- [X] T001 Rewrite `VelociraptorTests/SpeedViewModelTests.swift` against the current `OneValueModel` (in `Velociraptor/SpeedView.swift`, initializer `OneValueModel(_ locationProvider: any LocationProviding<Double>)`, output `displayValue` formatted `"%.1f"`, no unit conversion). Keep `@MainActor struct SpeedViewModelTests`. Use `MockLocationProvider<Double>(initialValue: 0.0)` from `VelociraptorTests/MockLocationProvider.swift`. Tests: `initialValueIsFormatted` (initial 0.0 → `"0.0"`), `lowSpeedFormatsCorrectly` (send 3.2 → `"3.2"`), `higherSpeedFormatsCorrectly` (send 87.4 → `"87.4"`), `valueIsRoundedToOneDecimal` (send 12.36 → `"12.4"`). Remove all references to `SpeedModel`/`displaySpeed`
- [X] T002 [P] Delete `VelociraptorTests/AltitudeViewModelTests.swift` (altitude feature removed; references nonexistent `AltitudeViewModel`). Leave the duplicate preview mocks in `Velociraptor/VelociraptorApp.swift` as they are (R11)
- [X] T003 Gate: run the commit gates on the T001–T002 diff and commit ("test: repair test target after refactor"). Do not include unrelated working-tree changes in this commit (e.g. an unrelated `IPHONEOS_DEPLOYMENT_TARGET` edit in `Velociraptor.xcodeproj/project.pbxproj` — ask the user about it rather than committing it silently)

**Checkpoint**: Build and test suite green on `main`-equivalent code.

---

## Phase 2: Foundational (Shared types, parser, mock — plan Tasks 1 and 2)

**Purpose**: Types and test doubles every later task depends on. `HeartRateMeasurement` is here (not only in US1) because the `HeartRateMonitorProviding` protocol exposes it.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Heart rate measurement parser (plan Task 1)

- [X] T004 [P] Write `VelociraptorTests/HeartRateMeasurementTests.swift` (`struct HeartRateMeasurementTests`), one `@Test` per row of the contract byte table in `contracts/heart-rate-service.md`, building `Data([...])` from the hex bytes: `00 48` → bpm 72, contact `.notSupported`, `isValid == true`; `01 48 00` → bpm 72 (UInt16); `01 2C 01` → bpm 300; `06 50` → bpm 80, contact `.detected`, valid; `04 50` → bpm 80, contact `.notDetected`, `isValid == false`; `10 48 00 03` → bpm 72 (RR bytes ignored); `00 00` → bpm 0, `isValid == false`; empty `Data()` → `nil`; `00` → `nil`; `01 48` → `nil`. Add `02 50` → contact `.notSupported` (bits 1–2 = `0b01`, treated as contact OK, valid)
- [X] T005 [P] Create `Velociraptor/HeartRateMeasurement.swift`: `enum SensorContact: Equatable { case detected, notDetected, notSupported }`; `struct HeartRateMeasurement: Equatable { let bpm: Int; let contact: SensorContact }`; `static func parse(_ data: Data) -> HeartRateMeasurement?` per research R2 — byte 0 = flags; bit 0 = 0 → bpm is `UInt8` at byte 1, bit 0 = 1 → `UInt16` little-endian at bytes 1–2; bits 1–2: `0b11` → `.detected`, `0b10` → `.notDetected`, `0b00`/`0b01` → `.notSupported`; bits 3–4 ignored; return `nil` for an empty or too-short payload (never crash, index via `data.startIndex` offsets so slices work); `var isValid: Bool { bpm > 0 && contact != .notDetected }`. No CoreBluetooth import. T004 must pass

### Service boundary types (plan Task 2)

- [X] T006 Create `Velociraptor/HeartRateMonitorProviding.swift` with the state types from data-model.md: `enum BluetoothAvailability: Equatable { case notDetermined, pending, available, poweredOff, denied, unsupported }` (keep the comments: notDetermined = central not yet created, pending = `.unknown`/`.resetting`, available = `.poweredOn`, denied = `.unauthorized`, unsupported = `.unsupported`); `enum ConnectOrigin: Equatable { case user, automatic }`; `enum MonitorConnectionState: Equatable { case none; case connecting(monitorID: UUID, name: String, origin: ConnectOrigin); case connected(monitorID: UUID, name: String); case lost(monitorID: UUID, name: String) }` plus computed `monitorID: UUID?` and `name: String?` (nil for `.none`). No CoreBluetooth import
- [X] T007 In `Velociraptor/HeartRateMonitorProviding.swift` add `struct DiscoveredMonitor: Identifiable, Equatable { let id: UUID; let name: String; let rssi: Int; let lastSeen: Date }` and pure helpers: `static let unnamedName = "Unnamed heart rate monitor"`; `static func displayName(advertisedName: String?, peripheralName: String?) -> String` (advertised local name → peripheral name → `unnamedName`; treat empty strings as missing); `static func visibleList(_ monitors: [DiscoveredMonitor], now: Date, connected: DiscoveredMonitor?) -> [DiscoveredMonitor]` — drop entries where `now − lastSeen > 5 s`, sort by `rssi` descending with `127` ("unavailable") last, duplicate names allowed (identity is `id`), then pin `connected` first and remove any other entry with the same `id` (contract C3)
- [X] T008 In `Velociraptor/HeartRateMonitorProviding.swift` add the protocol exactly as in `contracts/heart-rate-service.md`: `protocol HeartRateMonitorProviding: AnyObject` with `availability`, `connectionState`, `discoveredMonitors`, `measurements: AnyPublisher<HeartRateMeasurement, Never>`, `connectionFailures: AnyPublisher<String, Never>`, and `startScanning()`, `stopScanning()`, `connect(to monitorID: UUID)`, `reconnectIfNeeded()`. Doc-comment each member with its contract note ("current value replayed", "user-initiated only", etc.)
- [X] T009 In `Velociraptor/HeartRateMonitorProviding.swift` add `protocol LastMonitorStoring: AnyObject { var lastMonitorID: UUID? { get set }; var lastMonitorName: String? { get set } }` and `final class UserDefaultsLastMonitorStore: LastMonitorStoring` with `init(defaults: UserDefaults = .standard)`, keys exactly `"lastHeartRateMonitorID"` (stored as `uuidString`; an unparsable string reads as `nil`) and `"lastHeartRateMonitorName"`; setting `nil` removes the key
- [X] T010 [P] Create `VelociraptorTests/MockHeartRateService.swift`: `final class MockHeartRateService: HeartRateMonitorProviding` backed by `CurrentValueSubject<BluetoothAvailability, Never>(.notDetermined)`, `CurrentValueSubject<MonitorConnectionState, Never>(.none)`, `CurrentValueSubject<[DiscoveredMonitor], Never>([])`, `PassthroughSubject<HeartRateMeasurement, Never>`, `PassthroughSubject<String, Never>`; helpers `send(availability:)`, `send(state:)`, `send(monitors:)`, `send(measurement:)`, `sendFailure(name:)`; call recording `startScanningCallCount`, `stopScanningCallCount`, `connectedIDs: [UUID]`, `reconnectIfNeededCallCount`. Also `final class InMemoryLastMonitorStore: LastMonitorStoring` with plain stored properties
- [X] T011 [P] Create `VelociraptorTests/HeartRateMonitorProvidingTests.swift`: tests for `DiscoveredMonitor.visibleList` (prunes entry seen 5.1 s ago, keeps entry seen exactly 5 s ago, sorts −40 before −70, puts rssi 127 last, keeps two entries with the same name, pins connected first and de-duplicates it) and `displayName` (advertised wins, falls back to peripheral name, falls back to "Unnamed heart rate monitor", empty string counts as missing); tests for `UserDefaultsLastMonitorStore` using `UserDefaults(suiteName: "HeartRateTests-\(UUID())")!` (round-trips ID and name, setting nil removes, garbage ID string reads nil)
- [X] T012 Gate: run the commit gates on Phase 2 and commit ("feat: heart rate measurement parser and service types")

**Checkpoint**: Parser, shared types and mock compile and are tested — user story work can begin.

---

## Phase 3: User Story 1 - Connect a Heart Rate Monitor and See Heart Rate (Priority: P1) 🎯 MVP

**Goal**: Button → sheet listing nearby monitors (nearest first, live) → select → Connecting → heart rate + "bpm" under the speed; failure message, Lost + auto-reconnect, remembered monitor reconnects at launch, Bluetooth off/denied messages.

**Independent Test**: On a device with a worn monitor, tap "Connect heart rate monitor", pick it, and see "<n> bpm" under the speed following the heart rate (quickstart scenarios 2–13). Logic is covered by `HeartRateConnectionMachineTests` and `HeartRateViewModelTests` in the Simulator.

### Connection state machine (plan Task 3)

- [X] T013 [US1] Create `Velociraptor/HeartRateConnectionMachine.swift` with the event/effect types from research R9: `enum ConnectionEvent: Equatable { case launch(storedID: UUID?, storedName: String?); case userSelected(id: UUID, name: String); case didConnect(id: UUID); case subscribed(id: UUID); case didFail(id: UUID); case didDisconnect(id: UUID); case timeoutFired(id: UUID); case availabilityChanged(BluetoothAvailability); case sceneActive }` and `enum ConnectionEffect: Equatable { case retrieveAndConnect(id: UUID); case connect(id: UUID); case cancel(id: UUID); case startTimeout(id: UUID); case cancelTimeout; case saveLastMonitor(id: UUID, name: String); case emitFailure(name: String) }` (`launch` and `saveLastMonitor` carry the name because the state and `LastMonitorStoring` need it). Declare `struct HeartRateConnectionMachine { private(set) var state: MonitorConnectionState = .none; private(set) var availability: BluetoothAvailability = .notDetermined; private(set) var hasPendingConnect = false; private var pendingLaunch: (id: UUID, name: String)?; static let connectTimeout: TimeInterval = 10; mutating func handle(_ event: ConnectionEvent) -> [ConnectionEffect] }` with a stub body. No CoreBluetooth import
- [X] T014 [US1] Write `VelociraptorTests/HeartRateConnectionMachineTests.swift` — user selection rows of the data-model Transitions table (assert both resulting `state` and the exact effect array, in order). Set availability `.available` first in each test. Tests: `noneUserSelectsConnectsWithTimeout` (none + userSelected(M) → connecting(M, .user); effects `[saveLastMonitor(M), connect(M), startTimeout(M)]`); `switchingCancelsPreviousMonitor` (from connected(M), lost(M) and connecting(M, .user) each: userSelected(M′) → connecting(M′, .user); effects `[cancelTimeout?, cancel(M), saveLastMonitor(M′), connect(M′), startTimeout(M′)]` — include `cancelTimeout` only when leaving a connecting state); `selectingConnectedMonitorIsNoOp` (connected(M) + userSelected(M) → unchanged, `[]`); `selectingLostOrAutomaticMonitorBecomesUserConnect` (lost(M) / connecting(M, .automatic) + userSelected(M) → connecting(M, .user); effects `[cancelTimeout?, cancel(M), saveLastMonitor(M), connect(M), startTimeout(M)]`)
- [X] T015 [US1] In `VelociraptorTests/HeartRateConnectionMachineTests.swift` add launch and connecting-outcome tests: `launchWithoutStoredMonitorDoesNothing`; `launchWaitsForFirstPoweredOn` (launch(M) while `.notDetermined` → `[]`, state none; then availabilityChanged(.pending) → `[]`; then `.available` → connecting(M, .automatic), `[retrieveAndConnect(M), startTimeout(M)]`); `launchReconnectRunsOnceOnly` (a second `.available` after poweredOff does not repeat the launch path when state is none); `userConnectSubscribedBecomesConnected` (`[cancelTimeout]`); `userConnectFailureGoesToNoneWithMessage` (for each of didFail(M), didDisconnect(M) before subscribe, timeoutFired(M): → none, effects include `cancel(M)` and `emitFailure(name)`, plus `cancelTimeout` unless the event was the timeout); `userConnectCutByBluetoothOffFailsWithMessage` (availabilityChanged(.poweredOff) → none, `emitFailure`, `cancelTimeout`); `automaticConnectSubscribedBecomesConnected`; `automaticConnectFailureGoesLostWithPendingConnect` (didFail / timeoutFired → lost(M); effects `[cancelTimeout?, cancel(M), connect(M)]`; `hasPendingConnect == true`); `retrievalFailureInLostLeavesLostWithoutPending` (lost + didFail(M) → lost, `[]`, `hasPendingConnect == false`)
- [X] T016 [US1] In `VelociraptorTests/HeartRateConnectionMachineTests.swift` add connected/lost/availability/scene tests: `connectedDisconnectGoesLostAndReconnects` (→ lost(M), `[connect(M)]`, pending true); `lostSubscribedBecomesConnected` (pending false); `sceneActiveInLostWithoutPendingReconnects` (→ `[retrieveAndConnect(M)]`, pending true); `sceneActiveIsIdempotent` (C8: no-op when connected, when none, and when a connect is already pending); `bluetoothOffWhileConnectedGoesLost` (C10: connected / lost / connecting(.automatic) + availabilityChanged(.poweredOff), `.pending` and `.denied` → lost(M), pending false, `cancelTimeout` only from connecting); `bluetoothOnWhileLostReRetrieves` (lost + availabilityChanged(.available) → unchanged, `[retrieveAndConnect(M)]`, pending true); `availabilityIsTracked` (`machine.availability` follows every availabilityChanged)
- [X] T017 [US1] In `VelociraptorTests/HeartRateConnectionMachineTests.swift` add stale-callback and contract tests: `staleCallbacksAreIgnored` (after switching M → M′: didDisconnect(M), didFail(M), subscribed(M), timeoutFired(M) all → state unchanged, `[]`; FR-003, C5); `atMostOneMonitorTargeted` (C4: every userSelected from a non-none state emits `cancel` of the old ID before `connect` of the new one); `failuresEmittedOnlyForUserConnects` (C6: no `emitFailure` across any automatic-path test sequence); `lastMonitorSavedOnEverySelectionEvenIfItFails` (C7: `saveLastMonitor` present on userSelected, and the following timeout does not undo it); `savedMonitorButNoPermissionAtLaunch` (R6: launch(M) while `.notDetermined`, then the user's first scan leads to `.available` → connecting(M, .automatic))
- [X] T018 [US1] Implement `HeartRateConnectionMachine.handle(_:)` in `Velociraptor/HeartRateConnectionMachine.swift` so that every row of the data-model Transitions table and every test in T014–T017 passes. Rules to follow exactly: callbacks (`didConnect`, `subscribed`, `didFail`, `didDisconnect`, `timeoutFired`) whose ID ≠ `state.monitorID` return `[]`; `didConnect` changes nothing (the adapter runs discovery itself); `didDisconnect` while connecting is handled like `didFail`; leaving any connecting state emits `cancelTimeout` (except on `timeoutFired`); `hasPendingConnect` is set by `connect`/`retrieveAndConnect` effects and cleared on `subscribed`, on `didFail` in lost, and when availability leaves `.available`; `launch` only records `pendingLaunch`, which is consumed by the first `availabilityChanged(.available)` while state is none
- [X] T019 [US1] Gate: run the commit gates and commit ("feat: heart rate connection state machine")

### View model (plan Task 4)

- [X] T020 [US1] Create the view model skeleton in `Velociraptor/HeartRateView.swift`: `enum PickerMessage: Equatable { case searching, noneFound, bluetoothOff, bluetoothDenied, bluetoothUnsupported }` with a `text` property returning exactly "Searching for heart rate monitors…", "No heart rate monitors found", "Turn on Bluetooth to connect a heart rate monitor", "Velociraptor needs Bluetooth access to connect a heart rate monitor", "Bluetooth is not available on this device"; `struct HeartRateReading: Equatable { let bpm: Int; let receivedAt: Date }`; `@MainActor final class HeartRateViewModel: ObservableObject` with `@Published private(set) var heartRateText: String?`, `showsUnit: Bool`, `buttonTitle: String`, `monitors: [DiscoveredMonitor]`, `pickerMessage: PickerMessage?`, `@Published var isPickerPresented = false`, `@Published var alertMessage: String?`; `init(service: any HeartRateMonitorProviding, now: @escaping () -> Date = Date.init, ticks: AnyPublisher<Date, Never> = Timer.publish(every: 1, on: .main, in: .common).autoconnect().eraseToAnyPublisher())`; methods `connectButtonTapped()`, `select(_ monitor: DiscoveredMonitor)`, `pickerDismissed()`, `sceneBecameActive()`, `refresh()` (stub bodies)
- [X] T021 [US1] Write `VelociraptorTests/HeartRateViewModelTests.swift` (`@MainActor struct HeartRateViewModelTests`, using `MockHeartRateService`, a mutable `var now = Date(timeIntervalSince1970: 0)` captured by the `now` closure, and a `PassthroughSubject<Date, Never>` as `ticks`) — Monitor States table: `noneHidesHeartRate` (`heartRateText == nil`, `showsUnit == false`, button "Connect heart rate monitor"); `connectingShowsConnecting` ("Connecting…", no unit, "Change heart rate monitor"); `connectedWithoutReadingShowsDash` ("–", unit shown); `connectedValidReadingShowsValue` (measurement bpm 72 → "72"); `readingUpdates` (72 then 75 → "75"); `lostShowsDash` ("–", unit, "Change heart rate monitor")
- [X] T022 [US1] In `VelociraptorTests/HeartRateViewModelTests.swift` add reading-validity tests (R7, SC-005): `zeroBpmShowsDashImmediately`; `lostContactShowsDashImmediately` (contact `.notDetected`); `invalidMeasurementClearsPreviousReading` (72 then 0 → "–", then still "–" after refresh); `readingGoesStaleAfterFiveSeconds` (advance `now` 5 s + refresh → still "72"; 5.1 s + refresh → "–"); `tickTriggersRefresh` (advance `now` 6 s, send on `ticks` → "–"); `readingClearedWhenLeavingConnected` (72 shown, state → lost → connected(M′) → "–", not "72")
- [X] T023 [US1] In `VelociraptorTests/HeartRateViewModelTests.swift` add picker tests: `buttonTapPresentsPickerAndStartsScanning` (`isPickerPresented`, `startScanningCallCount == 1`); `dismissStopsScanningAndKeepsState` (scenario 8: state and texts unchanged, `stopScanningCallCount == 1`); `selectConnectsAndClosesPicker` (scenario 2: `connectedIDs == [M]`, `isPickerPresented == false`); `monitorsMirrorService` (sends list → `monitors` equals it, order preserved); `searchingThenNoneFound` (scenario 9: available + empty list → `.searching`; after 5 s + refresh → `.noneFound`; a monitor appearing clears the message); `notDeterminedAndPendingShowSearching`; `bluetoothOffMessage`, `bluetoothDeniedMessage`, `bluetoothUnsupportedMessage` (scenario 11); `bluetoothTurnedOnWhilePickerOpenShowsSearching` (`.poweredOff` → `.available` while presented → `.searching`, search timer restarts from that moment); `userConnectFailureShowsAlert` (scenario 3: `sendFailure(name: "Polar H10")` → `alertMessage == "Couldn't connect to Polar H10"`); `sceneActiveRequestsReconnect` (`reconnectIfNeededCallCount == 1`)
- [X] T024 [US1] Implement `HeartRateViewModel` in `Velociraptor/HeartRateView.swift` so T021–T023 pass: subscribe to all five service publishers (`.receive(on:)` not needed — main queue); map state per the spec Monitor States table and data-model "HeartRateViewModel (presentation state)" table; keep `HeartRateReading?` (set only for `isValid` measurements while connected, cleared on invalid measurement and on any state that is not `.connected`); show the value only while `now() − receivedAt ≤ 5`; record `searchStartedAt = now()` when the picker is presented with availability `.available` (or when availability becomes `.available` while presented) and show `.noneFound` once `now() − searchStartedAt ≥ 5` with an empty list; `connectButtonTapped` → present + `startScanning()`; `select` → `connect(to: monitor.id)` + close (the machine makes re-selecting the connected monitor a no-op); `pickerDismissed` → `stopScanning()`; `sceneBecameActive` → `reconnectIfNeeded()`; `ticks` sink calls `refresh()`
- [X] T025 [US1] Gate: run the commit gates and commit ("feat: heart rate view model")

### CoreBluetooth adapter (plan Task 5)

- [X] T026 [P] [US1] Add `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription = "Velociraptor uses Bluetooth to connect to your heart rate monitor.";` to the **Velociraptor app target** Debug and Release build settings in `Velociraptor.xcodeproj/project.pbxproj`, next to the two existing `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` lines (not the test targets)
- [X] T027 [US1] Create `Velociraptor/BluetoothHeartRateService.swift`: `protocol TimeoutScheduling { func schedule(after: TimeInterval, _ action: @escaping () -> Void) -> AnyCancellable }` with a `MainQueueScheduler` default using `DispatchQueue.main.asyncAfter` + `DispatchWorkItem` (C11); `final class BluetoothHeartRateService: NSObject, HeartRateMonitorProviding, CBCentralManagerDelegate, CBPeripheralDelegate` with `init(store: LastMonitorStoring = UserDefaultsLastMonitorStore(), scheduler: TimeoutScheduling = MainQueueScheduler())`. Holds `var machine = HeartRateConnectionMachine()`, `CurrentValueSubject`s for availability/state/discovered, `PassthroughSubject`s for measurements/failures, `private var central: CBCentralManager?`, `private var targetPeripheral: CBPeripheral?` (strong reference, R6), `private var seen: [UUID: DiscoveredMonitor]`, `private var wantsScan = false`. Central created with `CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])` only from `startScanning()` or in `init` when `CBManager.authorization == .allowedAlways` (C1, FR-007). `init` sends `.launch(storedID: store.lastMonitorID, storedName: store.lastMonitorName)` to the machine
- [X] T028 [US1] In `Velociraptor/BluetoothHeartRateService.swift` add the event/effect plumbing: `private func send(_ event: ConnectionEvent)` → `machine.handle` → publish `machine.state`/`machine.availability` → execute each effect: `retrieveAndConnect(id)` → `central.retrievePeripherals(withIdentifiers: [id]).first`, if nil send `.didFail(id)`, else store as target, set delegate, `central.connect`; `connect(id)` → reuse target if its identifier matches, else retrieve as above; `cancel(id)` → `central.cancelPeripheralConnection` on the target if it matches, then nil it; `startTimeout(id)` → `scheduler.schedule(after: HeartRateConnectionMachine.connectTimeout) { send(.timeoutFired(id: id)) }` stored in one `AnyCancellable`; `cancelTimeout` → cancel it; `saveLastMonitor(id, name)` → write `store`; `emitFailure(name)` → failures subject. Map `centralManagerDidUpdateState` to `BluetoothAvailability` per R4 (`.poweredOn` → available, `.poweredOff` → poweredOff, `.unauthorized` → denied, `.unsupported` → unsupported, `.unknown`/`.resetting` → pending) and send `.availabilityChanged`; when leaving `.poweredOn` drop `targetPeripheral` and the scan list (R6)
- [X] T029 [US1] In `Velociraptor/BluetoothHeartRateService.swift` implement the connect sequence (R6): `didConnect` → send `.didConnect`, then `peripheral.discoverServices([CBUUID(string: "180D")])`; `didDiscoverServices` → `discoverCharacteristics([CBUUID(string: "2A37")], for: hrService)`; `didDiscoverCharacteristicsFor` → `setNotifyValue(true, for:)`; `didUpdateNotificationStateFor` with no error and `isNotifying` → send `.subscribed`; any error or missing service/characteristic → send `.didFail`; `didFailToConnect` → `.didFail`; `didDisconnectPeripheral` → `.didDisconnect`; `didUpdateValueFor` 0x2A37 → `HeartRateMeasurement.parse` → measurements subject (drop `nil`). Ignore every callback whose `peripheral.identifier` is not the current target (C5)
- [X] T030 [US1] In `Velociraptor/BluetoothHeartRateService.swift` implement scanning (R5, C2, C3): `startScanning()` creates the central if needed, sets `wantsScan = true`, and if powered on calls `scanForPeripherals(withServices: [CBUUID(string: "180D")], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])` and starts a repeating 1 s prune via the scheduler; `centralManagerDidUpdateState(.poweredOn)` starts the scan when `wantsScan` (scenario 11); `didDiscover` updates `seen[id]` with `DiscoveredMonitor.displayName(advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String, peripheralName: peripheral.name)`, `RSSI.intValue`, `Date()`; publish `DiscoveredMonitor.visibleList(Array(seen.values), now: Date(), connected:)` where `connected` is built from `.connected(id, name)` state with rssi `0` and `lastSeen: Date()`; `stopScanning()` sets `wantsScan = false`, stops the scan and the prune tick, clears `seen` and publishes the list. `connect(to:)` looks up the name in `seen` (fallback `DiscoveredMonitor.unnamedName`) and sends `.userSelected`; `reconnectIfNeeded()` sends `.sceneActive`
- [X] T031 [US1] Gate: run the commit gates and commit ("feat: CoreBluetooth heart rate service")

### UI and wiring (plan Task 6)

- [X] T032 [US1] In `Velociraptor/HeartRateView.swift` add `struct HeartRateView: View` (`@ObservedObject var viewModel: HeartRateViewModel`): renders nothing when `heartRateText == nil` (no reserved space); otherwise `HStack(alignment: .lastTextBaseline, spacing: 8)` with `Text(heartRateText)` at `.system(size: 56, weight: .thin, design: .rounded).monospacedDigit()`, `.minimumScaleFactor(0.5)`, `.lineLimit(1)`, accessibility identifier `heartRateValue`; and, when `showsUnit`, `Text("bpm")` in `.title3` `.secondary`, identifier `heartRateUnit` (R10, FR-004)
- [X] T033 [US1] In `Velociraptor/HeartRateView.swift` add `struct MonitorPickerView: View` (`@ObservedObject var viewModel: HeartRateViewModel`, `@Environment(\.openURL)`): `NavigationStack` titled "Heart rate monitors" with a `List` of `viewModel.monitors` — each a `Button(monitor.name) { viewModel.select(monitor) }` with identifier `monitorRow`, and a checkmark on the row whose `id` equals the connected monitor; when `pickerMessage != nil` show its `text` (identifier `monitorPickerMessage`, with a `ProgressView` for `.searching`) and, for `.bluetoothDenied`, a `Button("Open Settings")` (identifier `openSettingsButton`) calling `openURL(URL(string: UIApplication.openSettingsURLString)!)`; a "Cancel" toolbar button sets `isPickerPresented = false`
- [X] T034 [US1] Update `ContentView` in `Velociraptor/VelociraptorApp.swift`: add `@ObservedObject var heartRateViewModel: HeartRateViewModel`; VStack order `SpeedView` (unchanged), `HeartRateView`, `LocationStatusView`, `Spacer`, then `Button(heartRateViewModel.buttonTitle) { heartRateViewModel.connectButtonTapped() }.buttonStyle(.bordered)` with identifier `heartRateMonitorButton`; `.sheet(isPresented: $heartRateViewModel.isPickerPresented, onDismiss: heartRateViewModel.pickerDismissed) { MonitorPickerView(viewModel: heartRateViewModel).presentationDetents([.medium, .large]) }`; `.alert` bound to `alertMessage` (title = the message, single OK button that sets it to nil)
- [X] T035 [US1] Update `VelociraptorApp` in `Velociraptor/VelociraptorApp.swift`: add `@StateObject private var heartRateViewModel` built in `init` from `HeartRateViewModel(service: BluetoothHeartRateService())`; pass it to `ContentView`; add `@Environment(\.scenePhase)` and `.onChange(of: scenePhase) { _, phase in if phase == .active { heartRateViewModel.sceneBecameActive() } }` on the `WindowGroup` content. Do not touch the existing `CLLocationManager().requestWhenInUseAuthorization()` call and do not create any Bluetooth object eagerly beyond the service (whose init respects C1)
- [X] T036 [US1] Update the `#Preview` in `Velociraptor/VelociraptorApp.swift`: add `final class PreviewHeartRateService: HeartRateMonitorProviding` (distinct name from the test `MockHeartRateService`) backed by subjects, with buttons in the preview's control VStack to cycle state none → connecting → connected (send bpm 142) → lost, and pass `HeartRateViewModel(service: previewService)` to `ContentView`
- [X] T037 [US1] Gate: run the commit gates (plus a visual check of the preview in portrait) and commit ("feat: heart rate UI and wiring")

**Checkpoint**: US1 is functional end to end; logic verified in Simulator tests, Bluetooth verified on device in Phase 5.

---

## Phase 4: User Story 2 - Speed Stays Usable Without a Monitor (Priority: P1)

**Goal**: Speed is shown, full size and updating, in every monitor/Bluetooth/permission state; with no monitor the only visible addition is the button.

**Independent Test**: Launch with no saved monitor, Bluetooth on and off: speed updates normally, no heart rate area, button "Connect heart rate monitor"; in landscape with heart rate shown, speed is not truncated or shrunk.

- [X] T038 [US2] In `VelociraptorTests/HeartRateViewModelTests.swift` add `speedUnaffectedByHeartRateStates` (FR-006, SC-004): create `OneValueModel(MockLocationProvider<Double>(initialValue: 0.0))` and a `HeartRateViewModel` over `MockHeartRateService`; cycle the mock through every `MonitorConnectionState`, every `BluetoothAvailability`, measurements and a failure, sending a new speed value after each step; `#expect(speed.displayValue == ...)` matches the last sent speed every time
- [X] T039 [US2] In `ContentView` in `Velociraptor/VelociraptorApp.swift` give the speed priority (R10, acceptance US2-2): apply `.fixedSize()` and `.layoutPriority(1)` to the `SpeedView(...)` call site (do **not** edit `Velociraptor/SpeedView.swift`); ensure the heart rate text is the only element that can scale (`.minimumScaleFactor` from T032) and that the button stays on screen
- [X] T040 [US2] Add a landscape preview in `Velociraptor/VelociraptorApp.swift` (`#Preview("Landscape, heart rate shown", traits: .landscapeLeft)`) with `PreviewHeartRateService` in `.connected` state showing a 3-digit bpm (e.g. 188) and speed "188.8"; verify speed is full size and untruncated and the button is visible. If it does not fit, switch `ContentView` to an `HStack` (readings | button) when `@Environment(\.verticalSizeClass) == .compact`, keeping speed at 120 pt
- [X] T041 [US2] Gate: run the commit gates (plus visual check of the portrait and landscape previews) and commit ("feat: keep speed display independent of heart rate")

**Checkpoint**: Both P1 stories complete.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T042 Verify accessibility identifiers in `Velociraptor/HeartRateView.swift` and `Velociraptor/VelociraptorApp.swift` match the UI contract table in `contracts/heart-rate-service.md` exactly (`heartRateValue`, `heartRateUnit`, `heartRateMonitorButton`, `monitorRow`, `monitorPickerMessage`, `openSettingsButton`)
- [X] T043 Run the feature tests from `specs/004-ble-heart-rate-monitor/quickstart.md` ("Automated checks", including `-only-testing VelociraptorTests/HeartRateConnectionMachineTests` and `VelociraptorTests/HeartRateMonitorProvidingTests`) and the full suite; all green
- [ ] T044 Manual device validation (plan Task 7): run all 15 scenarios in `specs/004-ble-heart-rate-monitor/quickstart.md` on a physical iPhone with a real monitor, in portrait and landscape; record pass/fail per scenario and file any fixes as follow-up tasks in this file

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — must finish first (test target must compile before any commit)
- **Foundational (Phase 2)**: depends on Phase 1 — blocks both stories
- **US1 (Phase 3)**: depends on Phase 2. Internal order: machine (T013–T019) → view model (T020–T025; only needs Phase 2, so can run parallel to the machine block) → adapter (T026–T031; needs the machine) → UI/wiring (T032–T037; needs view model + adapter)
- **US2 (Phase 4)**: depends on US1's UI (T034–T036), since it hardens the shared `ContentView` layout
- **Polish (Phase 5)**: after US1 and US2

### Mapping to plan Implementation Order

| Plan task | Tasks |
|---|---|
| 0 Repair test target | T001–T003 |
| 1 Measurement parser | T004–T005 (committed in T012) |
| 2 Service types + mock | T006–T012 |
| 3 Connection machine | T013–T019 |
| 4 View model | T020–T025, T038 |
| 5 Bluetooth adapter + Info.plist | T026–T031 |
| 6 Views + wiring + preview | T032–T037, T039–T041 |
| 7 Manual validation | T042–T044 |

### Within each block

- Tests are written before the implementation they cover and must fail first (T014–T017 before T018; T021–T023 before T024; T004 before T005)
- Each block ends in a Gate task; nothing is marked done before its reviewer approval

### Parallel Opportunities

- T001 ∥ T002 (different test files)
- T004 ∥ T005 (test file vs source file), and both ∥ T006–T009 (different files)
- T010 ∥ T011 once T006–T009 exist
- Machine block (T013–T018) ∥ view model block (T020–T024): different files, the view model only depends on Phase 2 types — but they are committed through separate gates
- T026 (pbxproj) ∥ T027–T030 (adapter source)

---

## Parallel Example: User Story 1

```bash
# After Phase 2, two independent streams:
Task: "Write HeartRateConnectionMachineTests in VelociraptorTests/HeartRateConnectionMachineTests.swift (T014–T017)"
Task: "Write HeartRateViewModelTests in VelociraptorTests/HeartRateViewModelTests.swift (T021–T023)"

# While writing the adapter:
Task: "Add NSBluetoothAlwaysUsageDescription in Velociraptor.xcodeproj/project.pbxproj (T026)"
Task: "Create BluetoothHeartRateService in Velociraptor/BluetoothHeartRateService.swift (T027)"
```

---

## Implementation Strategy

### MVP First

1. Phase 1 (green test target) → Phase 2 (types, parser, mock)
2. Phase 3 (US1) block by block, committing at each Gate
3. **Validate**: quickstart scenarios 1–13 on device
4. Phase 4 (US2) — small, but required before release since speed is the app's core function

### Incremental Delivery

Each Gate leaves the app shippable: until T034 the new code is unused by the UI, so the app behaves exactly as before; T034–T037 turn the feature on; T039–T041 harden layout.

---

## Notes

- `SpeedView.swift` stays unchanged throughout (plan)
- Scanning happens only while the picker sheet is open; no background Bluetooth mode
- Avoid committing the unrelated `IPHONEOS_DEPLOYMENT_TARGET = 16.6` working-tree change in `project.pbxproj` unless the user confirms it is intended
