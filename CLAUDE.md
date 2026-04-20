# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Velociraptor is a native iOS app built with SwiftUI. Minimum deployment target: iOS 18.2. No external package managers or dependencies — this is pure Swift/Xcode.

## Commands

```bash
# Build
xcodebuild build -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test
xcodebuild test -scheme Velociraptor -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing VelociraptorTests/VelociraptorTests/<TestName>
```

## Architecture

Entry point: `VelociraptorApp.swift` (`@main`) → `ContentView.swift`

Three build targets:
- **Velociraptor** — main app
- **VelociraptorTests** — unit tests using Swift Testing framework (`@Test`, `#expect`)
- **VelociraptorUITests** — UI tests using XCTest (`XCUIApplication`)

Note: unit tests use the newer Swift Testing framework (not XCTest), so test functions are annotated with `@Test` rather than prefixed with `test`.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
