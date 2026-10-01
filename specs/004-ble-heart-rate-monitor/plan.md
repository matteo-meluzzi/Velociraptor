# Implementation Plan: BLE Heart Rate Monitor

**Branch**: `004-ble-heart-rate-monitor` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-ble-heart-rate-monitor/spec.md`

## Summary

Add a "Connect heart rate monitor" button to the speed screen. Tapping it opens a sheet listing nearby standard BLE heart rate monitors (service `0x180D`), nearest first and updating live. Selecting one connects, subscribes to Heart Rate Measurement (`0x2A37`), and shows the heart rate in bpm under the speed. The last monitor is remembered and reconnected automatically at launch, after drops, and on return to the foreground. Bluetooth is wrapped behind a `HeartRateMonitorProviding` protocol (same pattern as `LocationProviding`). Connection decisions (timeouts, failure vs Lost, reconnects, Bluetooth on/off, stale callbacks) live in a pure, unit-tested `HeartRateConnectionMachine`; presentation lives in a unit-tested `HeartRateViewModel`; the byte parser is a pure, unit-tested function. `BluetoothHeartRateService` is a thin adapter. The speed view is untouched.

Before any feature work, the currently broken test target is repaired (see [research.md R11](research.md#r11-existing-test-target-does-not-compile)).

## Technical Context

**Language/Version**: Swift 5 language mode (project `SWIFT_VERSION = 5.0`), Xcode with iOS 18.2 SDK

**Primary Dependencies**: SwiftUI, Combine, CoreBluetooth, Foundation (`UserDefaults`) — system frameworks only

**Storage**: `UserDefaults`, two keys (`lastHeartRateMonitorID` UUID string, `lastHeartRateMonitorName`)

**Testing**: Swift Testing (`@Test`, `#expect`). `HeartRateConnectionMachine` tested event-by-event; `HeartRateViewModel` with `MockHeartRateService`; injected clocks/schedulers so no test waits on real time. CoreBluetooth itself is verified manually on device ([quickstart.md](quickstart.md)).

**Target Platform**: iOS 18.2+, iPhone (portrait + landscape)

**Project Type**: Native iOS app, single target (`fileSystemSynchronizedGroups`, so new files under `Velociraptor/` and `VelociraptorTests/` are picked up automatically)

**Performance Goals**: Monitor appears in list ≤ 5 s (SC-002); reading displayed ≤ 2 s after arrival (SC-003); "– bpm" ≤ 5 s after drop/stale (SC-005); auto-reconnect at launch ≤ 15 s (SC-006)

**Constraints**: No Bluetooth prompt at launch (FR-007); speed display never blocked, shrunk or truncated (FR-006, US2); no background Bluetooth mode; scanning only while the picker sheet is open

**Scale/Scope**: 5 new production files, 1 modified file, 1 build-setting change, 4 new test files, 1 repaired + 1 deleted test file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Build Integrity | PASS | Additive; build verified before every commit |
| II. Test Discipline | PASS (after Task 0) | Test target currently fails to compile (R11). Task 0 repairs it and is the first commit; new logic covered by `HeartRateMeasurementTests`, `HeartRateConnectionMachineTests` and `HeartRateViewModelTests` |
| III. Peer Review Before Commit | PASS | Reviewer agent on `git diff` before each commit |
| IV. Task Completion Gate | PASS | Each task closes only after reviewer sign-off |
| V. SwiftUI-First | PASS | UI is SwiftUI (`.sheet`, `List`, `openURL`). CoreBluetooth is a non-UI framework. `UIApplication.openSettingsURLString` is only a URL constant (no SwiftUI equivalent) |
| VI. Plan Review Gate | PASS | Reviewer agent returned **APPROVED** (round 2, 2026-10-01) after round 1 BLOCKED issues were fixed |

**Post-design re-check** (after plan review round 1): Design keeps all Bluetooth behind one protocol, moves every connection decision into a testable pure type, adds no dependencies, no UIKit views. No violations; Complexity Tracking not needed.

## Project Structure

### Documentation (this feature)

```text
specs/004-ble-heart-rate-monitor/
├── spec.md
├── plan.md                         # This file
├── research.md                     # Phase 0
├── data-model.md                   # Phase 1
├── quickstart.md                   # Phase 1
├── contracts/heart-rate-service.md # Phase 1
├── checklists/requirements.md
└── tasks.md                        # Phase 2 (/speckit-tasks — not created here)
```

### Source Code

```text
Velociraptor/
├── HeartRateMeasurement.swift      # NEW: HeartRateMeasurement, SensorContact, parse(_:)
├── HeartRateMonitorProviding.swift # NEW: protocol, MonitorConnectionState, BluetoothAvailability,
│                                   #      DiscoveredMonitor, LastMonitorStoring + UserDefaults store
├── HeartRateConnectionMachine.swift # NEW: pure state machine (ConnectionEvent → state + [ConnectionEffect])
├── BluetoothHeartRateService.swift # NEW: thin CoreBluetooth adapter (delegates → events, effects → CB calls)
├── HeartRateView.swift             # NEW: HeartRateViewModel, HeartRateView, MonitorPickerView
├── VelociraptorApp.swift           # MODIFY: wire service + view model, button, sheet, scenePhase, preview
└── SpeedView.swift                 # unchanged (US2)

Velociraptor.xcodeproj/project.pbxproj  # MODIFY: INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription (Debug + Release)

VelociraptorTests/
├── SpeedViewModelTests.swift       # REPAIR: test OneValueModel / displayValue
├── AltitudeViewModelTests.swift    # DELETE: feature removed
├── MockHeartRateService.swift      # NEW: mock + InMemoryLastMonitorStore
├── HeartRateMeasurementTests.swift # NEW: byte-level parse tests (contract table)
├── HeartRateConnectionMachineTests.swift # NEW: one test per Transitions row + C4/C6/C7/C8/C10
└── HeartRateViewModelTests.swift   # NEW: Monitor States table, picker, failures, staleness
```

**Structure Decision**: Keep the existing flat layout of `Velociraptor/` and `VelociraptorTests/`; one file per concern, matching `LocationPublisher.swift` / `SpeedView.swift`.

## Design

### Data flow

```text
CBCentralManager / CBPeripheral
        │ delegate callbacks (main queue)
        ▼
BluetoothHeartRateService : HeartRateMonitorProviding  ── LastMonitorStoring (UserDefaults)
        │   events ⇄ effects
        │   HeartRateConnectionMachine (pure; owns MonitorConnectionState)
        │ Combine publishers (availability, connectionState, discoveredMonitors, measurements, connectionFailures)
        ▼
HeartRateViewModel (@MainActor ObservableObject, injected `now`, 1 s refresh timer)
        │ @Published heartRateText / showsUnit / buttonTitle / monitors / pickerMessage / alertMessage
        ▼
ContentView ─ SpeedView (unchanged)
            ─ HeartRateView
            ─ LocationStatusView
            ─ Button → .sheet(MonitorPickerView)
```

### Key decisions (details in [research.md](research.md))

- **Permission**: central created lazily on first `startScanning()` unless `CBManager.authorization == .allowedAlways` (R3). `ShowPowerAlert` disabled; the app shows its own message.
- **Scanning**: service-filtered, allow-duplicates, only while the sheet is open; 5 s prune; RSSI-desc sort (R5).
- **Connecting**: full sequence connect → discover 180D → discover 2A37 → notify on; 10 s timeout. User-initiated failure → None + message; automatic failure → Lost with a pending `connect` that never times out (R6).
- **Reconnect**: on disconnect, at launch (after first `.poweredOn`), on `scenePhase == .active`, on Bluetooth powered on (R6).
- **Bluetooth off/reset while in use**: Connected/Lost/automatic → Lost, re-retrieve on power-on; user connect in progress → None + message (R6).
- **Switching**: callbacks for a non-target peripheral are ignored, so cancelling the old monitor never resurrects it (R6, FR-003). Picking the already-connected monitor just closes the sheet.
- **Last monitor**: saved whenever the user selects one (spec Key Entities).
- **Valid/stale**: `bpm > 0`, contact not lost, ≤ 5 s old; reading cleared on invalid measurement and when leaving Connected; 1 s re-evaluation with injected clock (R7).
- **Layout**: heart rate below speed, smaller font; speed keeps layout priority; nothing reserved when hidden (R10).

### Messages (user-facing text)

| Situation | Where | Text |
|---|---|---|
| Scanning, nothing yet (first 5 s), or Bluetooth still starting / permission prompt up | sheet | "Searching for heart rate monitors…" |
| Scanning, still nothing after 5 s | sheet | "No heart rate monitors found" |
| Bluetooth off | sheet | "Turn on Bluetooth to connect a heart rate monitor" |
| Bluetooth denied | sheet | "Velociraptor needs Bluetooth access to connect a heart rate monitor" + "Open Settings" |
| Bluetooth unsupported | sheet | "Bluetooth is not available on this device" |
| User connect failed | alert | "Couldn't connect to `<name>`" |

## Implementation Order

| # | Task | Depends on |
|---|---|---|
| 0 | Repair test target (R11): rewrite `SpeedViewModelTests` for `OneValueModel`, delete `AltitudeViewModelTests`; build + test green; commit | — |
| 1 | `HeartRateMeasurement` + `HeartRateMeasurementTests` (contract byte table) | 0 |
| 2 | `HeartRateMonitorProviding.swift` types + `UserDefaultsLastMonitorStore`; `MockHeartRateService` | 0 |
| 3 | `HeartRateConnectionMachine` + `HeartRateConnectionMachineTests` (every Transitions row; scenarios 2, 3, 6, 7, 10; C4, C6–C8, C10) | 2 |
| 4 | `HeartRateViewModel` + `HeartRateViewModelTests` (Monitor States table, picker messages incl. Searching→None found, staleness, reading cleared on invalid/state change, scenarios 1, 4, 5, 8, 9, 11; US2 independence) | 1, 2 |
| 5 | `BluetoothHeartRateService` (adapter over the machine; contract C1–C11) + Info.plist key | 1, 2, 3 |
| 6 | `HeartRateView`, `MonitorPickerView`, `ContentView`/`VelociraptorApp` wiring, scenePhase hook, preview with mock; check landscape fit | 4, 5 |
| 7 | Manual device validation per [quickstart.md](quickstart.md) | 6 |

Each task ends with build → test → reviewer sign-off → commit (Constitution I–IV).

## Risks

- **No device in CI**: CoreBluetooth calls are only manually verifiable; mitigated by keeping `BluetoothHeartRateService` a thin adapter and putting every decision in the tested state machine, view model and parser.
- **Lost-state battery cost**: a pending `connect` is handled by the Bluetooth controller and is low cost; no polling timers while Lost.
- **Landscape height**: speed (120 pt) + heart rate + status + button must fit ~390 pt without pushing the button off-screen; heart rate text may scale down (or the layout may place the button beside the readings in landscape), speed may not be truncated. Verified in Task 6 previews in landscape.

## Complexity Tracking

No constitution violations; nothing to justify.
