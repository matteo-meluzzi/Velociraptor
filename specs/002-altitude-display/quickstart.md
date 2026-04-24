# Quickstart: Testing Altitude Display

**Feature**: 002-altitude-display

## Build & Run

```bash
# Build
xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Run altitude-specific tests only
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing VelociraptorTests/SpeedViewModelTests
```

## Verifying the Feature

### On Simulator

1. Launch the app on the iPhone 16 simulator.
2. The speed screen shows `"– m"` below `"km/h"` (no real GPS on simulator).
3. Use **Features → Location → Custom Location…** in the simulator to inject a GPS fix.
4. The altitude row updates to reflect the injected altitude in meters (e.g., `"52 m"`).

### On Device

1. Build and run on a physical iPhone.
2. Step outside or open a window for GPS signal.
3. The altitude value below `"km/h"` updates in real time as you move or elevation changes.
4. Confirm the altitude font is visibly smaller than the speed digits.
5. Confirm the "m" unit is always present.

## Acceptance Checklist

- [ ] Altitude value appears directly below the `"km/h"` unit label
- [ ] Altitude text is smaller than the speed digits
- [ ] Unit label is always `"m"` — not editable
- [ ] Shows `"– m"` when no GPS fix is available
- [ ] Shows negative values when below sea level (test via injected location)
- [ ] Updates within the same cycle as the speed reading
