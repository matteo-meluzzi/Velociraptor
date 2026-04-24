# Feature Specification: Real-Time GPS Acceleration Plot

**Feature Branch**: `003-gps-acceleration-plot`  
**Created**: 2026-04-24  
**Status**: Draft  
**Input**: User description: "i want to plot the acceleration in real-time calculated from the GPS speed. I want to create the plot under the speed and altitude. the plot should show the acceleration of the last minute. the y axis should have a minimum scale of 1 m/s² but it could increase to more if the data has a value greater than 1 m/s². the unit of acceleration should always be m/s². the plotted line should be red."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View real-time acceleration chart (Priority: P1)

A user is driving or cycling and wants to monitor their acceleration in real-time. They open the app and see the speed and altitude displays, and directly below them a live-updating chart showing the acceleration computed from GPS speed changes over the past 60 seconds. The red line updates as new GPS readings arrive.

**Why this priority**: This is the core deliverable — without the live chart, the feature does not exist.

**Independent Test**: Launch the app while moving (or using a simulated GPS feed), scroll to the acceleration chart beneath the speed and altitude panels, and confirm it shows a red line updating in real time.

**Acceptance Scenarios**:

1. **Given** the app is open and GPS is active, **When** the user views the main screen, **Then** an acceleration chart is visible below the altitude display.
2. **Given** the chart is visible, **When** new GPS speed data arrives, **Then** the chart updates within one second to reflect the latest acceleration value.
3. **Given** the chart is visible, **When** the computed acceleration is within ±1 m/s², **Then** the y-axis spans at least −1 to +1 m/s².
4. **Given** the chart is visible, **When** the computed acceleration exceeds 1 m/s² (or is below −1 m/s²), **Then** the y-axis expands automatically to accommodate the value.
5. **Given** the chart is visible, **Then** the plotted line is red and the y-axis label displays "m/s²" at all times.

---

### User Story 2 - View acceleration history for the last minute (Priority: P2)

A user wants to review the last 60 seconds of acceleration, not just the instantaneous value. The chart scrolls or shifts left as time advances so that the oldest data (more than 60 seconds ago) disappears and only the most recent 60-second window is shown.

**Why this priority**: Showing a rolling window distinguishes this from a simple numeric display and delivers the key temporal insight.

**Independent Test**: Keep the app running for more than 60 seconds while moving; confirm that data older than 60 seconds is no longer visible on the chart.

**Acceptance Scenarios**:

1. **Given** the app has been collecting GPS data for more than 60 seconds, **When** the user views the chart, **Then** only the last 60 seconds of acceleration data is displayed.
2. **Given** the chart is displaying a 60-second window, **When** time advances by one second, **Then** the oldest data point drops off and the newest is added.

---

### User Story 3 - View chart when GPS data is unavailable or just started (Priority: P3)

A user opens the app but GPS has not yet acquired a fix, or fewer than two GPS samples have been received (so no acceleration can be computed yet). The chart area still renders but shows no data line until sufficient samples arrive.

**Why this priority**: Graceful empty state prevents confusion and ensures the UI is always coherent.

**Independent Test**: Launch the app indoors with no GPS signal and confirm the chart area is visible but empty (no red line), with axes still labeled correctly.

**Acceptance Scenarios**:

1. **Given** GPS is unavailable or only one sample has been received, **When** the user views the chart, **Then** the chart area is visible with labeled axes but no data line is drawn.
2. **Given** the chart shows no data, **When** GPS acquires a fix and a second sample arrives, **Then** the red line appears and begins updating.

---

### Edge Cases

- What happens when GPS speed jumps unrealistically (e.g., GPS glitch producing a spike)? The chart plots the computed value as-is; no smoothing or outlier rejection is specified.
- What happens when the app is backgrounded and then foregrounded after more than 60 seconds? Data collected during background (if any) is included; data older than 60 seconds is not shown.
- What happens at exactly the 60-second boundary? The window is strictly the most recent 60 seconds; the oldest sample is removed as soon as it ages out.
- What if acceleration is exactly 0 m/s² for the entire window? The y-axis still shows the minimum ±1 m/s² scale.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST display an acceleration chart directly below the altitude display on the main screen.
- **FR-002**: The acceleration value MUST be derived by computing the rate of change of GPS speed between consecutive GPS samples (Δspeed / Δtime).
- **FR-003**: The chart MUST display only the acceleration data from the most recent 60 seconds, discarding older samples.
- **FR-004**: The chart MUST update in real time as new GPS speed readings arrive.
- **FR-005**: The plotted data line MUST be rendered in red.
- **FR-006**: The y-axis MUST have a minimum visible range of −1 m/s² to +1 m/s².
- **FR-007**: The y-axis MUST expand automatically beyond ±1 m/s² when any data point in the current 60-second window exceeds that range.
- **FR-008**: The y-axis label MUST always display the unit "m/s²".
- **FR-009**: When no acceleration data is available (fewer than two GPS samples received), the chart MUST render its axes and labels without drawing a data line.

### Key Entities

- **Acceleration Sample**: A timestamped scalar value (in m/s²) computed from two consecutive GPS speed readings; the core data unit plotted on the chart.
- **Rolling Window**: The bounded collection of acceleration samples retained for display, limited to those with a timestamp within the last 60 seconds.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The acceleration chart is visible on the main screen every time the app is launched, positioned below the altitude display, without any additional user action.
- **SC-002**: The chart updates within 1 second of a new GPS speed reading being received.
- **SC-003**: Data older than 60 seconds is never visible on the chart.
- **SC-004**: The y-axis label reads "m/s²" 100% of the time, regardless of the magnitude of acceleration.
- **SC-005**: The y-axis never clips a data point — the visible range always fully contains every value in the current 60-second window.
- **SC-006**: The chart renders correctly (axes labeled, empty or with data line) in both the no-GPS and active-GPS states.

## Assumptions

- Acceleration is computed purely from GPS speed (as reported by the location subsystem), not from the device accelerometer.
- The GPS sampling rate is sufficient to produce meaningful acceleration values; no minimum sample rate is enforced by this feature.
- Positive acceleration (speeding up) and negative acceleration (braking) are both plotted; no absolute-value transformation is applied.
- The 60-second window is based on wall-clock time of GPS sample receipt, not distance or GPS timestamp.
- No smoothing, filtering, or outlier rejection is applied to the computed acceleration values.
- The chart is display-only; users cannot interact with (zoom, pan, or export) it.
- The existing speed and altitude displays remain unchanged by this feature.
