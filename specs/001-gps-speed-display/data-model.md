# Data Model: GPS Speed Display

## Entities

### SpeedViewModel (ObservableObject)

```swift
@MainActor
final class SpeedViewModel: ObservableObject {
    @Published var displaySpeed: String      // e.g. "87" or "3.2" or "– –"
    @Published var isLocationAvailable: Bool // false when GPS not locked

    private let locationProvider: LocationProviding
}
```

**Responsibilities**:
- Subscribes to `LocationProviding.speedPublisher` (m/s).
- Converts raw m/s → km/h (× 3.6) → display string.
- Formats: always 1 decimal place (e.g. "87.4", "3.2"), "– –" if raw speed < 0.

**State transitions**:

```
.notDetermined ──request──► .authorizedWhenInUse ──startUpdating──► receiving updates
                                                                         │
                         .denied ◄──── user denies ────────────────────┘
```

---

### LocationManager (NSObject, CLLocationManagerDelegate, LocationProviding)

```swift
final class LocationManager: NSObject, CLLocationManagerDelegate, LocationProviding {
    @Published var rawSpeed: Double = -1   // m/s; –1 = unavailable
    @Published var authorizationStatus: CLAuthorizationStatus
}
```

**Responsibilities**:
- Creates and holds `CLLocationManager`.
- Sets `desiredAccuracy = .bestForNavigation`, `activityType = .automotiveNavigation`.
- Calls `requestWhenInUseAuthorization()` on first use.
- Publishes `rawSpeed` on each `didUpdateLocations` callback.

---

### LocationProviding (protocol — for testability)

```swift
protocol LocationProviding: AnyObject {
    var speedPublisher: AnyPublisher<Double, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    func requestAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
```

**Rationale**: Decouples `SpeedViewModel` from `CLLocationManager` so unit tests inject a `MockLocationProvider`.

---

## Validation Rules

| Field | Rule |
|-------|------|
| `rawSpeed` | Display "– –" when `rawSpeed < 0` |
| `displaySpeed` | Always a non-empty string; never `nil` |

## State Transitions (authorization)

```
notDetermined
    └─ requestWhenInUseAuthorization() ──► authorizedWhenInUse → startUpdatingLocation()
                                      └─► denied → show "Location access denied" message
                                      └─► restricted → show "Location restricted" message
```
