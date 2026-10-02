# Feature Specification: Distance Travelled and Remaining Along the GPX Track

**Feature Branch**: `006-gpx-distance-progress`

**Created**: 2026-10-01

**Status**: Approved (independent review round 6, 2026-10-01)

**Input**: User description: "as a user, I want to see the distance left to the end of the gpx file as well as the distance travelled so far. These distances should appear under the speed and heart rate gauge in a smaller font but still readable. They should take 15% of the available height. The distance travelled so far can be computed from the start of the gpx file (by following the gpx file not straight line). The distance remaining is the distance needed to follow the rest of the gpx file (following gpx file not straight line)."

## Clarifications

### Session 2026-10-01

- Q (from the user, after review round 1): What should the distances use when the user is away from the track? → A: The closest point of the track to the user (FR-004d). Where the track passes nearly as close more than once, continuity with the previous progress chooses between the passes.
- Q (from the user, 2026-10-02, after testing on a device): "Left" was cut off ("65...."). → A: Make the distance font smaller and not bold. The values must shrink to fit rather than be cut off (FR-008).
- Q (from the user, 2026-10-02, after testing on a device): the map is too small. → A: (1) In landscape, speed, heart rate and the distances share one top bar (FR-006a). (2) The bottom buttons float over the map, which runs to the bottom edge of the screen (updates feature 005 FR-009). (3) In portrait, the empty space between speed/heart rate and the distances is halved (FR-006).
- Q (from the user, 2026-10-02): the user's position is in the middle of the map; show more of the way ahead. → A: Place it 15% of the map's height above the map's bottom edge, or higher if that would collide with the buttons (FR-014).
- Q (from the user, 2026-10-02): the instruments take too much space in portrait. → A: In portrait, shrink speed, heart rate and distances by 25%, keeping their proportions (FR-006). Landscape is unchanged.
- Decision (after review round 2): FR-004 states the required behaviour and its limits. The exact selection algorithm and its tuning are left to the plan and are verified against the US2 scenarios and SC-003, because a rule written into the spec kept failing edge cases (doubled-back legs inside the radius, slow walkers below the Moving threshold).

## Definitions

Terms from feature 005 (Track, Track line, Nearest track position, Track view, Visible area, Following, Browsing) keep their meaning.

- **Along-track distance**: distance measured by following the track from its start through every point in file order, segment after segment, never as a straight line from start to user or user to finish. Segments are taken in file order; the straight gap from the last point of one segment to the first point of the next counts toward the along-track distance (the user has to cover it to continue the track).
- **Track length**: the along-track distance from the first point of the first segment to the last point of the last segment.
- **Progress position**: the place on the track line where the app considers the user to be (chosen per FR-004). It is **established** once the user has first been within 30 m of the track after the track was loaded (or it was restored from a previous run, FR-013).
- **Distance travelled**: the along-track distance from the start of the track to the progress position.
- **Distance remaining**: the along-track distance from the progress position to the end of the track.
- **Pass**: each time the track goes by a place. Loops, out-and-back routes, crossings and hairpins go by the same place more than once.
- **On the track**: within 30 m (straight line) of the track line; **off the track**: further than that.
- **Near the user**: a pass is near the user when it comes within 30 m of them; when the user is off the track, within d + 30 m, where d is the straight-line distance to the closest point of the track.
- **Finished**: progress is established; since the track was loaded (or restored), the progress position has at some point been established and more than 200 m before the end (half the track length for tracks shorter than 400 m); at the previous location the user was on the track and the progress position was within that distance of the end; and the new progress position is at the end of the track while the user is on the track. Progress therefore never becomes finished on the first location, before progress is established, by a jump (FR-004d, FR-004e) from further away, or for a user who has only ever been near the end.
- **Distance band**: the area on screen, directly under the speed and heart rate, that shows the two distances.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See How Far I've Come and How Far Is Left (Priority: P1)

As a user following a loaded GPX track, I see under my speed and heart rate the distance I have travelled along the track so far and the distance left to its end, both measured along the track, so I can pace myself and know how much of the route remains.

**Why this priority**: This is the whole feature; the distances are what the user asked for.

**Independent Test**: Import a GPX track of known length (e.g., 5.0 km along a winding path whose start and finish are 1 km apart in a straight line). Stand at the start, then at a point known to be 2.0 km along the track; confirm the distances read about 0 / 5.0 km and 2.0 / 3.0 km respectively, not straight-line values.

**Acceptance Scenarios**:

1. **Given** a track is loaded and the user's location is known, **Then** a distance band is shown directly under the speed and heart rate, showing the distance travelled and the distance remaining, each with a label that says which is which
2. **Given** the user is at the start of the track, **Then** distance travelled is 0 and distance remaining equals the track length
3. **Given** the user is at the end of the track, **Then** distance travelled equals the track length and distance remaining is 0
4. **Given** the track winds (e.g., a switchback climb), **When** the user is partway along it, **Then** both distances are measured along the track, so they are longer than the straight-line distances to the start and finish
5. **Given** the user moves along the track, **Then** distance travelled goes up and distance remaining goes down by the same amount, and both update within 1 second of each new location
6. **Given** the user is beside the track but not exactly on it (e.g., on the other side of the road), **Then** the distances are measured from the progress position on the track, ignoring the sideways gap
7. **Given** no track is loaded, **Then** no distance band is shown and the speed screen looks as it does today

---

### User Story 2 - Correct Progress on Loops and Out-and-Back Routes (Priority: P2)

As a user on a track that passes the same place more than once, I want the distances to reflect where I am in the route, not jump to another pass of the track that happens to be nearby.

**Why this priority**: Loops (start = finish) and out-and-back routes are common; without this, the distances would be wrong at the start of every loop and on the whole return leg of every out-and-back. Simple one-way tracks work without it.

**Independent Test**: Load an out-and-back track (5 km out, 5 km back along the same road). Feed in positions along the full route in order (out to the turnaround and back) and confirm distance travelled increases steadily from 0 to 10 km with no jumps, and that at the 1 km mark on the way back it reads about 9 km, not 1 km. Repeat with a loop track starting and ending at the same place.

**Acceptance Scenarios**:

1. **Given** a loop track whose start and finish are at the same place, **When** the user is at the start and has not yet moved along the track, **Then** distance travelled is 0 (not the track length)
2. **Given** a loop track, **When** the user has gone round and returns to the start/finish, **Then** distance travelled equals the track length and distance remaining is 0
3. **Given** an out-and-back track, **When** the user is on the return leg, **Then** distance travelled is greater than half the track length, even though the outbound leg is at the same place
4. **Given** a track that crosses itself, **When** the user passes the crossing, **Then** the distances continue from the pass the user is on rather than jumping to the other pass
5. **Given** an out-and-back track whose turnaround point is at 5.00 km, **When** the user turns around up to 20 m before it and walks back, **Then** within 20 m of walking back distance travelled reads more than 5.00 km and from then on keeps increasing along the return pass; it does not follow the outbound pass back down
6. **Given** a loop track and a first location fix 40 m from the start/finish, **Then** distance travelled is about 0, not the track length, and stays near 0 as the user starts along the track
7. **Given** a track with two legs running side by side in opposite directions less than 30 m apart (a hairpin or switchback), **When** the user moves along one leg, **Then** the distances follow that leg, not the opposite one
8. **Given** an out-and-back track, **When** the user walks the return leg slowly (e.g., 2.5 km/h, below the 3 km/h Moving threshold of feature 005) or stops and starts, **Then** the distances behave as in scenario 3; no minimum speed is needed
9. **Given** an out-and-back track and a user 2 km out on the outbound leg, **When** the user walks 20 m back (e.g., to pick something up) and then continues, **Then** distance travelled goes down by about 20 m and up again; it does not jump to the return leg
10. **Given** a point-to-point track loaded 300 m (or 20 m) from its finish, **When** the user then goes to the start, **Then** at the start distance travelled is 0 and distance remaining equals the track length; the reading near the finish did not lock in as finished

---

### Edge Cases

- **User away from the track before progress is established** (e.g., walking to the start from 2 km away): the values are shown for the closest point of the track, using the earliest pass where several are almost as close (FR-004d), and they do not lock in until the user is on the track. The sideways distance to the track is not added to either value; the off-screen arrow (feature 005) already shows it.
- **User leaves the track after progress is established** (detour, more than 30 m from the track): the values follow the closest point of the track to the user (FR-004d), as the user asked. Where the track passes nearby more than once, the pass that continues from the previous progress position is used, so a detour off the return leg of an out-and-back does not jump to the outbound leg.
- **User cuts across between two legs of a hairpin**: the values may stay on the old leg for a while, then move to the new leg in one step; the skipped part counts as travelled.
- **Loop done twice in a row**: after the first lap progress is finished and the values stay at the finish (Done = track length, FR-004f); to count a second lap the user closes and re-imports the track. Counting laps is out of scope. The same applies to a one-way track: after reaching the end, wandering around does not change the values.
- **User returns to the track somewhere else** (e.g., took a shortcut that skips part of the route): the distances follow the new progress position; skipped parts of the track count as travelled. On a loop, a shortcut straight back to the shared start/finish takes whichever of start or finish is closer along the track to the previous progress position (FR-004c); it does not count as finished unless the Finished conditions hold.
- **User goes backwards along the track** where there is only one pass: distance travelled goes down and distance remaining goes up accordingly. (Near an out-and-back turnaround, walking back is treated as starting the return leg, scenario US2-5.)
- **Location unknown or access denied**: the distance band stays visible. If a progress position is established (including one restored on relaunch), the values for it are shown. Otherwise both values show "—"; no values are invented.
- **Location temporarily lost** (tunnel, weak signal): the last values stay shown and the progress position is kept, so the distances continue correctly when the location comes back.
- **Track with a single point**: track length is 0; both values show 0.
- **Multi-segment track**: gaps between segments count toward the distances (see Along-track distance).
- **Very large track** (50,000 points, the size used in feature 005 SC-002): the distances still update within 1 second of each location update and do not slow down the map.
- **New track imported**: the distances start over for the new track; its progress position is not yet established.
- **Track closed**: the distance band disappears with the track view.
- **App relaunched with the last track restored** (feature 005 FR-007): the last progress position is restored with it (FR-013), so a crash on the return leg of an out-and-back does not reset the distances to the outbound leg.
- **Browsing** (zoomed or panned): the distances are always for the user's real position, not the centre of the view.
- **Very long tracks** (e.g., 250 km): values over 100 km still fit in the band without being cut off.

## Requirements *(mandatory)*

### Functional Requirements

**Values**

- **FR-001**: When a track is loaded, the app MUST show the distance travelled and the distance remaining as defined in Definitions, both measured along the track and never as straight lines.
- **FR-002**: Distance travelled plus distance remaining MUST equal the track length. The displayed values may differ from it by up to one unit in the last displayed digit because of rounding; tests compare the unrounded values.
- **FR-003**: Both values MUST update within 1 second of each new location of the user.
- **FR-004**: On each new location, the progress position MUST be a point on the track line chosen so that:
  - **FR-004a — on a single pass**: where only one pass of the track is near the user, it is the closest point of that pass to the user.
  - **FR-004b — first time on the track**: when progress is not yet established and the user is on the track where several passes are near (e.g., the start/finish of a loop), it is on the earliest of those passes in the route. Progress becomes established the first time the user is on the track.
  - **FR-004c — continuity**: once established, where several passes are near the user, it stays on the pass that continues from the previous progress position, and it does not need a minimum speed or a compass to do so. Walking back within 20 m of an out-and-back turnaround or hairpin bend counts as continuing onto the return pass (US2-5, US2-7). Walking back where the return pass is more than 200 m further along the track stays on the same pass (US2-9). In between, either is acceptable.
  - **FR-004d — off the track**: when the user is off the track, it is the closest point of the track to the user. Where another pass is within 30 m of being as close, FR-004c chooses between them once progress is established, and FR-004b (the earliest pass) before then.
  - **FR-004e — rejoining elsewhere**: when the user comes back onto the track at a place that does not continue from the previous progress position (a shortcut), it moves there.
  - **FR-004f — finished**: once progress is finished, it stays at the end of the track (Done = track length, Left = 0) until the track is closed or another track is imported.
- **FR-005**: The sideways (straight-line) distance between the user and the progress position MUST NOT be added to either value.

**Display**

- **FR-006**: In portrait, the speed/heart rate panel and the distance band MUST be 75% of the sizes below, with everything in them scaled by the same factor (the panel content is 75% of what fits in the top 30%, and the band is 75% of 15% of the screen height). Otherwise: the distance band MUST sit directly under the speed and heart rate panel (which takes the top 30% of the screen height, feature 005 FR-009) and take 15% of the screen height, i.e., the band spans from 30% to 45% of the full screen height measured from the top edge of the screen (status bar and camera area included in the measurement, as in feature 005 FR-009). In portrait, the band is then moved up so that the visible empty space between the speed digits (or heart rate gauge) and the distance labels is half what it would be otherwise; the map gains that height.
- **FR-006a**: In landscape, the distances MUST sit in the same top bar as speed and heart rate (the top 30% of the screen height): speed and heart rate share one half of the width, and the two distances the other half. There is no separate band.
- **FR-006b**: The "Import GPX track", heart rate monitor and close-track buttons MUST float over the map, each on its own background so it stays readable. The map MUST run to the bottom edge of the screen. The map's visible area for centring ends at the top of the buttons.
- **FR-007**: The distance band MUST show two values side by side, each with a short label: distance travelled on the left (label "Done"), distance remaining on the right (label "Left").
- **FR-008**: The distance digits MUST be in a regular (not bold) weight, smaller than the speed digits, and readable at arm's length: digit height about 25% of the band height on an iPhone 16-class screen. A value MUST never be cut off. If it doesn't fit its half of the band, the number and unit shrink together. The unit ("km") and labels may be smaller than the digits.
- **FR-009**: Distances MUST be formatted in kilometres with two decimals below 100 km (e.g., "0.00 km", "3.47 km", "99.99 km") and one decimal from 100 km (e.g., "128.1 km"), matching common running and cycling apps. Every value up to 999.9 km MUST fit in its half of the band without being cut off.
- **FR-010**: When the user's location is unknown and no progress position is established, both values MUST show "—" in place of a number. When the location becomes unknown after a progress position is established, the values for that position MUST stay shown.
- **FR-011**: The distance band MUST be shown only while a track is loaded, and MUST NOT change the speed or heart rate values or behaviour.
- **FR-012**: The map's visible area MUST start below the distance band (portrait) or the top bar (landscape). The visible area bounds the off-track arrow, the Re-centre button and the track-in-view test, and the user's position within it is set by FR-014 (this updates feature 005 FR-010: "between the speed/heart rate panel and the button bar" becomes "between the distance band and the button bar").
- **FR-013**: The app MUST remember the progress position together with the last loaded track (feature 005 FR-007), and restore it as established when the track is restored on relaunch, together with whether it has been more than 200 m (or half the track length for tracks shorter than 400 m) before the end (see Finished). The saved position MUST be no more than 10 seconds old while the user is moving along the track. Importing a new track or closing the track MUST discard it.
- **FR-014**: When the track view is Following (and after Re-centre), the user's position MUST be drawn 15% of the map's height above the map's bottom edge. The map's height runs from the bottom of the top overlay to the bottom of the screen. If that point is less than 40 pt above the top of the floating buttons, the position MUST be raised to 40 pt above them. This supersedes feature 005 FR-010, which put the user in the middle of the visible area. The track-in-view test and the re-centre button still use the whole visible area. The off-track arrow is placed where a ray from the user's position meets the edge of the visible area, and when that point would be within 64 pt of the user's dot it sits 64 pt from the dot instead (above it when the track is behind), moving continuously as the direction changes. The position is never above the middle of the visible area.

### Key Entities

- **Track** (from feature 005): gains a track length.
- **Track progress**: the current progress position (established or not), distance travelled, and distance remaining. Saved with the track and restored with it; discarded when a new track is imported or the track is closed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On test tracks of known length, the displayed track length (distance remaining at the start) is within 1% of the true along-track length.
- **SC-002**: At any point along a test track, distance travelled is within 1% of the track length (or 20 m, whichever is larger) of the true along-track distance to that point, measured on the pass the user is on. The first 20 m of walking back after an out-and-back turnaround or hairpin bend (before the switch allowed by FR-004c) is exempt.
- **SC-003**: Walking or simulating the full route of a loop, an out-and-back track (including turning round up to 20 m short of the tip, and walking slowly), and a hairpin track in order, distance travelled never jumps by more than 60 m (twice the on-track radius) between consecutive location updates spaced 1 second apart, including when the user strays between 30 m and 50 m off the track and comes back, apart from the one switch onto the return pass at an out-and-back turnaround or hairpin bend, which may jump up to 100 m.
- **SC-004**: Both values update within 1 second of each location update, for tracks up to 50,000 points, while the map keeps redrawing at least 55 times per second (feature 005 SC-002).
- **SC-005**: A user holding the phone at arm's length can read both distances at a glance, on first attempt, in daylight.

## Assumptions

- "15% of the available height" means 15% of the full screen height, consistent with feature 005 FR-009 where the speed/heart rate panel takes the top 30% of the screen height. The band is added below that panel, so the map's visible area shrinks by 15% of the screen height.
- Kilometres with two decimals are a sensible default for walking, running, and cycling; no miles or unit setting is in scope.
- The 30 m on-track radius covers typical phone GPS error plus road width, so both carriageways and both passes of an out-and-back on the same road count as near the user.
- Gaps between segments count toward the distances, since the user has to cover them to follow the rest of the track. Most multi-segment files are recordings paused briefly, so the gaps are short.
- Elevation is ignored: distances are measured over the ground surface, not including climbs.
- Out of scope: estimated time to finish, average pace, progress bars, off-track warnings, and recording the user's own travelled path.
