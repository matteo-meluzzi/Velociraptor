# Contract: HeartRateMonitorProviding

The boundary between CoreBluetooth and the rest of the app. `BluetoothHeartRateService` implements it in the app; `MockHeartRateService` implements it in tests. All members are used on the main actor.

```swift
protocol HeartRateMonitorProviding: AnyObject {
    // Outputs
    var availability: AnyPublisher<BluetoothAvailability, Never> { get }      // current value replayed
    var connectionState: AnyPublisher<MonitorConnectionState, Never> { get }  // current value replayed
    var discoveredMonitors: AnyPublisher<[DiscoveredMonitor], Never> { get }  // sorted nearest first, pruned
    var measurements: AnyPublisher<HeartRateMeasurement, Never> { get }       // every parsed 0x2A37 value
    var connectionFailures: AnyPublisher<String, Never> { get }               // monitor name, user-initiated only

    // Commands
    func startScanning()          // creates the central if needed (may prompt for permission); scans once powered on
    func stopScanning()
    func connect(to monitorID: UUID)
    func reconnectIfNeeded()      // called at launch and when the scene becomes active
}
```

## Guarantees

| # | Guarantee |
|---|---|
| C1 | No `CBCentralManager` is created before the first `startScanning()` unless `CBManager.authorization == .allowedAlways` (FR-007). Before that, `availability` is `.notDetermined`. |
| C2 | `startScanning()` called while not powered on records the intent; scanning begins as soon as the state becomes `.poweredOn` (scenario 11). |
| C3 | `discoveredMonitors` contains only peripherals advertising service `0x180D`, sorted by RSSI desc, without entries unseen for > 5 s, **plus** the currently connected monitor (which no longer advertises) pinned first; scan results are cleared by `stopScanning()`. |
| C4 | `connect(to:)` disconnects any current/pending monitor first; at most one monitor is connected or pending (FR-003). |
| C5 | `connectionState` follows the transitions in [data-model.md](../data-model.md#transitions), as computed by `HeartRateConnectionMachine`; the service only maps callbacks to events and runs effects. Callbacks for peripherals other than the current target are ignored. |
| C6 | `connectionFailures` emits only for user-initiated connections that fail, time out (10 s), or are cut off by Bluetooth turning off; automatic attempts go to `.lost` silently. |
| C7 | The last monitor ID is written to `LastMonitorStoring` whenever the user selects a monitor (spec Key Entities). |
| C8 | `reconnectIfNeeded()` is idempotent: no-op when connected or a connect is already pending. Launch reconnection waits for the first `.poweredOn`. |
| C9 | Nothing here touches location services; speed display is independent (FR-006). |
| C10 | When availability leaves `.available`, a connected/lost/automatic state becomes `.lost` and reconnects on the next `.poweredOn`. |
| C11 | Timers (connect timeout, prune tick) use an injected scheduler/clock so tests never wait on real time. |

# Contract: Heart Rate Measurement bytes (0x2A37)

| Input bytes (hex) | Result |
|---|---|
| `00 48` | bpm 72, contact `.notSupported` |
| `01 48 00` | bpm 72 (UInt16) |
| `01 2C 01` | bpm 300 (UInt16) |
| `06 50` | bpm 80, contact `.detected` |
| `04 50` | bpm 80, contact `.notDetected` → invalid |
| `10 48 00 03` | bpm 72 (RR interval bytes ignored) |
| `00 00` | bpm 0 → invalid |
| `` (empty) / `00` / `01 48` | `nil` (too short) |

# Contract: UI (speed screen)

| Element | Accessibility identifier | Content |
|---|---|---|
| Heart rate value | `heartRateValue` | "Connecting…", digits, or "–"; absent in state None |
| Heart rate unit | `heartRateUnit` | "bpm" |
| Button | `heartRateMonitorButton` | "Connect heart rate monitor" / "Change heart rate monitor" |
| Picker row | `monitorRow` | monitor name |
| Picker message | `monitorPickerMessage` | "Searching…", "No heart rate monitors found", Bluetooth off/denied/unsupported text |
| Settings button | `openSettingsButton` | only when Bluetooth access is denied |
