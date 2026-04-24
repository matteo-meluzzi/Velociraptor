# Research: Altitude Display

**Feature**: 002-altitude-display  
**Date**: 2026-04-24

## CLLocation Altitude API

**Decision**: Use `CLLocation.altitude` (type `CLLocationDistance` / `Double`), which returns meters above/below sea level.

**Rationale**: Already available on every `CLLocation` object delivered to the existing `locationManager(_:didUpdateLocations:)` delegate callback. Zero additional permission or setup required — the same location update that provides `speed` also provides `altitude`. No new CoreLocation APIs needed.

**Alternatives considered**:
- `CLLocationUpdate` (new async API, iOS 17+) — rejected; existing code uses delegate pattern and `CLLocationManager` directly. Mixing async and delegate would add unnecessary complexity.
- Barometric altitude via `CMAltimeter` — rejected; requires additional entitlement, separate framework, and is out of scope. GPS altitude from CoreLocation is sufficient.

## Altitude Accuracy

**Decision**: Display the raw `CLLocation.altitude` value without accuracy gating.

**Rationale**: The spec requires "display the raw value provided by the system location service." GPS altitude has ~10–20 m vertical accuracy in normal conditions. Filtering by `verticalAccuracy` would suppress valid readings. The app already treats speed the same way (no accuracy gate).

**Alternatives considered**:
- Gate display on `verticalAccuracy < threshold` — rejected per spec assumption that raw values are shown.

## Placeholder When Altitude Unavailable

**Decision**: Display `"– m"` when altitude data is `nil` (no fix yet or location denied).

**Rationale**: Consistent with spec FR-006. The speed screen already shows `"0.0"` for nil speed; altitude uses a dash to distinguish "no data" from a valid zero-meter altitude (which is meaningful).

**Alternatives considered**:
- Show `"0 m"` — rejected; zero is a valid altitude (sea level) and would be misleading.
- Hide the label entirely — rejected per spec (altitude display is always shown).

## Negative Altitude

**Decision**: Display negative values as-is (e.g., `"-12 m"`).

**Rationale**: Spec assumption: "Negative altitudes (below sea level) are valid values and should be displayed as-is."

## Number Formatting

**Decision**: Display altitude as a whole integer with no decimal places (`"%.0f"`).

**Rationale**: Altitude at GPS accuracy (~10–20 m) makes sub-meter precision misleading. Integer display is cleaner and more readable. Speed uses one decimal place because km/h precision is meaningful to drivers; altitude in meters does not benefit from decimals.

**Alternatives considered**:
- One decimal place (`"%.1f"`) — rejected; sub-meter GPS altitude accuracy is not reliable enough to warrant it.

## Font Sizing

**Decision**: Use `.title2` for altitude value + "m" unit, matching the existing `"km/h"` unit label size.

**Rationale**: `SpeedView` uses `.system(size: 120)` for the speed digit and `.title2` for `"km/h"`. Using `.title2` for altitude makes it visually subordinate to the speed (satisfying SC-002) and consistent with the existing secondary label styling.

**Alternatives considered**:
- `.title` — slightly larger than `.title2`, but still clearly smaller than the 120pt speed. Would work but introduces a third font size tier with no clear benefit.
- `.caption` — too small; altitude is a primary secondary metric, not a footnote.
