# Research: GPS Speed Display

## 1. CoreLocation speed API

**Decision**: Use `CLLocation.speed` (in m/s) delivered via `CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)`.

**Rationale**: `CLLocation.speed` is the canonical, documented property for device speed on iOS. It returns –1 when speed is unavailable (GPS not locked, indoors, or device stationary below threshold). No third-party library is needed.

**Alternatives considered**:
- `CLLocationUpdate` (new iOS 17 async/await API via `CLLocationUpdate.liveUpdates()`) — more modern but adds complexity with structured concurrency in an otherwise simple delegate flow. Not worth the overhead for a single-screen app. Could migrate later.

**Key facts**:
- Speed unit: metres per second (m/s). Display in km/h only (× 3.6).
- `speedAccuracy` (m/s): negative means invalid. Always check `speed >= 0` before displaying.
- `CLLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation` gives the best GPS fix for speed.
- `CLLocationManager.activityType = .automotiveNavigation` optimises power for vehicle-speed scenarios.

## 2. Location permissions (iOS 18)

**Decision**: Request `WhenInUse` authorization via `requestWhenInUseAuthorization()`.

**Rationale**: The app only needs location while foregrounded. `Always` authorization would trigger an App Store review question and is unnecessary.

**Required Info.plist key**: `NSLocationWhenInUseUsageDescription` — must be present or the app crashes on `requestWhenInUseAuthorization()`.

**Authorization flow**: Check `authorizationStatus` in `locationManagerDidChangeAuthorization(_:)`. Handle `.notDetermined`, `.authorizedWhenInUse`, `.denied`, `.restricted`.

## 3. ObservableObject + CLLocationManagerDelegate bridging

**Decision**: `LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject` with `@Published var speed: Double` (m/s, –1 = unavailable).

**Rationale**: `CLLocationManagerDelegate` is an ObjC protocol — must be adopted by an `NSObject` subclass. Wrapping it in an `ObservableObject` lets SwiftUI views subscribe cleanly via `@StateObject` / `@ObservedObject`.

**Alternatives considered**:
- Combine `PassthroughSubject` + manual `sink` — more boilerplate, no benefit over `@Published` here.
- Swift concurrency `AsyncStream` — cleaner long-term but overkill for this scope.

## 4. Unit conversion & display

**Decision**: `SpeedViewModel` converts raw m/s → km/h (× 3.6) and formats as a display string. km/h is the only unit.

**Rationale**: Keeps LocationManager pure (always m/s) and testable. A single unit removes toggle complexity.

**Display precision**: Always 1 decimal place (e.g. "87.4", "3.2"). Shows "– –" when speed < 0 (GPS unavailable).

## 5. UI-first sequencing

**Decision**: Implement `SpeedView` with a hardcoded `@State var speed: Double = 42.0` first, wire `LocationManager` only after UI is approved.

**Rationale**: Matches user's stated requirement. Allows UI iteration in Previews without needing a physical device or simulator location injection.

**Alternatives considered**: None — this is an explicit project requirement.

## 6. Testing strategy

**Decision**: Unit-test `SpeedViewModel` for conversion math and state transitions (no GPS needed). UI-test the visible label and unit toggle.

**Rationale**: `CLLocationManager` cannot be meaningfully unit-tested in CI without a simulator location injection — testing the ViewModel's pure logic is sufficient and reliable.

**Mock approach**: Protocol-abstract `LocationProviding` so `SpeedViewModel` can be injected with a fake in tests without touching `CLLocationManager` directly.

## Resolved clarifications

| Item | Resolution |
|------|-----------|
| Speed unit | km/h only — mph removed |
| Accuracy display | No — speed only, no accuracy indicator in V1 |
| Background updates | No — WhenInUse only |
| Map or route | No — speed display only, no map in V1 |
| Landscape support | Standard SwiftUI adaptive layout handles it automatically |
