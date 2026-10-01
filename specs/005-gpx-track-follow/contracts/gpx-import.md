# Contract: GPX import

```swift
enum GPXParser {
    /// Pure; safe to call off the main actor.
    static func parse(_ data: Data, fileName: String) -> Result<Track, GPXImportError>
}

extension UTType { static let gpx: UTType }  // importedAs "com.topografix.gpx", conforms to .xml
```

## Guarantees

| # | Guarantee |
|---|---|
| G1 | Accepts GPX 1.0 (`http://www.topografix.com/GPX/1/0`), GPX 1.1 (`…/GPX/1/1`) and no-namespace files; element matching is by local name. |
| G2 | Returns `.success` only with ≥ 1 segment of ≥ 1 valid point (validation rules in [data-model.md](../data-model.md#track-spec-key-entity-track)). |
| G3 | `elevation`, `time`, extensions and waypoints are ignored and never cause an error. |
| G4 | Never traps on malformed input; any XML error → `.unreadable`. |

## Fixture table (`GPXParserTests`)

| Input | Result |
|---|---|
| 1.1 file, 1 `trk`, 1 `trkseg`, 3 `trkpt` | 1 segment, 3 points, name from `trk/name` |
| 1.0 file, same content | same result |
| 1 `trk`, 2 `trkseg` | 2 segments, not joined |
| 2 `trk` × 1 `trkseg` | 2 segments, name from first `trk` |
| only `rte` with 4 `rtept` | 1 segment, 4 points |
| `trk` with points **and** `rte` | track points only |
| only `wpt` | `.noTrackPoints` |
| `trkpt` with `lat="95"`, `lon="abc"`, missing `lon` among valid points | invalid points dropped |
| all points invalid | `.noTrackPoints` |
| empty `trkseg` + a valid one | 1 segment |
| no `trk/name`, `metadata/name` = "Loop" | name "Loop" |
| no names at all, `fileName` "Morning ride.gpx" | name "Morning ride" |
| not XML (e.g. PNG bytes), truncated XML | `.unreadable` |
| well-formed XML, root not `gpx` | `.unreadable` |
