# Data Model: Altitude Display

**Feature**: 002-altitude-display  
**Date**: 2026-04-24

## Data Flow

```
CLLocationManager
  └─ didUpdateLocations([CLLocation])
       └─ CLLocation.altitude: Double       ← meters above/below sea level
            └─ altitudeSubject (CurrentValueSubject<Double?, Never>)
                 └─ altitudePublisher (AnyPublisher<Double?, Never>)
                      └─ SpeedViewModel.displayAltitude: String
                           └─ SpeedView Text("…")
```

## Protocol Extension: LocationProviding

The `LocationProviding` protocol gains one new publisher:

| Property | Type | Description |
|----------|------|-------------|
| `altitudePublisher` | `AnyPublisher<Double?, Never>` | Emits current altitude in meters. `nil` when no fix or location denied. |

Existing properties (`speedPublisher`, `authorizationStatusPublisher`) are unchanged.

## LocationManager Changes

| Addition | Detail |
|----------|--------|
| `altitudeSubject` | `CurrentValueSubject<Double?, Never>(nil)` — internal subject |
| `altitudePublisher` | Exposes `altitudeSubject.eraseToAnyPublisher()` |
| `didUpdateLocations` | Sends `locations.last?.altitude` to `altitudeSubject` |

`CLLocation.altitude` is always valid on a real fix. No special handling needed for negative values.

## SpeedViewModel Changes

| Property | Type | Initial value | Format |
|----------|------|---------------|--------|
| `displayAltitude` | `@Published String` | `"– m"` | `"\(Int(altitude.rounded())) m"` when altitude is non-nil; `"– m"` when nil |

The `bindPublishers()` method gains a subscription to `locationProvider.altitudePublisher`.

## MockLocationProvider (test helper)

Gains one new method:

```swift
func send(altitude: Double?) { altitudeSubject.send(altitude) }
```

The existing `MockLocationProvider` already has `speedSubject` and `authorizationSubject`; an `altitudeSubject` is added in parallel.

## SpeedView Layout

```
VStack(spacing: 8)
├── Spacer
├── Text(viewModel.displaySpeed)          ← .system(size: 120, weight: .thin)
├── Text("km/h")                          ← .title2, .secondary
├── Text(viewModel.displayAltitude)       ← .title2, .secondary   [NEW]
├── Text("Location unavailable")          ← .caption (conditional)
└── Spacer
```

The altitude `Text` is placed between the `"km/h"` label and the "Location unavailable" warning, keeping the speed group visually cohesive.
