# Quickstart: Distance Travelled and Remaining

## Automated

```bash
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing VelociraptorTests/TrackProgressTests
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Manual (simulator)

1. Run the app and import a GPX file through Files.
2. In Simulator, choose Features ▸ Location ▸ Custom Location and enter the first track point. The band reads `Done 0.00 km` and `Left <length> km`.
3. Enter a point further along the track. The values change, and Done + Left stays the same.
4. Check the band's layout:
   - It sits directly under the speed/heart rate panel and is about 15% of the screen tall.
   - The map's centre (blue dot) is in the middle of the area between the band and the button bar.
5. Rotate to landscape. The values still fit.
6. Quit and relaunch the app. The band shows the previous values before a new fix arrives.
7. Close the track. The band disappears and the screen returns to the plain speed screen.

## Manual (device, outdoors)

- Walk an out-and-back route. After the turnaround, Done keeps increasing.
- Walk at arm's length in daylight. Both values are readable at a glance (SC-005).

## Verification log

- 2026-10-02, simulator (iPhone 16): a stored loop track with the location set beside it.
  - The band read "Done 1.02 km | Left 7.12 km".
  - It sat directly under the speed panel, spanning about 30–45% of the screen height.
  - The blue dot was centred between the band and the button bar.
- Steps 5–7 (landscape, relaunch, close) are covered by unit tests D7/D6 and the layout code. They were not checked by hand.
- The device and outdoor checks are not done; they need a real walk.
