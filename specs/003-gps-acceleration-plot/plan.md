# Implementation Plan: Real-Time GPS Acceleration Plot

**Branch**: `003-gps-acceleration-plot` | **Date**: 2026-04-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-gps-acceleration-plot/spec.md`

## Summary

Display a real-time red line chart of GPS-derived acceleration (m/s²) for the last 60 seconds, positioned below the existing altitude display. Acceleration is computed as Δspeed / Δtime between consecutive GPS readings using `CLLocation.timestamp` for timing accuracy. A new `SpeedSampleBehavior` extends the existing `LocationBehavior` pattern to carry both speed and timestamp; `AccelerationViewModel` manages the rolling window and drives a Swift Charts `LineMark` view.

## Technical Context

**Language/Version**: Swift 5.9, iOS 18.2+
**Primary Dependencies**: SwiftUI, Combine, CoreLocation, Swift Charts (all system frameworks — no external packages)
**Storage**: None (in-memory rolling buffer only)
**Testing**: Swift Testing framework (`@Test`, `#expect`); `MockLocationProvider<SpeedSample?>` using existing generic mock
**Target Platform**: iOS 18.2+ (iPhone)
**Project Type**: Native iOS mobile app (SwiftUI-first per Constitution Principle V)
**Performance Goals**: Chart updates within 1 second of a GPS reading; negligible overhead at typical GPS rates (~1 Hz)
**Constraints**: No external dependencies; SwiftUI-only UI; rolling buffer bounded to ≤ ~120 elements at 2 Hz GPS
**Scale/Scope**: Single chart view; 3 new production types; 1 new test file

## Constitution Check

*GATE: Must pass before implementation. Re-check after tasks complete.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Build Integrity | PASS | All changes extend existing patterns; no API removals |
| II. Test Discipline | PASS | Unit tests cover AccelerationViewModel; MockLocationProvider already exists |
| III. Peer Review Before Commit | PASS | Reviewer agent required before each commit (tracked in tasks) |
| IV. Task Completion Gate | PASS | Review sign-off required before marking any task done |
| V. SwiftUI-First | PASS | Swift Charts is a SwiftUI-native framework; no UIKit used |
| VI. Plan Review Gate | REQUIRED | Reviewer agent must APPROVE this plan before implementation begins |

**Complexity Tracking**: No violations. All additions follow existing patterns.

## Project Structure

### Documentation (this feature)

```text
specs/003-gps-acceleration-plot/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — not yet created)
```

### Source Code Changes

```text
Velociraptor/
├── LocationPublisher.swift       # ADD: SpeedSample struct, SpeedSampleBehavior
├── AccelerationView.swift        # NEW: AccelerationViewModel + AccelerationView
└── VelociraptorApp.swift         # MODIFY: init + body to add AccelerationViewModel/View

VelociraptorTests/
└── AccelerationViewModelTests.swift   # NEW: unit tests
```

---

## Implementation Tasks

### Task 1 — Add `SpeedSample` and `SpeedSampleBehavior` to `LocationPublisher.swift`

**File**: `Velociraptor/LocationPublisher.swift`

Add after `AltitudeBehavior`:

```swift
struct SpeedSample {
    let speed: Double      // m/s, guaranteed >= 0
    let timestamp: Date    // CLLocation.timestamp (GPS fix time)
}

struct SpeedSampleBehavior: LocationBehavior {
    var initialValue: SpeedSample? { nil }
    func value(from location: CLLocation) -> SpeedSample? {
        guard location.speed >= 0 else { return nil }
        return SpeedSample(speed: location.speed, timestamp: location.timestamp)
    }
}
```

**Why here**: Keeps all `LocationBehavior` conformances co-located; `SpeedSample` is a CoreLocation-level type.

**Acceptance**: Build passes; no existing tests break.

---

### Task 2 — Create `AccelerationView.swift`

**File**: `Velociraptor/AccelerationView.swift` (new file)

#### 2a. `AccelerationSample`

```swift
struct AccelerationSample {
    let timestamp: Date
    let value: Double   // m/s²
}
```

#### 2b. `AccelerationViewModel`

```swift
import Combine
import SwiftUI

@MainActor
final class AccelerationViewModel: ObservableObject {
    @Published private(set) var samples: [AccelerationSample] = []

    private var previousSample: SpeedSample?
    private var cancellable: AnyCancellable?

    init(locationProvider: some LocationProviding<SpeedSample?>) {
        cancellable = locationProvider.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current in
                self?.process(current)
            }
    }

    private func process(_ current: SpeedSample?) {
        defer { previousSample = current }
        guard let current, let previous = previousSample else { return }
        let dt = current.timestamp.timeIntervalSince(previous.timestamp)
        guard dt > 0 else { return }
        let acceleration = (current.speed - previous.speed) / dt
        let sample = AccelerationSample(timestamp: current.timestamp, value: acceleration)
        let cutoff = Date.now.addingTimeInterval(-60)
        samples.append(sample)
        samples.removeAll { $0.timestamp < cutoff }
    }

    var yAxisDomain: ClosedRange<Double> {
        let maxAbs = samples.map { abs($0.value) }.max() ?? 0
        let bound = max(1.0, maxAbs)
        return -bound...bound
    }
}
```

**Key behaviours**:
- `defer { previousSample = current }` — always updates the previous sample, even when current is nil (resets state on GPS loss).
- Rolling window pruned on every update — no timer needed.
- `yAxisDomain` is a pure computed property — trivially testable.

#### 2c. `AccelerationView`

```swift
import Charts
import SwiftUI

struct AccelerationView: View {
    @ObservedObject var viewModel: AccelerationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(viewModel.samples, id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Acceleration", sample.value)
                )
                .foregroundStyle(.red)
            }
            .chartYScale(domain: viewModel.yAxisDomain)
            .chartYAxisLabel("m/s²")
            .frame(height: 120)
        }
        .padding(.horizontal)
    }
}
```

**Note**: `id: \.timestamp` works because GPS timestamps are unique per fix. No `Identifiable` conformance is added to `AccelerationSample` to keep it a plain value type.

**Acceptance**: Build passes; view renders a red chart when sample data is present; empty state shows axes with no line.

---

### Task 3 — Wire `AccelerationViewModel` into `VelociraptorApp.swift`

**File**: `Velociraptor/VelociraptorApp.swift`

Add a new `@StateObject` and include `AccelerationView` in the `VStack`:

```swift
@StateObject private var accelerationViewModel: AccelerationViewModel

// In init():
_accelerationViewModel = StateObject(
    wrappedValue: AccelerationViewModel(
        locationProvider: LocationPublisher(behavior: SpeedSampleBehavior())
    )
)

// In body, after AltitudeView:
AccelerationView(viewModel: accelerationViewModel)
```

**Acceptance**: App compiles and runs; `AccelerationView` is visible below `AltitudeView` on the main screen.

---

### Task 4 — Unit tests: `AccelerationViewModelTests.swift`

**File**: `VelociraptorTests/AccelerationViewModelTests.swift` (new file)

Use `MockLocationProvider<SpeedSample?>` (already exists and is generic).

| Test | Scenario | Expected |
|------|----------|----------|
| `testNoSampleBeforeSecondReading` | Send one `SpeedSample`; check `samples` | `samples` is empty |
| `testAccelerationFromTwoSamples` | Send two samples 1 s apart, Δspeed = 2 m/s | `samples.first?.value == 2.0` |
| `testNilSpeedSampleResetsState` | Send valid, nil, valid, valid; check output | Acceleration only from last two valids |
| `testRollingWindowPrunesOldSamples` | Manually inject samples with old timestamps | Old samples absent after next update |
| `testYAxisDomainMinimum` | Empty samples | Domain is `-1.0...1.0` |
| `testYAxisDomainExpands` | Sample with value 3.5 m/s² | Domain is `-3.5...3.5` |
| `testZeroDeltaTimeIgnored` | Two samples with identical timestamps | `samples` is empty |

**Acceptance**: All 7 tests pass with `xcodebuild test`.

---

## Dependency Order

```
Task 1 (SpeedSample + SpeedSampleBehavior)
    └── Task 2 (AccelerationView.swift)
            └── Task 3 (VelociraptorApp wiring)
Task 4 (tests) — depends on Task 2; can be done in parallel with Task 3
```

---

## Out of Scope

- Smoothing or filtering of acceleration values
- Pan/zoom interaction on the chart
- Persistence of acceleration history
- Changes to SpeedView or AltitudeView
