# Data Model: GPS Speed Display

## Entities

### SpeedUnit (enum)

```swift
enum SpeedUnit: String, CaseIterable {
    case kmh = "km/h"
    case mph = "mph"

    func convert(from metersPerSecond: Double) -> Double {
        switch self {
        case .kmh: return metersPerSecond * 3.6
        case .mph: return metersPerSecond * 2.23694
        }
    }
}
```

**Fields**: raw string label used directly in the UI.  
**Relationships**: consumed by `SpeedViewModel`.

---

### SpeedViewModel (ObservableObject)

```swift
@MainActor
final class SpeedViewModel: ObservableObject {
    @Published var displaySpeed: String      // e.g. "87" or "3.2" or "– –"
    @Published var unit: SpeedUnit = .kmh
    @Published var isLocationAvailable: Bool // false when GPS not locked

    private let locationProvider: LocationProviding
}
```

**Responsibilities**:
- Subscribes to `LocationProviding.speedPublisher`.
- Converts raw m/s → display string using `SpeedUnit.convert(from:)`.
- Formats: 0 decimal places if converted ≥ 10, 1 decimal place if < 10, "– –" if raw speed < 0.

**State transitions**:

```
.notDetermined ──request──► .authorizedWhenInUse ──startUpdating──► receiving updates
                                                                         │
                         .denied ◄──── user denies ────────────────────┘
```

---

### LocationManager (NSObject, CLLocationManagerDelegate, ObservableObject)

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
| `unit` | Must be a valid `SpeedUnit` case; default `.kmh` |
| `displaySpeed` | Always a non-empty string; never `nil` |

## State Transitions (authorization)

```
notDetermined
    └─ requestWhenInUseAuthorization() ──► authorizedWhenInUse → startUpdatingLocation()
                                      └─► denied → show "Location access denied" message
                                      └─► restricted → show "Location restricted" message
```
