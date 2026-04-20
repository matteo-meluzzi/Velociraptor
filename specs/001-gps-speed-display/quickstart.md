# Quickstart: GPS Speed Display

## Prerequisites

- Xcode 16+ with iOS 18.2 simulator (iPhone 16)
- No external package managers needed

## Build & run

```bash
# Build
xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Test
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Implementation sequence

The feature is built in two phases — UI first, GPS second.

### Phase A: Static UI (no GPS)

1. Replace `ContentView.swift` with a pass-through to `SpeedView`.
2. Create `SpeedView.swift` — large speed number, unit label, unit toggle button.
3. Drive with hardcoded `@State var speed: Double = 42.0`.
4. Verify in Xcode Previews and simulator (no location needed).

### Phase B: GPS integration

5. Add `NSLocationWhenInUseUsageDescription` to `Info.plist`.
6. Create `LocationProviding` protocol.
7. Create `LocationManager` conforming to `LocationProviding` + `CLLocationManagerDelegate`.
8. Create `SpeedViewModel` — converts m/s → display string, owns `LocationManager`.
9. Inject `SpeedViewModel` into `SpeedView` via `@StateObject`.
10. Remove hardcoded speed; bind UI to `viewModel.displaySpeed` and `viewModel.unit`.
11. Test on a physical device or use Xcode's simulated location (GPX route).

## Simulating GPS speed in Simulator

In Xcode: Product → Scheme → Run → Options → Core Location: set Custom Location, then use a GPX file to simulate movement.

Example GPX snippet for ~50 km/h:

```xml
<?xml version="1.0"?>
<gpx version="1.1">
  <trk><trkseg>
    <trkpt lat="45.4654" lon="9.1859"><time>2026-04-20T10:00:00Z</time></trkpt>
    <trkpt lat="45.4700" lon="9.1900"><time>2026-04-20T10:00:04Z</time></trkpt>
  </trkseg></trk>
</gpx>
```

## Testing

- **Unit tests** (`SpeedViewModelTests`): test `SpeedUnit.convert`, display string formatting, "– –" for unavailable speed.
- **UI tests** (`SpeedDisplayUITests`): verify speed label is visible, unit toggle button exists and switches label.
