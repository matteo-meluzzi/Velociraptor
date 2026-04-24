# Data Model: Real-Time GPS Acceleration Plot

**Branch**: `003-gps-acceleration-plot` | **Date**: 2026-04-24

All types are in-memory only. No persistence layer.

---

## SpeedSample

**Purpose**: Carries a validated GPS speed reading together with the GPS fix timestamp, enabling accurate Δtime computation between consecutive readings.

**Location**: `Velociraptor/LocationPublisher.swift` (alongside existing `SpeedBehavior`, `AltitudeBehavior`)

| Field | Type | Constraints |
|-------|------|-------------|
| `speed` | `Double` | GPS speed in m/s; always ≥ 0 (invalid readings filtered before construction) |
| `timestamp` | `Date` | Taken from `CLLocation.timestamp` (GPS fix time, not reception time) |

**Validation**: `SpeedSampleBehavior.value(from:)` returns `nil` when `location.speed < 0`; a `SpeedSample` is never constructed for invalid readings.

---

## SpeedSampleBehavior

**Purpose**: `LocationBehavior` conformance that extracts `SpeedSample?` from a `CLLocation`. Follows the same pattern as the existing `SpeedBehavior` and `AltitudeBehavior`.

**Location**: `Velociraptor/LocationPublisher.swift`

| Member | Type | Notes |
|--------|------|-------|
| `initialValue` | `SpeedSample?` | `nil` — no sample before first GPS fix |
| `value(from:)` | `(CLLocation) -> SpeedSample?` | Returns `nil` if `location.speed < 0` |

---

## AccelerationSample

**Purpose**: A single computed acceleration value at a point in time, suitable for direct use as a chart data point.

**Location**: `Velociraptor/AccelerationView.swift`

| Field | Type | Constraints |
|-------|------|-------------|
| `timestamp` | `Date` | Taken from the *current* `SpeedSample.timestamp` (the later of the two readings) |
| `value` | `Double` | Acceleration in m/s²; may be negative (braking); unbounded magnitude |

**Derivation**: `value = (currentSample.speed − previousSample.speed) / (currentSample.timestamp − previousSample.timestamp)`

---

## AccelerationViewModel (state)

**Purpose**: Maintains the rolling 60-second buffer of `AccelerationSample` values and the previous `SpeedSample` needed for the next acceleration computation.

**Location**: `Velociraptor/AccelerationView.swift`

| Property | Type | Role |
|----------|------|------|
| `samples` | `[AccelerationSample]` | Published; consumed by `AccelerationView`; pruned to last 60 s on each update |
| `previousSample` (private) | `SpeedSample?` | Mutable state; holds the last valid `SpeedSample` for Δ computation |
| `yAxisDomain` (computed) | `ClosedRange<Double>` | `(−bound...bound)` where `bound = max(1.0, maxAbsValue)`; drives `chartYScale` |

**State transitions**:

```
GPS delivers nil SpeedSample  → previousSample remains; no AccelerationSample added
GPS delivers first SpeedSample  → previousSample set; no AccelerationSample yet
GPS delivers second SpeedSample → AccelerationSample computed; appended; previousSample updated
GPS delivers Nth SpeedSample    → same as above; samples pruned to last 60 s
```

---

## Rolling Window Invariant

At all times, every element in `AccelerationViewModel.samples` satisfies:

```
sample.timestamp >= Date.now - 60 seconds
```

Enforcement: after appending each new `AccelerationSample`, `samples.removeAll { $0.timestamp < Date.now.addingTimeInterval(-60) }` is called.
