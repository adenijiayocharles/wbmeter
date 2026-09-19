# Repository Guidelines

## Project Structure

`PRD.md` is the product source of truth. `design/` contains the screen and flow prototypes plus their shared preview runtime. The iOS app and asset catalog are in `wbmeter/`; the Xcode project and `wbmeter` scheme are in `wbmeter.xcodeproj/`. Xcode’s synchronized folder includes Swift files added under `wbmeter/` automatically.

## Build and Development

Build for an iPhone device with:

```sh
xcodebuild -project wbmeter.xcodeproj -scheme wbmeter -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Open `wbmeter.xcodeproj` in Xcode to run on a signed physical iPhone. A successful simulator or generic-device build does not verify camera hardware behavior; check live preview and permissions on an iPhone.

## Architecture and Style

Keep SwiftUI presentation in `ContentView.swift` and `CameraPreview.swift`. Keep permission state in `CameraService.swift` and all `AVCaptureSession` configuration and lifecycle work in `CameraSessionController.swift`. Use four-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for properties and functions. Keep future color-science calculations independent of AVFoundation and UI code, as required by `PRD.md`.

## Testing

Run `swift test` for deterministic, Foundation-only ROI and exposure tests. Keep sensor analysis independent of AVFoundation so it remains testable on a Mac. Build with the command above after app changes. Validate RAW/DNG capability and captures on a physical iPhone; a simulator or generic-device build does not verify camera hardware support.

## Commits and Pull Requests

The repository is newly initialized, so no established commit convention exists. Use short imperative subjects (for example, `Add camera preview`). Pull requests should summarize behavior changes, link the relevant PRD requirements, list build and device validation, and include screenshots for UI changes.

## Privacy

Keep camera access and temporary capture analysis on-device. Preserve a clear `NSCameraUsageDescription` in `wbmeter/Info.plist`; never commit credentials or machine-specific settings. Never replace unsupported sensor data with processed preview RGB.
