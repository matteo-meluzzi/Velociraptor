# Quickstart: BLE Heart Rate Monitor

How to verify the feature end to end. Interfaces: [contracts/heart-rate-service.md](contracts/heart-rate-service.md). States: [data-model.md](data-model.md).

## Prerequisites

- Xcode with the iOS 18.2+ SDK; iPhone 16 simulator for build/tests
- For manual checks: a physical iPhone and a standard BLE heart rate monitor (chest strap or armband), worn so it transmits. Bluetooth does not work in the Simulator.

## Automated checks

```bash
xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test  -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Feature tests only
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing VelociraptorTests/HeartRateMeasurementTests \
  -only-testing VelociraptorTests/HeartRateViewModelTests
```

Expected: build succeeds; all tests pass, including the repaired `SpeedViewModelTests`.

## Manual scenarios (physical device)

| # | Steps | Expected |
|---|---|---|
| 1 | Fresh install, launch | Location prompt only; **no** Bluetooth prompt; speed shown; button "Connect heart rate monitor"; no heart rate area |
| 2 | Tap the button | Bluetooth prompt appears; after Allow, sheet lists the monitor by name within 5 s (SC-002) |
| 3 | Move a second monitor closer / switch one off | List reorders nearest first; switched-off monitor disappears within ~5 s |
| 4 | Pick the monitor | Sheet closes; "Connecting…" then value + "bpm" under the speed within 15 s total (SC-001); updates each beat (SC-003) |
| 5 | Remove the strap from the skin | "– bpm" within 5 s (SC-005) |
| 6 | Switch the monitor off | "– bpm"; switch it on again → value returns with no taps |
| 7 | Force-quit and relaunch with the monitor on | "Connecting…" then heart rate with no taps within 15 s (SC-006) |
| 8 | Relaunch with the monitor off | "Connecting…" then "– bpm" (Lost); switch it on → value returns |
| 9 | Tap "Change heart rate monitor", dismiss the sheet | Nothing changes |
| 10 | Turn Bluetooth off in Control Center, tap the button | Message that Bluetooth is needed; turn it on → list starts filling |
| 11 | Deny Bluetooth in Settings, tap the button | Message with a Settings button that opens the app's settings |
| 12 | No monitors around, tap the button | "Searching…", then "No heart rate monitors found" |
| 13 | Pick a monitor, switch it off before it connects | After ~10 s: "Couldn't connect" message; state None (button "Connect heart rate monitor") |
| 14 | During all of the above, while moving | Speed is always visible, full size, and updating (SC-004); also in landscape |
| 15 | Lock the screen 1 min with monitor on, unlock | Heart rate returns automatically (reconnects if it dropped) |
