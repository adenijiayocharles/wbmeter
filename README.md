# WB Meter

WB Meter is an iPhone white-balance measurement app. The product requirements and planned milestones are documented in [`PRD.md`](PRD.md); screen references and design prototypes are in [`design/`](design/).

## Current Status

Phase 1 adds on-device Bayer RAW DNG capture and linear sensor-channel sampling within a centered ROI. It does not calculate Kelvin, CCT, Δuv, or confidence, and it does not save or upload captures. Camera settings remain a placeholder.

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

Run the deterministic ROI and exposure tests from the repository root:

```sh
swift test
```

## Camera Architecture

- `CameraService.swift` checks camera authorization and publishes app-facing camera state.
- `CameraSessionController.swift` configures and starts or stops the AVFoundation capture session on a serial queue.
- `RawPhotoCapture.swift` requests Bayer RAW DNG data, reads capture/DNG metadata, and analyzes the raw buffer without saving the image.
- `SensorROIAnalyzer.swift` extracts a centered 20% sensor ROI, normalizes Bayer samples using DNG black/white levels, reports channel medians, and rejects invalid exposure.
- `CameraPreview.swift` displays the session using `AVCaptureVideoPreviewLayer`.
- `ContentView.swift` contains the permission prompts, measurement target, instructions, and controls.

The app declares `NSCameraUsageDescription` in `wbmeter/Info.plist`. Capture requires a rear camera that advertises Bayer RAW and DNG support. Unsupported paths show an error and never fall back to processed preview RGB. Captures and analysis remain on-device.

## Validation

The generic iOS build checks compilation only. Verify camera behavior on a physical iPhone; the simulator does not provide a normal camera feed. `swift test` runs the deterministic, Foundation-only ROI/exposure suite without camera hardware.
