# Research: BLE Heart Rate Monitor

**Feature**: 004-ble-heart-rate-monitor | **Date**: 2026-10-01

Each section records a decision, why it was chosen, and what else was considered. No NEEDS CLARIFICATION items remain.

---

## R1. Bluetooth framework

- **Decision**: CoreBluetooth `CBCentralManager` with `queue: nil`, so delegate callbacks arrive on the main queue.
- **Rationale**: System framework, no dependencies (project rule). Main-queue callbacks let the service talk to the `@MainActor` view model without hops. At ~1 Hz heart rate notifications, main-queue cost is negligible.
- **Alternatives**: a background dispatch queue (adds thread hops for no gain at this data rate); AccessorySetupKit (iOS 18; system picker UI, but does not support live nearest-first lists with our own empty-state messaging, and needs extra Info.plist declarations — overkill).

## R2. Heart rate GATT profile

- **Decision**: Scan for Heart Rate Service `0x180D`; subscribe (notify) to Heart Rate Measurement characteristic `0x2A37`. Ignore Body Sensor Location (`0x2A38`) and Heart Rate Control Point (`0x2A39`).
- **Parsing of 0x2A37** (byte 0 = flags):
  - bit 0: 0 → heart rate is `UInt8` at byte 1; 1 → `UInt16` little-endian at bytes 1–2
  - bits 1–2: sensor contact status. `0b11` (supported + detected) → contact; `0b10` (supported, not detected) → **lost contact**; `0b00`/`0b01` → not supported, treat as contact OK
  - bits 3–4 (energy expended, RR intervals): ignored; only the heart rate field is read
  - Payload too short for the declared format → reading discarded (no crash)
- **Rationale**: Standard Bluetooth SIG profile; covers every common chest strap and armband. Scanning by service UUID guarantees FR-002 ("only heart rate monitors").
- **Alternatives**: scanning everything and filtering by name (unreliable, violates FR-002).

## R3. When the Bluetooth permission prompt appears (FR-007)

- **Decision**: Do not create `CBCentralManager` at launch unless `CBManager.authorization == .allowedAlways` (a class property, readable without triggering the prompt). Otherwise create it lazily on the first "Connect heart rate monitor" tap.
- **Rationale**: Instantiating `CBCentralManager` is what triggers the system prompt. Lazy creation keeps the prompt off launch.
- **Also**: pass `CBCentralManagerOptionShowPowerAlertKey: false` so iOS does not show its own "Turn on Bluetooth" alert at launch; the app shows its own message instead (FR-005, scenario 11).
- **Info.plist**: add `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` to the app target's build settings (Debug + Release), alongside the existing location key.

## R4. Bluetooth off / denied (scenario 11)

- **Decision**: Map `CBManagerState` to an availability value: `.poweredOn` → available; `.poweredOff` → off; `.unauthorized` → denied; `.unsupported` → unsupported (Simulator); `.unknown`/`.resetting` → pending. The picker sheet shows a message for off/denied/unsupported, with a Settings button when denied (`UIApplication.openSettingsURLString` via SwiftUI `openURL`). When state becomes `.poweredOn` while the sheet is open, scanning starts automatically.
- **Rationale**: The sheet stays open and reacts to `centralManagerDidUpdateState`, which satisfies "if Bluetooth is turned on while the message is shown, the search starts".
- **Alternatives**: a separate alert (cannot transition into the list without re-tapping).

## R5. Live, nearest-first device list (FR-002, SC-002)

- **Decision**: `scanForPeripherals(withServices: [0x180D], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])` while the sheet is open; stop scanning when it closes. Each advertisement updates that device's RSSI and `lastSeen`. A 1-second timer removes devices not seen for 5 seconds. List sorted by RSSI descending (nearest first; RSSI `127` = unavailable, sorted last).
- **Rationale**: Allow-duplicates is needed to get continuous RSSI and to detect disappearance; it is only enabled while the sheet is foregrounded, so battery cost is bounded.
- **Name**: `CBAdvertisementDataLocalNameKey`, else `peripheral.name`, else "Unnamed heart rate monitor".
- **Already-connected device**: a monitor connected to this app is no longer advertising; it is shown at the top of the list from the current connection, so the user can see what is connected.
- **"No monitors found"**: shown when scanning has been running and the list is empty ("Searching…" for the first 5 s, then "No heart rate monitors found" while still scanning). While availability is `.notDetermined`/`.pending` (permission prompt up, Bluetooth starting) the sheet also shows "Searching…".
- **Selecting the already-connected monitor** just closes the sheet; it does not cancel and reconnect.
- **Timers are injectable**: the 1 s prune tick and the 5 s "Searching…" → "No monitors found" switch use an injected clock and are driven by a `tick()` call in tests.

## R6. Connection, failure, reconnect (scenarios 2, 3, 6, 10; edge case background)

- **Decision**:
  - **User selection**: `connect(peripheral)` → state Connecting. A 10-second timeout, `didFailToConnect`, or failed service discovery → cancel, state None, show "Couldn't connect to <name>". The previous monitor (if any) is disconnected before connecting the new one; the stored identifier and name are saved when the user selects the monitor (spec Key Entities).
  - **Launch / auto-reconnect**: `retrievePeripherals(withIdentifiers: [stored])` then `connect`. State Connecting; after 10 s without success → state Lost, and the pending `connect` is left in place (CoreBluetooth `connect` never times out, so it acts as an indefinite retry with no polling).
  - **Drop while connected** (`didDisconnectPeripheral`): state Lost, immediately call `connect` again (pending until the device returns).
  - **Return to foreground** (`scenePhase == .active`): if the state is Lost or Connecting and no pending connect exists, re-issue `connect`. If the system invalidated the peripheral, re-retrieve by identifier.
  - **Stored peripheral cannot be retrieved** (`retrievePeripherals` returns empty, e.g. device forgotten): state Lost; reconnect is retried on every foreground and every `.poweredOn` transition. (Matches spec: "Lost if it isn't available".)
  - **Launch is deferred until `.poweredOn`**: `connect` while the central is `.unknown` is a no-op, so the launch `retrievePeripherals`/`connect` runs on the first `.poweredOn` callback.
  - **Bluetooth leaves `.poweredOn`** (off, resetting, unauthorized): iOS cancels all connections and pending connects and invalidates `CBPeripheral` objects; `didDisconnectPeripheral` is not reliably delivered. So: `connected`/`lost`/`connecting(.automatic)` → `lost` (drop peripheral references and pending flag); `connecting(.user)` → `none` with a failure message. When `.poweredOn` returns, Lost/automatic states re-retrieve by identifier and `connect` again.
  - **Connect sequence**: `connect` → `didConnect` → `discoverServices([180D])` → `discoverCharacteristics([2A37])` → `setNotifyValue(true)` → `didUpdateNotificationStateFor` (no error) → **connected**. Discovery/subscription failure counts as a connect failure (user: None + message; automatic: cancel, then pending `connect` → Lost).
  - **Strong reference**: the target `CBPeripheral` is held from `connect` until it is replaced or disconnected, otherwise it can be deallocated and the connect silently cancelled.
  - **Stale callbacks**: any disconnect, failure or notification whose peripheral identifier is not the current target is ignored (e.g. the `didDisconnect` caused by cancelling the previous monitor when switching), so the old monitor is never resurrected (FR-003).
  - **Retrieval returns nothing**: the adapter reports it as `didFail(id)` (automatic → Lost; user → None + message).
  - **Saved monitor but permission not yet granted at launch**: nothing happens at launch (FR-007); the first `.poweredOn` after the user's first tap also runs the launch reconnection to the saved monitor. Intentional and covered by machine tests.
- **Where the logic lives**: all of the above decisions are made by a pure `HeartRateConnectionMachine` (events in → new state + effects out, see R9); `BluetoothHeartRateService` only translates delegate callbacks into events and executes effects.
- **Rationale**: A pending `connect` is Apple's recommended reconnection pattern; cheap, no timers, survives the device leaving and returning.
- **Alternatives**: iOS 17 `CBConnectPeripheralOptionEnableAutoReconnect` (system reconnects after drops); rejected because it still needs our own handling for launch and foreground cases, and behaviour is harder to unit-test. Background mode `bluetooth-central`: out of scope (spec says the connection need not be kept in background).

## R7. Valid reading and staleness (SC-005)

- **Decision**: A reading is valid if `bpm > 0` and contact is not reported lost. The view model stores the last valid reading with its arrival time. The stored reading is **cleared** when an invalid measurement arrives (so "– bpm" shows at once) and on any state change away from Connected (so a previous monitor's value can never appear as the new one's). Display shows the value if `now − arrival ≤ 5 s`, otherwise "– bpm". A 1-second timer in the view model re-evaluates (only while state is Connected). Invalid readings (0 bpm, lost contact) immediately show "– bpm".
- **Testability**: the view model takes an injected `now: () -> Date` closure and exposes `refresh()`; tests drive time without waiting.
- **Alternatives**: SwiftUI `TimelineView` (moves logic into the view, not unit-testable).

## R8. Persisting the last monitor (FR-008)

- **Decision**: `UserDefaults` key `lastHeartRateMonitorID` storing `peripheral.identifier.uuidString` (plus `lastHeartRateMonitorName` for the display name at launch), behind a small `LastMonitorStoring` protocol so tests use an in-memory store.
- **Rationale**: A single UUID; `UserDefaults` is the simplest correct store. Peripheral identifiers are stable per device on this phone.
- **Alternatives**: SwiftData/files (overkill).

## R9. Architecture fit

- **Decision**: Follow the existing pattern (protocol-wrapped system service exposing Combine publishers → `@MainActor ObservableObject` view model → SwiftUI view), with the connection state machine pulled out as a pure type:
  - `HeartRateConnectionMachine`: a CoreBluetooth-free value type. `mutating func handle(_ event: ConnectionEvent) -> [ConnectionEffect]`. Events: `launch(storedID)`, `userSelected(id, name)`, `didConnect(id)`, `subscribed(id)`, `didFail(id)`, `didDisconnect(id)`, `timeoutFired(id)`, `availabilityChanged(BluetoothAvailability)`, `sceneActive`. Effects: `retrieveAndConnect(id)`, `connect(id)`, `cancel(id)`, `startTimeout(id)`, `cancelTimeout`, `saveLastMonitor(id)`, `emitFailure(name)`. Fully unit-tested, one test per Transitions row.
  - `HeartRateMonitorProviding` protocol (publishers + commands), real `BluetoothHeartRateService` (thin adapter: callbacks → events, effects → CoreBluetooth calls; timeout via injected scheduler), `MockHeartRateService` in tests.
  - `HeartRateMeasurement.parse(_ data: Data)` is a pure function, tested directly with byte arrays.
  - `HeartRateViewModel` owns all state-table logic (button label, heart rate text, messages).
- **Rationale**: CoreBluetooth cannot be exercised in the Simulator; putting all logic behind the protocol keeps it unit-testable. Matches `LocationProviding`/`AuthorizationProviding`.

## R10. Layout (FR-004, US2)

- **Decision**: `ContentView` VStack: `SpeedView` (unchanged), then `HeartRateView` (value at ~56 pt thin rounded monospaced + "bpm" in `.title3` secondary, same baseline style as speed), then `LocationStatusView`, then the button (`.bordered`) near the bottom. Picker shown in a `.sheet` with `.presentationDetents([.medium, .large])`.
- **Speed never shrinks**: the heart rate view is a sibling below the speed; `SpeedView` gets `.fixedSize()` / `.layoutPriority(1)` and the heart rate text uses `.minimumScaleFactor` so in tight landscape only the heart rate can scale. The hidden state uses no placeholder space, so the no-monitor layout matches today's (US2).
- **Alternatives**: overlay/ZStack (risks overlapping speed in landscape).

## R11. Existing test target does not compile

- **Finding**: `xcodebuild build-for-testing` currently fails: `SpeedViewModelTests.swift` uses `SpeedModel`/`displaySpeed` and `AltitudeViewModelTests.swift` uses `AltitudeViewModel`, both removed by the earlier refactor (now `OneValueModel`/`displayValue`; altitude removed). Also `MockLocationProvider`/`MockAuthorizationProvider` are declared in the app target's `VelociraptorApp.swift` (for the preview) as well as in the test target.
- **Decision**: Task 0 of this feature repairs the test target: rewrite `SpeedViewModelTests` against `OneValueModel` (with `MockLocationProvider<Double>`) and delete `AltitudeViewModelTests.swift`. The duplicated preview mocks in the app target are harmless (the test module's own types shadow imported ones) and are left as is.
- **Rationale**: Constitution Principle II requires `xcodebuild test` to pass before any commit; without this no commit for this feature is possible.
