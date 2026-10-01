# Feature Specification: Follow a GPX Track

**Feature Branch**: `005-gpx-track-follow`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "as a user, I want to follow a gpx track. 1. user can import a gpx track file by clicking a button next to "change heart rate monitor" 2. a gpx view appears where the user can see their current location and the gpx breadcrumbs of the loaded file 3. the gpx view does not show the entire gpx. It shows a 1km2 view around the current location of the user. 4. if the gpx breadcrumbs are outside the 1km2, show an arrow pointing to the nearest gpx coordinate. 5. the user can zoom in and out to increase or decrease the 1km2, and they can also scroll. If they do that, there appears a "re-center" button which resets the view. 6. the orientation of the gpx view is based on the compass if the user is not moving. If they are moving, base the orientation of the gpx view on the direction that the user is going. 7. clarification: determine if it would be easy for the gxp view to show a map with roads and intersections to make it easier for the user to follow the gpx. If that requires a lot of work, show only the gpx breadcrumbs and user position."

## Clarifications

### Session 2026-10-01

- Q: Where does the track view appear relative to the speed and heart rate? → A: The track view fills the screen; speed and heart rate are shown smaller on top of it (FR-009).
- Q: While the app is open, should the screen stay on instead of auto-locking? → A: Yes, whenever the app is open, with or without a track loaded (FR-024).
- Q (2026-10-01, after implementation of US1–US5, from the user): How big should speed and heart rate be over the map? → A: They take the top 30% of the screen height (FR-009).
- Q: Should the track view show which way the track goes? → A: Yes. Start and finish markers, plus small direction chevrons spaced along the line (FR-008a).

## Definitions

- **Track**: the ordered list of points (breadcrumbs) read from a GPX file, drawn as a line through the points.
- **Track view**: the area on screen that shows the track around the user.
- **Visible area**: the part of the track view not covered by the speed/heart rate overlay and buttons.
- **View width**: the ground distance shown across the shorter side of the screen (the width in portrait).
- **Default view**: the track view centred on the user's current location with a view width of 1 km; the longer side shows proportionally more. Rotated according to the orientation rule below. (This is how the request's "1 km² around the user" applies to a non-square screen.)
- **Following**: the track view is in the default view and keeps itself centred on the user as they move (or on the track's first point while the user's location is unknown).
- **Browsing**: the user has zoomed or panned the track view, so it no longer follows the user.
- **Moving**: the user's speed is at or above 3 km/h. **Stationary**: speed is below 2 km/h. Between 2 and 3 km/h the previous state is kept, so the orientation does not flip back and forth at walking-pace boundaries.
- **Track line**: the line drawn through the track points of each segment in order; segments are not joined to each other.
- **Nearest track position**: the position on the track line (anywhere along it, not only at its points) with the shortest straight-line distance to the user's real current location.
- **Track in view**: any part of the track line lies inside the visible area, even if none of its points do.

## Track View Orientation

| User state | Top of the track view points to |
|---|---|
| Moving | the direction the user is travelling |
| Stationary | the direction the device is facing (compass heading) |
| Direction unavailable for the current state (no travel direction while Moving, or no compass while Stationary) | the last orientation shown; north if there has never been one |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import a Track and See It Around Me (Priority: P1)

As a user on the speed screen, I tap "Import GPX track" next to "Change heart rate monitor", pick a GPX file, and see a full-screen track view that shows my current location and the track breadcrumbs in about 1 km around me, with my speed and heart rate still on top.

**Why this priority**: Without loading and drawing the track there is nothing to follow; this is the minimum useful slice.

**Independent Test**: Import a GPX file whose track passes within 500 m of the tester's location; confirm the track view appears, the user's position marker is in the centre, and the part of the track inside the default view is drawn in the right place relative to the marker.

**Acceptance Scenarios**:

1. **Given** the speed screen is shown, **Then** an "Import GPX track" button is shown next to the heart rate monitor button, whether or not a heart rate monitor is connected
2. **Given** the user taps "Import GPX track", **Then** the system file picker opens and lets the user choose a GPX file from the device or from file storage services available on the device
3. **Given** the user picks a valid GPX file, **Then** the file picker closes and the track view fills the screen showing the default view, with speed and heart rate shown smaller on top of it, and with the user's position marker in the centre and the track line drawn wherever it passes through the view, with direction chevrons along it and start/finish markers where they fall inside the view
4. **Given** the user dismisses the file picker without choosing a file, **Then** nothing changes
5. **Given** the user picks a file that is not a valid GPX file or contains no track or route points, **Then** a message says the file could not be loaded and any previously loaded track stays loaded
6. **Given** a track is loaded, **When** the user imports another file successfully, **Then** the new track replaces the old one
7. **Given** a track is loaded, **When** the user moves, **Then** the track view stays centred on the user's position
8. **Given** a track is loaded, **When** the user chooses to close the track, **Then** the track view disappears and the screen returns to how it looked before any track was imported
9. **Given** the user's location is not yet known or location access is denied, **When** a track is loaded, **Then** the track view says the current location is not available (with a link to Settings if access was denied) and shows the track centred on its first point until a location is known; "Re-centre" in this state returns to the track's first point
10. **Given** the view is centred on the track's first point because the location was unknown, **When** the location becomes known, **Then** the view moves to the default view centred on the user if it is Following, and stays where it is if the user is Browsing

---

### User Story 2 - Arrow Toward the Track When It Is Off-Screen (Priority: P1)

As a user who is away from the track, I see an arrow pointing toward the nearest position on the track, with the distance to it, so I know which way to go to get back on it.

**Why this priority**: The user will often start the activity away from the track or stray from it; without the arrow an empty view gives no guidance.

**Independent Test**: Import a GPX file whose nearest track position is more than 1 km from the tester; confirm an arrow appears pointing toward it, and that it disappears once the track comes into view.

**Acceptance Scenarios**:

1. **Given** the track is not in view (no part of the track line inside the visible area), **Then** an arrow is shown at the edge of the visible area pointing toward the nearest track position, together with the distance to it (in metres below 1 km, in km with one decimal from 1 km)
2. **Given** the arrow is shown, **When** the user or the view rotates, **Then** the arrow keeps pointing toward the nearest track position
3. **Given** the arrow is shown, **When** any part of the track line enters the visible area, **Then** the arrow disappears
4. **Given** a track whose points are far apart, **When** the line between two points crosses the visible area but neither point is inside it, **Then** no arrow is shown
5. **Given** the view is Browsing and has been panned away from the user, **Then** the arrow's direction and distance are still measured from the user's real position
6. **Given** the user's location is not known, **Then** no arrow is shown

---

### User Story 3 - Track View Turns With Me (Priority: P2)

As a user following the track, I want the top of the track view to point where I'm heading when I move, and where my phone is pointing when I stand still, so that left and right on screen match left and right in the real world.

**Why this priority**: A rotating view makes it much easier to decide which way to turn, but the track is still usable with a north-up view.

**Independent Test**: Walk in a straight line and confirm the direction of travel is at the top of the view; stop and turn the phone and confirm the view rotates with the phone.

**Acceptance Scenarios**:

1. **Given** the user is Moving, **Then** the track view is rotated so the direction of travel points to the top of the screen
2. **Given** the user is Stationary, **Then** the track view is rotated so the direction the device is facing points to the top of the screen, and it updates as the user turns the device
3. **Given** the direction for the current state is unavailable (no travel direction while Moving, or no compass heading while Stationary), **Then** the view keeps the last orientation shown, or north-up if there has never been one
4. **Given** the view is rotated, **Then** a north indicator shows where north is
5. **Given** the orientation changes, **Then** the view rotates smoothly rather than jumping, and the view does not rotate while the new heading differs from the currently displayed orientation by less than 5°

---

### User Story 4 - Zoom, Pan, and Re-centre (Priority: P2)

As a user, I can zoom in and out and pan the track view to look further ahead or see more detail, and then tap "Re-centre" to go back to the default view.

**Why this priority**: Useful for planning ahead, but following works without it.

**Independent Test**: With a track loaded, pinch to zoom, then drag; confirm "Re-centre" appears; tap it and confirm the default view is restored and the button disappears.

**Acceptance Scenarios**:

1. **Given** the track view is Following, **When** the user pinches to zoom in or out, **Then** the view width shrinks or grows accordingly, down to 100 m and up to 20 km, and the view stops following the user (as the request asks, "Re-centre" appears after zooming too)
2. **Given** the track view is Following, **When** the user drags the view, **Then** the view pans and no longer follows the user's position
3. **Given** the user has zoomed or panned (Browsing), **Then** a "Re-centre" button is shown and the view keeps the zoom and position the user chose while the user's marker continues to move
4. **Given** the "Re-centre" button is shown, **When** the user taps it, **Then** the track view returns to the default view (1 km view width, centred on the user, oriented by the orientation rule), the button disappears, and Following resumes
5. **Given** the track view is Browsing, **Then** the orientation rule still applies (the view keeps rotating with travel direction or compass)

---

### User Story 5 - See Roads Under the Track (Priority: P3)

As a user following the track, I see roads and intersections under the breadcrumbs so I can tell which road or path to take at a junction.

**Why this priority**: Makes the track much easier to follow at intersections, but the track and arrow alone are enough to follow it.

**Independent Test**: With a data connection, import a track along known streets; confirm streets and intersections are drawn under the track line and line up with it. Turn off the data connection in an area not viewed before; confirm the track and position are still shown without the road map.

**Acceptance Scenarios**:

1. **Given** a track is loaded and map data is available, **Then** a street map with roads and intersections is shown under the track line and the user's position marker, rotating and zooming together with them
2. **Given** map data cannot be loaded (e.g., no data connection and the area is not cached), **Then** the track line, position marker, and arrow are still shown on a plain background, and following works as normal
3. **Given** the street map is shown, **Then** the track line stays clearly visible on top of it (contrasting colour and width)

---

### Edge Cases

- **Very large file** (e.g., 50,000 points): loads and draws within SC-002; points far outside the visible area do not slow down the view.
- **File with several tracks or segments**: all segments are shown; gaps between segments are not joined with a line.
- **File with only a route (no track)**: route points are used as the track.
- **File with only waypoints**: treated as having no track points (error message as in US1 scenario 5).
- **Points with missing or out-of-range coordinates**: ignored; if no valid points remain, the file is rejected.
- **User exactly on the track**: no arrow is shown, the track passes through the position marker.
- **Track that loops or crosses itself**: drawn as is; the nearest track position is whichever is closest, regardless of order. Where the line overlaps itself (an out-and-back route), the chevrons of both directions are visible.
- **Poor GPS accuracy**: the position marker shows the accuracy (e.g., a halo); the arrow and centring use the best available position.
- **Compass needs calibration or is unavailable**: covered by the last row of the Track View Orientation table (last orientation shown, else north-up).
- **App goes to background and returns**: the loaded track is kept. If the view was Following, it re-centres on the user's current position. If it was Browsing, the zoom and position stay as they were and "Re-centre" is still shown.
- **App is relaunched**: the last loaded track is loaded again automatically and shown in the default view, unless the user closed it, in which case no track is shown. If the stored track can no longer be read, the track view does not appear and no error is shown.
- **Heart rate monitor states**: the import button and the track view never change the behaviour of the heart rate monitor or the speed value; only the size and position of the speed and heart rate change while a track is loaded (FR-009).

## Requirements *(mandatory)*

### Functional Requirements

**Import**

- **FR-001**: The speed screen MUST show an "Import GPX track" button next to the heart rate monitor button, in every heart rate monitor state.
- **FR-002**: Tapping the button MUST open the system file picker restricted to GPX files.
- **FR-003**: The app MUST read track points and, if there are none, route points from the chosen GPX 1.1 or 1.0 file. Waypoints alone are not a track.
- **FR-004**: The app MUST reject files that cannot be read as GPX or contain no valid track/route points, show a message saying the file could not be loaded, and keep the previously loaded track, if any.
- **FR-005**: Importing a new valid track MUST replace the previously loaded one.
- **FR-006**: The user MUST be able to close the loaded track, which hides the track view.
- **FR-007**: The app MUST remember the last loaded track and show it again when the app is relaunched, so that a crash or the system closing the app mid-activity does not lose the track. A track the user closed (FR-006) MUST NOT come back on relaunch.

**Track view**

- **FR-008**: When a track is loaded, the app MUST show a track view containing the user's position marker and the track line.
- **FR-008a**: The track view MUST show which way the track goes: a start marker at the first point of the first segment, a finish marker at the last point of the last segment, and small chevrons along the track line pointing in file order. The chevrons are 1 cm ± 0.3 cm apart on screen at every zoom level. Only the overall start and finish get markers, not the ends of segments in between. When start and finish are within 20 m of each other (a loop), one combined start/finish marker is shown. Chevrons and markers MUST stay clearly visible on top of the street map (as in US5-AS3).
- **FR-009**: When a track is loaded, the track view MUST fill the screen, with the speed (km/h), the heart rate (when shown per feature 004), the "Import GPX track" button, the heart rate monitor button, and the close-track control shown on top of it. The speed and heart rate MUST take the top 30% of the screen height (measured from the top edge of the screen), sized to fill that area; the buttons sit in a small bar at the bottom. The speed MUST stay readable at arm's length (its digits at least one third of their full-size height). While a track is loaded, this supersedes feature 004 User Story 2 scenario 2 ("speed never shrunk"), as chosen in Clarifications. When no track is loaded, the speed screen MUST look as it does today.
- **FR-010**: The default view MUST have a 1 km view width and be centred on the user's current location, with the user in the middle of the visible area (between the speed/heart rate panel and the button bar).
- **FR-011**: While Following, the track view MUST stay centred on the user's current location as it changes.

**Off-screen arrow**

- **FR-012**: When the track is not in view and the user's location is known, the track view MUST show an arrow pointing to the nearest track position, with the straight-line distance to it, both measured from the user's real position even while Browsing.
- **FR-013**: The arrow MUST be hidden whenever the track is in view.

**Orientation**

- **FR-014**: The track view MUST be oriented according to the Track View Orientation table, using the Moving/Stationary definitions (3 km/h and 2 km/h thresholds).
- **FR-015**: Orientation changes MUST be animated smoothly, and the view MUST NOT rotate while the new heading differs from the currently displayed orientation by less than 5° (so slow drift still turns the view once it adds up to 5°).
- **FR-016**: The track view MUST show a north indicator whenever north is not at the top.

**Zoom, pan, re-centre**

- **FR-017**: The user MUST be able to zoom the track view with a pinch gesture between 100 m and 20 km view width.
- **FR-018**: The user MUST be able to pan the track view with a drag gesture.
- **FR-019**: After any zoom or pan, the track view MUST stop following the user's position and show a "Re-centre" button. This applies to zoom-only changes too, as the request asks.
- **FR-020**: Tapping "Re-centre" MUST restore the default view, hide the button, and resume Following.

**Road map**

- **FR-021**: When map data is available, the track view MUST show a street map with roads and intersections under the track and the position marker, aligned with them and rotating and zooming together.
- **FR-022**: When map data is not available, the track view MUST still show the track, position marker, and arrow on a plain background.

**Location access**

- **FR-023**: When location is unknown or access is denied, the track view MUST say so (with a link to Settings if access was denied), and centre on the track's first point until a location is known. When the location becomes known, a Following view moves to the default view; a Browsing view stays where it is.

**Screen**

- **FR-024**: While the app is open in the foreground, the screen MUST NOT dim or auto-lock, whether or not a track is loaded. When the app goes to the background, the device's normal auto-lock applies again. The user can still lock the device manually. This supersedes the default auto-lock behaviour of feature 004's speed screen, as chosen in Clarifications.

### Key Entities

- **Track**: the imported route. Attributes: name (from the file, or the file name if none), one or more segments, each an ordered list of points.
- **Track point**: latitude and longitude (elevation and time in the file are ignored by this feature).
- **Track view state**: Following or Browsing; current view width; current centre; current orientation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From the speed screen, a user can import a GPX file and see it around their position in under 15 seconds (excluding the time to find the file).
- **SC-002**: A track of 50,000 points loads and appears in under 3 seconds, and the view is redrawn at least 55 times per second while zooming, panning, and rotating on an iPhone 16-class device.
- **SC-003**: While Following and walking, the user's marker is never more than 10% of the view width from the centre.
- **SC-004**: The off-screen arrow points within 5° of the true direction to the nearest track position.
- **SC-005**: After the user goes from stationary to moving (or back), the view switches orientation source within 3 seconds, including the smoothing animation.
- **SC-006**: A user standing 2 km from the track can reach the track by following only the arrow, without zooming or panning.
- **SC-007**: At 5 sample intersections of a track recorded along streets, the track line lies within 10 m of the road it was recorded on in the road map.

## Assumptions

- **Road map is low effort (item 7 resolved)**: the device platform provides a built-in street map service with roads and intersections that can be shown under custom lines and markers, rotated, and zoomed, at no extra cost and without third-party services. Showing roads therefore adds little work compared with drawing breadcrumbs on a blank background, so it is in scope (User Story 5). It needs a data connection for areas not already cached; offline, the plain-background fallback applies.
- "1 km² around the current location" is read as a 1 km view width centred on the user (about 500 m either side); on a portrait screen the height shows more than 1 km. See Definitions.
- Zoom limits (100 m to 20 km wide) are reasonable defaults for walking, running, and cycling.
- Moving/Stationary thresholds (3 km/h and 2 km/h) are reasonable defaults for walking pace; travel direction is unreliable at lower speeds.
- Distance to the nearest track position is straight-line distance, not distance along roads.
- The feature only shows the track; it does not give turn-by-turn instructions, measure progress along the track, warn when the user goes off-track, record the user's own track, or show elevation.
- The app only needs the track while it is in the foreground; there is no background tracking for this feature.
- Keeping the screen on (FR-024) uses more battery; the user is expected to close or background the app when not using it. This also changes the speed screen from feature 004, which until now allowed normal auto-lock.
- Only one track is loaded at a time.
- Location access already requested for the speed display is reused; compass heading needs no extra permission.
- The existing speed display and heart rate monitor (feature 004) keep their behaviour. Only their size and placement change while a track is loaded (FR-009).
