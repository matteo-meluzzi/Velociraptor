# Feature Specification: BLE Heart Rate Monitor

**Feature Branch**: `004-ble-heart-rate-monitor`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "as a user I want to connect to a BLE heart rate monitor that I can select from a list. The current speed should still be visible even if the heart rate monitor is not connected. When I click on a "connect heart rate monitor" button, I should get a list of all heart rate monitor available to connect with their name printed on the list. I can connect to one of them, at which point the heart rate will be visible on the left of the current speed. Its unit is also shown, bpm."

## Clarifications

### Session 2026-10-01

- Q: Should the monitor stay connected while the app is in the background or the screen is locked? → A: No; the connection may drop, and on return to the foreground the app reconnects to the same monitor automatically.
- Q: When the connection drops while the app is open, should the app reconnect automatically? → A: Yes; it keeps retrying the same monitor, showing "– bpm", until it reconnects or the user picks another monitor.
- Q: Should the app remember the last monitor and connect to it automatically at launch? → A: Yes; at launch it connects to the last monitor (Connecting, then Lost and retrying if it isn't around).
- Q: Where should the heart rate go, given there's no room left of the speed in portrait? → A: Always under the speed (replaces "left of the speed" from the original request).

## Monitor States

The speed screen shows the heart rate area according to the monitor state:

| State | Heart rate area | Button |
|---|---|---|
| **None** (no monitor chosen yet, or connection failed) | hidden | "Connect heart rate monitor" |
| **Connecting** | "Connecting…" | "Change heart rate monitor" |
| **Connected, valid reading** | value + "bpm" | "Change heart rate monitor" |
| **Connected, no valid reading** | "– bpm" | "Change heart rate monitor" |
| **Lost** (connection dropped; reconnecting automatically) | "– bpm" | "Change heart rate monitor" |

A reading is **valid** if it is above 0, the monitor does not report lost skin contact, and it arrived within the last 5 seconds.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect a Heart Rate Monitor and See Heart Rate (Priority: P1)

As a user on the speed screen, I tap "Connect heart rate monitor", pick my monitor from a list of nearby monitors shown by name, and then see my heart rate in bpm under my speed.

**Why this priority**: This is the whole feature.

**Independent Test**: With a monitor worn nearby, tap "Connect heart rate monitor", choose it, and check that a heart rate labelled "bpm" appears under the speed and follows the heart rate. Requires a physical device and monitor.

**Acceptance Scenarios**:

1. **Given** the button is tapped, **Then** a list of nearby heart rate monitors is shown, each with its name, nearest first; monitors appear and disappear as they come into and go out of range
2. **Given** the list is shown, **When** the user selects a monitor, **Then** the list closes and the state becomes Connecting, then Connected
3. **Given** the state is Connecting, **When** the connection fails, **Then** a message says the connection failed and the state becomes None
4. **Given** a monitor is connected, **When** it sends a valid reading, **Then** the value is shown under the speed, followed by "bpm", and updates with each new reading
5. **Given** a monitor is connected, **When** no valid reading is available (none yet, zero, skin contact lost, or none for 5 seconds), **Then** "– bpm" is shown
6. **Given** a monitor is connected, **When** the connection drops, **Then** the state becomes Lost and the app keeps retrying the same monitor until it reconnects (back to Connected) or the user picks another monitor
7. **Given** a monitor is connected, **When** the user taps "Change heart rate monitor" and picks another, **Then** the previous connection is replaced
8. **Given** the list is shown, **When** the user dismisses it, **Then** the state is unchanged
9. **Given** no monitors are nearby, **When** the list is shown, **Then** it says no heart rate monitors were found
10. **Given** a monitor was connected in a previous session, **When** the app launches, **Then** the state becomes Connecting to that monitor without any tap, then Connected, or Lost if it isn't available
11. **Given** Bluetooth is off or access is denied, **When** the button is tapped, **Then** a message explains that Bluetooth is needed (with a link to Settings if access was denied); if Bluetooth is turned on while the message is shown, the search starts

---

### User Story 2 - Speed Stays Usable Without a Monitor (Priority: P1)

As a user without a connected monitor, I see my speed exactly as before.

**Why this priority**: Speed is the app's core function; the feature must never get in its way.

**Independent Test**: Open the app with no monitor, with Bluetooth on and off; speed displays and updates normally and the only addition is the button.

**Acceptance Scenarios**:

1. **Given** any monitor state, Bluetooth state, or Bluetooth permission, **Then** the current speed is shown and updates without interruption
2. **Given** the heart rate is shown, **Then** the speed is never truncated or shrunk to make room

### Edge Cases

- **Monitor without a name**: listed as "Unnamed heart rate monitor".
- **Several monitors with the same name**: each is a separate entry; nearest-first order helps tell them apart.
- **App backgrounded or screen locked**: the connection need not be kept; if it dropped, the state is Lost on return and reconnection resumes automatically.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The speed screen MUST always show the button, labelled per the Monitor States table
- **FR-002**: The list MUST show only heart rate monitors, by name (or the generic label), sorted nearest first, updating live as monitors appear and disappear
- **FR-003**: The user MUST be able to select one monitor, or dismiss the list; at most one monitor is connected at a time
- **FR-004**: The heart rate area MUST follow the Monitor States table; heart rate is a whole number followed by "bpm", under the speed, in a smaller font than the speed
- **FR-005**: The app MUST tell the user when no monitors are found, when connecting fails, and when Bluetooth is off or denied
- **FR-006**: The speed display MUST NOT be affected by the monitor, Bluetooth state, or Bluetooth permission (US2)
- **FR-007**: The Bluetooth permission prompt MUST appear only when the user first taps the button, never at launch
- **FR-008**: The app MUST remember the last selected monitor between launches and connect to it automatically at launch

### Key Entities

- **Heart rate monitor**: nearby device advertising heart rate; has an optional name, a signal strength, and a state (see Monitor States).
- **Last monitor**: identifier of the most recently selected monitor, kept between launches; replaced whenever the user selects another.
- **Heart rate reading**: latest whole-number bpm value from the connected monitor, with its arrival time and skin-contact status.

## Success Criteria *(mandatory)*

- **SC-001**: From the speed screen to a displayed heart rate in under 15 seconds and 2 taps
- **SC-002**: A powered-on monitor in range appears in the list within 5 seconds
- **SC-003**: A new reading is displayed within 2 seconds
- **SC-004**: Speed stays visible and updating in every monitor state, Bluetooth state, and permission state
- **SC-005**: Within 5 seconds of a connection drop or of the last valid reading, the value is replaced by "– bpm"
- **SC-006**: On later launches with the same monitor nearby, heart rate is displayed within 15 seconds with no taps

## Assumptions

- Only standard Bluetooth Low Energy heart rate monitors are supported; other fitness sensors are out of scope.
- No explicit disconnect action; switching monitors replaces the connection.
- Heart rate is shown live only; it is not recorded, stored, or shared.
