# Research: Real-Time GPS Acceleration Plot

**Branch**: `003-gps-acceleration-plot` | **Date**: 2026-04-24

---

## Decision 1: Acceleration computation strategy

**Decision**: Derive acceleration in the ViewModel using a stateful `previousSample` property, not inside a `LocationBehavior`.

**Rationale**: `LocationBehavior.value(from:)` is a single-location-to-value transform; it has no memory of the previous location. Acceleration requires Δspeed / Δtime across two consecutive readings, so state must live outside the behavior. Keeping state in the ViewModel (via a `previousSample: SpeedSample?` ivar) is the minimal change that follows the existing pattern without introducing a class-based stateful behavior.

**Alternatives considered**:
- *Stateful `AccelerationBehavior` (class)*: Would work but violates the stateless value-type convention used by `SpeedBehavior` and `AltitudeBehavior`. Rejected.
- *Combine `.scan` in the publisher chain*: Equivalent power but more complex than a simple ivar for a ViewModel that already runs on the main actor. Rejected for simplicity.

---

## Decision 2: New `SpeedSample` type + `SpeedSampleBehavior`

**Decision**: Introduce a `SpeedSample` struct (`speed: Double`, `timestamp: Date`) and a corresponding `SpeedSampleBehavior: LocationBehavior` that extracts both speed and `CLLocation.timestamp` from each `CLLocation`.

**Rationale**: `CLLocation.timestamp` reflects when the GPS fix was taken, not when the app received it. For high-accuracy Δtime computation this is more reliable than stamping `Date()` in the ViewModel's sink. Using `CLLocation.timestamp` avoids error from processing latency or Combine scheduler delays.

**Alternatives considered**:
- *Reuse existing `SpeedBehavior` (publishes `Double?`) and stamp `Date()` in the ViewModel*: Simpler but less accurate — Δtime would include any scheduling jitter between the GPS fix and the ViewModel's sink. Rejected.
- *Pass the raw `CLLocation` through*: Would work but breaks the behavior abstraction and leaks CoreLocation types into the ViewModel. Rejected.

---

## Decision 3: Chart framework — Swift Charts (native)

**Decision**: Use **Swift Charts** (`import Charts`), available from iOS 16 and fully supported on iOS 18.2+.

**Rationale**: Swift Charts is the standard SwiftUI-native charting solution. It requires no external dependencies (constitution: no package managers), integrates cleanly with `@Observable`/`@ObservedObject`, and provides `LineMark`, `chartYScale`, and `chartYAxisLabel` — exactly the primitives needed for a scrolling time-series line.

**Alternatives considered**:
- *Custom `Path`/`Canvas` drawing*: More control but significantly more code for axis labels, domain management, and accessibility. Rejected.
- *Third-party chart library*: Prohibited by the project's no-external-dependencies constraint. Rejected.

---

## Decision 4: Rolling window management

**Decision**: Maintain a `[AccelerationSample]` array in `AccelerationViewModel`. On every new sample, append it then remove all elements whose `timestamp < Date().addingTimeInterval(-60)`.

**Rationale**: Pruning inline on each update is O(n) where n is bounded by the GPS sample rate × 60 s (typically ≤ 60–120 elements). No timer is required; the GPS itself drives updates. This keeps the ViewModel simple and testable.

**Alternatives considered**:
- *Ring buffer / `ArraySlice`*: More efficient but unnecessary at GPS rates (1 Hz). Rejected.
- *Timer-based pruning*: Would require an extra timer and more lifecycle management. Rejected.

---

## Decision 5: Y-axis domain

**Decision**: Compute `yAxisDomain: ClosedRange<Double>` as `(-bound...bound)` where `bound = max(1.0, samples.map { abs($0.value) }.max() ?? 0)`. Pass this to `Chart.chartYScale(domain:)`.

**Rationale**: The spec requires a minimum ±1 m/s² range that auto-expands when data exceeds it. A symmetric domain (`−bound...+bound`) is appropriate because both positive (speeding up) and negative (braking) accelerations are plotted. Recomputing on every render is cheap given the small sample array size.

**Alternatives considered**:
- *Asymmetric domain (separate positive/negative bounds)*: Accurate but more complex; symmetric is a safe default for typical driving/cycling patterns. Rejected.
- *Fixed ±1 m/s² always*: Would clip extreme acceleration events. Rejected per spec (FR-007).

---

## Decision 6: X-axis time scale

**Decision**: No explicit `chartXScale` is set. Swift Charts automatically scales the X axis to the span of the data in `viewModel.samples`. This naturally shows a window that grows from 0 to 60 seconds as data accumulates, then remains a rolling 60-second window once the buffer fills.

**Rationale**: Setting an explicit X domain of `(Date.now − 60)...Date.now` would require either a timer or a re-render trigger independent of GPS updates to keep `Date.now` current. Relying on data-driven X scaling eliminates that complexity. The visual result is equivalent.

**Alternatives considered**:
- *Fixed 60-second X domain driven by a 1 s timer*: More predictable spacing but adds timer complexity. Rejected.

---

## Decision 7: File placement — `AccelerationView.swift`

**Decision**: Co-locate `AccelerationViewModel` and `AccelerationView` in a single new file `Velociraptor/AccelerationView.swift`, following the same convention as `SpeedView.swift` and `AltitudeView.swift`.

**Decision 8: `SpeedSample` and `SpeedSampleBehavior` placement**

**Decision**: Add `SpeedSample` struct and `SpeedSampleBehavior` to `LocationPublisher.swift`, alongside the existing `SpeedBehavior` and `AltitudeBehavior`. This keeps all behavior definitions in one place.

---

## Decision 9: Testing approach

**Decision**: Use the existing `MockLocationProvider<SpeedSample?>` pattern (MockLocationProvider is already generic) to drive `AccelerationViewModel` in unit tests. Test: no sample when only one reading, correct Δspeed/Δtime, rolling-window pruning, y-axis domain computation.

**Rationale**: The existing `MockLocationProvider<T>` already conforms to `LocationProviding<T>`, so `MockLocationProvider<SpeedSample?>` requires no new test infrastructure.
