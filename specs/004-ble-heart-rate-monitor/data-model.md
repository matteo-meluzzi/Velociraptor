# Data Model: BLE Heart Rate Monitor

**Feature**: 004-ble-heart-rate-monitor | **Date**: 2026-10-01

All types are in-memory except `LastMonitorStoring`, which persists one UUID.

---

## DiscoveredMonitor

A heart rate monitor seen while scanning (one row in the picker).

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `CBPeripheral.identifier`; `Identifiable` |
| `name` | `String` | Advertised local name → `peripheral.name` → "Unnamed heart rate monitor" |
| `rssi` | `Int` | Latest RSSI in dBm; `127` means unavailable |
| `lastSeen` | `Date` | Time of the last advertisement |

**Rules**: Removed from the list when `now − lastSeen > 5 s`. Sorted by `rssi` descending (`127` last). Duplicate names are allowed; identity is `id`.

## HeartRateMeasurement

Parsed payload of characteristic `0x2A37`.

| Field | Type | Notes |
|---|---|---|
| `bpm` | `Int` | From UInt8 or UInt16 (flags bit 0) |
| `contact` | `SensorContact` | `.detected`, `.notDetected`, `.notSupported` (flags bits 1–2) |

- `static func parse(_ data: Data) -> HeartRateMeasurement?` returns `nil` for an empty or too-short payload.
- `var isValid: Bool { bpm > 0 && contact != .notDetected }`

## HeartRateReading

Last valid measurement held by the view model.

| Field | Type | Notes |
|---|---|---|
| `bpm` | `Int` | > 0 |
| `receivedAt` | `Date` | Arrival time (from injected clock) |

**Rules**: Displayed only while `now − receivedAt ≤ 5 s`. Cleared when an invalid measurement arrives and whenever the state leaves Connected.

## MonitorConnectionState

State published by the service; drives the Monitor States table in the spec.

```text
enum MonitorConnectionState: Equatable {
    case none
    case connecting(monitorID: UUID, name: String, origin: ConnectOrigin)  // .user or .automatic
    case connected(monitorID: UUID, name: String)
    case lost(monitorID: UUID, name: String)
}
```

### Transitions

| From | Event | To | Side effect |
|---|---|---|---|
| none | user selects M | connecting(M, .user) | save M as last monitor; `connect(M)`; start 10 s timeout |
| any non-none on M | user selects M′ ≠ M | connecting(M′, .user) | cancel M; save M′; `connect(M′)`; start timeout |
| connected(M) | user selects M | unchanged | none (sheet just closes) |
| lost(M) / connecting(M, .automatic) | user selects M | connecting(M, .user) | cancel pending; `connect(M)`; start timeout |
| connecting(.automatic) / lost | `retrievePeripherals` empty (reported as `didFail`) | lost | retried on next foreground / power-on |
| none (launch, stored M) | first `.poweredOn` | connecting(M, .automatic) | retrieve + `connect(M)`; start timeout |
| connecting(.user) | subscribed to 0x2A37 | connected | cancel timeout |
| connecting(.user) | fail / discovery fail / 10 s timeout | none | cancel; emit `connectionFailed(name)` |
| connecting(.user) | availability leaves `.available` | none | emit `connectionFailed(name)` |
| connecting(.automatic) | connected + subscribed | connected | — |
| connecting(.automatic) | fail / discovery fail / 10 s timeout | lost | cancel, then pending `connect` |
| connected | disconnect | lost | `connect(M)` again (pending) |
| lost | connected + subscribed | connected | — |
| lost / connecting(.automatic) | app becomes active, no pending connect | unchanged | re-issue `connect` (re-retrieve if needed) |
| connected / lost / connecting(.automatic) | availability leaves `.available` | lost | drop peripheral reference + pending flag |
| lost / connecting(.automatic) | Bluetooth powered on | unchanged | re-retrieve by ID + `connect` |
| any | callback for a peripheral that is not the current target | unchanged | ignored |

## BluetoothAvailability

```text
enum BluetoothAvailability: Equatable {
    case notDetermined   // central not yet created (permission never asked)
    case pending         // .unknown / .resetting
    case available       // .poweredOn
    case poweredOff
    case denied          // .unauthorized
    case unsupported     // .unsupported (e.g. Simulator)
}
```

## LastMonitorStoring

```text
protocol LastMonitorStoring: AnyObject {
    var lastMonitorID: UUID? { get set }
    var lastMonitorName: String? { get set }   // used for the state's name at launch
}
```

- `UserDefaultsLastMonitorStore` — keys `lastHeartRateMonitorID` (UUID string) and `lastHeartRateMonitorName`.
- `InMemoryLastMonitorStore` — tests.
- Written whenever the user selects a monitor (spec Key Entities: "replaced whenever the user selects another"), even if that connection then fails; the next launch then tries the newly selected monitor.

## HeartRateConnectionMachine

Pure value type that owns `MonitorConnectionState` and implements the Transitions table above. No CoreBluetooth imports.

```text
struct HeartRateConnectionMachine {
    private(set) var state: MonitorConnectionState
    private(set) var availability: BluetoothAvailability
    mutating func handle(_ event: ConnectionEvent) -> [ConnectionEffect]
}
```

Events and effects are listed in [research.md R9](research.md#r9-architecture-fit).

## HeartRateViewModel (presentation state)

| Output | Type | Derived from |
|---|---|---|
| `heartRateText` | `String?` | `nil` (hidden) for none; "Connecting…"; "`<bpm>`" with valid fresh reading; "–" otherwise |
| `showsUnit` | `Bool` | true for connected/lost |
| `buttonTitle` | `String` | "Connect heart rate monitor" for none; "Change heart rate monitor" otherwise |
| `isPickerPresented` | `Bool` | button tap / selection / dismiss |
| `monitors` | `[DiscoveredMonitor]` | service list, sorted, pruned |
| `pickerMessage` | `PickerMessage?` | `.searching` (also while availability is `.notDetermined`/`.pending`), `.noneFound`, `.bluetoothOff`, `.bluetoothDenied`, `.bluetoothUnsupported` |
| `alertMessage` | `String?` | "Couldn't connect to `<name>`" on user-connect failure |
