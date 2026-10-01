#!/usr/bin/env swift
// Prints a GPX 1.1 track of 50,000 points to stdout, for device test D6 (quickstart.md).
// Same zig-zag as `largeGPX()` in VelociraptorTests/TrackTestDoubles.swift, about 1.1 m between points.
// The track starts at [lat lon] and runs about 55 km north.
// Usage: swift make-large-gpx.swift [lat lon] > large-50k.gpx   (defaults: 45.0 7.0)
import Foundation

let arguments = CommandLine.arguments.dropFirst().compactMap(Double.init)
let originLat = arguments.count >= 2 ? arguments[0] : 45.0
let originLon = arguments.count >= 2 ? arguments[1] : 7.0

var output = """
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="make-large-gpx" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>Large 50k</name><trkseg>
"""
for i in 0..<50_000 {
    let lat = originLat + Double(i) * 0.00001
    let lon = originLon + 0.001 * sin(Double(i) / 50)
    output += "<trkpt lat=\"\(lat)\" lon=\"\(lon)\"/>\n"
}
output += "</trkseg></trk></gpx>\n"
print(output, terminator: "")
