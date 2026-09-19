# WB Meter

WB Meter is an iPhone white-balance measurement app. The product requirements and planned milestones are documented in [`PRD.md`](PRD.md); screen references and design prototypes are in [`design/`](design/).

## Current Status

Milestone 1 provides a SwiftUI camera screen with camera permission handling, a live rear-camera preview, a central grey-card target, instructions, and a Measure control. The Measure control is a placeholder: this milestone does not capture images or calculate measurements. Settings are also a placeholder.

## Requirements

- Xcode with the iOS SDK
- An iPhone with a rear-facing camera for live camera validation

## Build

Build the iOS device target from the repository root:

```sh
xcodebuild -project wbmeter.xcodeproj \
  -scheme wbmeter \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

To install and run the app, open `wbmeter.xcodeproj` in Xcode, select a connected iPhone, configure signing for your Apple developer team, and run the `wbmeter` scheme. The app requests camera permission on first launch. If permission was denied, enable it in iOS Settings and return to the app.

## Camera Architecture

- `CameraService.swift` checks camera authorization and publishes app-facing camera state.
- `CameraSessionController.swift` configures and starts or stops the AVFoundation capture session on a serial queue.
- `CameraPreview.swift` displays the session using `AVCaptureVideoPreviewLayer`.
- `ContentView.swift` contains the permission prompts, measurement target, instructions, and controls.

The app declares `NSCameraUsageDescription` in `wbmeter/Info.plist`. It attaches no capture output and does not save or upload images.

## Validation

The generic iOS build checks compilation only. Verify the permission prompt, live rear-camera preview, target overlay, and app foreground/background behavior on a physical iPhone. The simulator does not provide a normal camera feed. No automated test target exists yet.
