# Feature Specification: Altitude Display

**Feature Branch**: `002-altitude-display`  
**Created**: 2026-04-24  
**Status**: Draft  
**Input**: User description: "i want to show the current altitude in meters right under the current speed. the font should be smaller than the speed. the unit is always meters and doesnt change"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Altitude While Tracking Speed (Priority: P1)

As a user viewing the speed screen, I want to see my current altitude in meters displayed just below the speed reading, so I have relevant elevation context without navigating away.

**Why this priority**: Core feature request — altitude is displayed alongside speed as a secondary metric. No other stories depend on it.

**Independent Test**: Can be fully tested by opening the app and observing that an altitude value in meters appears below the speed display.

**Acceptance Scenarios**:

1. **Given** the speed screen is visible, **When** the app has GPS data, **Then** the current altitude in meters is shown directly below the speed value
2. **Given** the speed screen is visible, **When** the altitude value is displayed, **Then** the altitude text is visually smaller than the speed text
3. **Given** the speed screen is visible, **When** the altitude is displayed, **Then** the unit label reads "m" (meters) and is always present regardless of any other app settings

---

### Edge Cases

- What happens when GPS altitude data is unavailable or not yet acquired?
- What happens when the altitude value is negative (e.g., below sea level)?
- What happens when altitude readings fluctuate rapidly?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST display the current GPS altitude in meters on the speed screen
- **FR-002**: The altitude display MUST be positioned directly below the speed display
- **FR-003**: The altitude text MUST use a font size smaller than the speed display font size
- **FR-004**: The unit for altitude MUST always be meters ("m") and MUST NOT be changeable by the user
- **FR-005**: The altitude value MUST update in real time as GPS altitude data changes
- **FR-006**: When GPS altitude data is unavailable, the app MUST display a placeholder (e.g., "– m") rather than crashing or showing nothing

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Altitude in meters is visible on the speed screen at all times when the screen is active
- **SC-002**: The altitude label is visually subordinate to the speed — font size is demonstrably smaller
- **SC-003**: The "m" unit label is always present next to the altitude value and cannot be removed or changed
- **SC-004**: Altitude value updates within the same refresh cycle as the speed display

## Assumptions

- GPS altitude accuracy depends on device hardware and signal quality; the app displays the raw value provided by the system location service
- Negative altitudes (below sea level) are valid values and should be displayed as-is
- The unit "m" (meters) is hardcoded; no localization or unit conversion is required
- The altitude display is always shown, not togglable by the user
