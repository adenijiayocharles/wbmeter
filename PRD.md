# WB Meter — Product Requirements Document

**Version:** 1.0
**Platform:** iOS First
**Technology:** Swift / SwiftUI
**Initial Target:** iPhone
**Product Type:** Photography & Videography Utility

---

## 1. Product Overview

**WB Meter** is a mobile application that helps photographers and videographers determine an appropriate manual white-balance setting for their camera.

The user points their iPhone at a neutral grey or white reference card under the same lighting as the subject.

The application measures the light using camera sensor data and colour-science calculations and recommends:

* Correlated Colour Temperature (CCT) in Kelvin
* Green/Magenta tint correction
* Δuv
* Measurement confidence
* Eventually, camera-specific white-balance settings

Example:

```text
Measured Light

Kelvin:     4,480 K
Recommended: 4,500 K
Tint:       Slight Magenta
Δuv:        -0.0021
Confidence: High
```

The application must prioritise **repeatability and measurement accuracy** over visual effects or AI-generated estimates.

---

## 2. Problem

Photographers and videographers frequently need to configure manual white balance.

Common approaches include:

* Auto White Balance
* Guessing Kelvin
* Camera presets such as Daylight or Tungsten
* Photographing a grey card
* Dedicated colour meters

Auto White Balance can vary between shots and between cameras.

Guessing Kelvin is unreliable, particularly with:

* LED lighting
* fluorescent lighting
* mixed lighting
* stage lighting
* RGB/RGBWW fixtures

Dedicated colour meters provide better measurements but introduce additional equipment and can be expensive.

WB Meter aims to provide a convenient measurement tool using hardware photographers already carry: their smartphone.

---

## 3. Product Goal

The primary goal is:

> Measure a neutral target using an iPhone and produce a repeatable estimate of the scene illuminant expressed as CCT (Kelvin) and tint/Δuv.

The application should eventually translate this measurement into practical white-balance settings for specific camera models.

The core product priority is:

```text
Measurement Correctness
        ↓
Repeatability
        ↓
Reliability
        ↓
User Experience
        ↓
Additional Features
```

---

## 4. MVP Non-Goals

Do **not** implement the following in the initial MVP:

* Android
* User accounts
* Backend API
* Laravel backend
* Cloud synchronisation
* Subscriptions
* Social features
* AI/LLM integration
* Image generation
* Automatic skin-tone correction
* Hundreds of camera profiles
* External hardware integration
* Apple Watch
* Photo editing
* Video recording
* Advanced mixed-light detection

The MVP is primarily a **measurement instrument**.

---

## 5. Target Users

Primary users include:

* Photographers
* Videographers
* Filmmakers
* Content creators
* Event videographers
* Church/media teams
* YouTube creators
* Multi-camera production teams

### Example Scenario

A videographer enters a room illuminated by LED fixtures.

Instead of guessing whether the camera should use:

```text
4000K
4500K
5000K
```

the videographer places a neutral grey card where the subject will stand and measures it using WB Meter.

The application returns:

```text
Measured: 4,327 K
Recommended: 4,300 K
Tint: Slight Magenta
Confidence: High
```

The videographer enters the recommended values into their camera.

---

# 6. MVP User Journey

## 6.1 First Launch

The user opens the application.

The application requests camera permission.

After permission is granted, the camera measurement interface appears.

---

## 6.2 Measurement

The user:

1. Places a neutral grey card under the subject lighting.
2. Points the iPhone at the grey card.
3. Positions the grey card inside the measurement target.
4. Taps **Measure**.
5. The app captures appropriate sensor data.
6. The app analyses the neutral target.
7. The app calculates illuminant information.
8. The result screen appears.

Example:

```text
WHITE BALANCE

4,500 K

Tint: Slight Magenta
Δuv: -0.0021

● High Confidence

Measured: 4,482 K

[ Measure Again ]
```

---

# 7. MVP Screens

## 7.1 Camera Measurement Screen

Display:

* Live camera preview
* Central measurement target
* Instructions
* Exposure/measurement status
* Measure button
* Settings button

Example:

```text
┌───────────────────────────────┐
│ WB Meter                      │
│                               │
│                               │
│        ┌─────────────┐        │
│        │             │        │
│        │  GREY CARD  │        │
│        │             │        │
│        └─────────────┘        │
│                               │
│ Place grey card inside target │
│                               │
│         [ MEASURE ]           │
│                               │
└───────────────────────────────┘
```

The central target defines the region used for colour measurement.

The application must **not** calculate the primary grey-card measurement from the entire image.

---

# 8. Measurement Requirements

The measurement engine is the most important component of the application.

The app should use the least-processed sensor information available through Apple's camera APIs.

Where supported, prefer:

* RAW
* DNG
* Linear sensor-derived data
* Camera calibration metadata

over processed:

* JPEG
* HEIC
* screenshots
* preview-frame RGB

The production measurement must **not** derive white balance solely from processed JPEG/HEIC RGB.

The implementation must account for device-specific camera colour behaviour.

---

# 9. Measurement Pipeline

The target architecture is:

```text
RAW / Sensor Measurement
          ↓
Black-Level Correction
          ↓
Normalisation
          ↓
Neutral Target Sampling
          ↓
Sensor Colour Calibration
          ↓
CIE XYZ
          ↓
Chromaticity
          ↓
CIE 1960 UCS
          ↓
Planckian Locus
          ↓
CCT + Δuv
          ↓
Kelvin + User-Friendly Tint
          ↓
Camera-Specific Recommendation
```

Camera-specific recommendations are post-MVP.

The scientific/internal representation must remain separate from UI formatting.

---

# 10. Neutral Region Sampling

The centre measurement target defines a **Region of Interest (ROI)**.

Do not sample a single pixel.

Sample a sufficiently large area.

Suggested initial ROI:

```text
15–25% of image width
15–25% of image height
```

around the centre of the frame.

For each channel calculate robust statistics.

Possible implementation:

1. Extract ROI.
2. Remove clipped pixels.
3. Remove severely underexposed pixels.
4. Reject obvious outliers.
5. Calculate median or trimmed mean.

Output:

```text
R_linear
G_linear
B_linear
```

Example:

```text
R = 0.421
G = 0.516
B = 0.602
```

---

# 11. Exposure Validation

The application must reject measurements when exposure makes the result unreliable.

Detect:

* Clipped highlights
* Severe underexposure
* Excessive noise
* Insufficient usable samples
* Insufficient grey-card coverage

Example:

```text
Measurement Unavailable

Grey card is overexposed.

Reduce exposure or reposition the card
and try again.
```

The application must never display a high-confidence Kelvin value when measurement data is unreliable.

---

# 12. Sensor Calibration

RAW RGB values are device-dependent.

The application must **not** assume:

```text
RAW RGB = sRGB
```

Where available, inspect RAW/DNG metadata for colour calibration information.

Potential metadata includes:

* `ColorMatrix1`
* `ColorMatrix2`
* `CalibrationIlluminant1`
* `CalibrationIlluminant2`
* `CameraCalibration1`
* `CameraCalibration2`
* `AsShotNeutral`
* `AnalogBalance`
* Black level
* White level

The architecture must allow device-specific calibration profiles to later override or augment metadata-derived calibration.

---

# 13. RGB → XYZ

Create a dedicated colour-science module.

Conceptually:

```text
| X |   | m11 m12 m13 | | R |
| Y | = | m21 m22 m23 | | G |
| Z |   | m31 m32 m33 | | B |
```

The transformation matrix must come from appropriate sensor/calibration information.

Do **not** hard-code an arbitrary RGB-to-XYZ matrix intended for sRGB and apply it directly to RAW camera values.

---

# 14. XYZ → Chromaticity

Calculate:

```text
x = X / (X + Y + Z)

y = Y / (X + Y + Z)
```

Represent this using a model such as:

```swift
struct ChromaticityCoordinate {
    let x: Double
    let y: Double
}
```

---

# 15. CIE 1960 UCS

Convert the measured chromaticity into CIE 1960 UCS coordinates.

Represent:

```text
u
v
```

These values will be used for:

* CCT calculation
* Planckian-locus distance
* Δuv calculation

---

# 16. Correlated Colour Temperature

Calculate **Correlated Colour Temperature (CCT)**.

The production implementation should estimate the nearest point on the Planckian locus rather than relying solely on simple RGB/Kelvin approximations.

McCamy's approximation may be implemented for:

* Testing
* Comparison
* Debugging

but should not be treated as the final production accuracy method.

Example internal result:

```text
CCT = 4482.4 K
```

The UI may display:

```text
4,500 K
```

Keep the unrounded value internally.

---

# 17. Δuv

Calculate the signed distance between the measured chromaticity and the Planckian locus.

Store:

```swift
duv: Double
```

Example:

```text
CCT = 4482 K
Δuv = +0.0026
```

Δuv should remain the canonical internal tint representation.

Do **not** assume that a camera manufacturer's tint scale maps directly or linearly to Δuv.

---

# 18. User-Friendly Tint

For the initial MVP, display:

* Tint direction
* Δuv

Possible tint descriptions:

```text
Green
Slight Green
Neutral
Slight Magenta
Magenta
```

Example:

```text
Tint: Slight Green
Δuv: +0.0026
```

Camera-specific tint values will be added after physical calibration.

---

# 19. Confidence Score

Every measurement should have a confidence score.

Potential inputs:

* Target exposure
* Clipping percentage
* ROI uniformity
* Sensor noise
* Sample count
* Measurement stability
* Validity of colour transformation
* Distance from supported CCT range

Internal representation:

```text
0.0 – 1.0
```

Suggested initial UI mapping:

```text
0.85 – 1.00 = High
0.65 – 0.84 = Medium
< 0.65      = Low
```

Thresholds must be configurable rather than deeply hard-coded.

---

# 20. Repeated Measurements

Measurements should be repeatable.

If the phone, grey card and lighting remain unchanged, repeated measurements should produce similar values.

Example:

```text
Measurement 1: 4480K
Measurement 2: 4510K
Measurement 3: 4490K
```

Large unexplained variations should be investigated before expanding the product.

---

# 21. Measurement Stability

The application may collect several samples before presenting the final result.

Example:

```text
Sample 1 → 4470K
Sample 2 → 4500K
Sample 3 → 4490K

Final → 4490K
```

Use median or another robust aggregation technique.

The UI may display:

```text
Measuring…
```

while samples are collected.

---

# 22. Data Models

Create a measurement model similar to:

```swift
struct WBMeasurement: Identifiable, Codable {

    let id: UUID
    let timestamp: Date

    let deviceModel: String

    let rawRed: Double
    let rawGreen: Double
    let rawBlue: Double

    let x: Double
    let y: Double

    let u: Double
    let v: Double

    let cct: Double
    let duv: Double

    let recommendedKelvin: Int

    let confidence: Double
}
```

Do not tightly couple measurement models to SwiftUI views.

---

# 23. Recommended Kelvin

Measured CCT and camera recommendation must remain separate.

Example:

```text
Measured:
4482K

Recommended:
4500K
```

For MVP, Kelvin may be rounded to configurable increments.

Default:

```text
100K
```

Examples:

```text
4482 → 4500
4321 → 4300
5672 → 5700
```

Future camera profiles may define different:

* Kelvin increments
* minimum Kelvin
* maximum Kelvin

---

# 24. Camera Profiles — Post-MVP Architecture

Prepare the data model but do not build a large camera database yet.

Example:

```swift
struct CameraProfile: Codable {

    let manufacturer: String
    let model: String

    let minimumKelvin: Int
    let maximumKelvin: Int
    let kelvinIncrement: Int

    let supportsTintAdjustment: Bool
}
```

Example profile:

```text
Manufacturer: Sony
Model: A6700
Minimum Kelvin: 2500
Maximum Kelvin: 9900
Increment: 100K
Tint Adjustment: Supported
```

Later versions will convert scientific measurements into camera-specific recommendations.

---

# 25. Result Screen

Example:

```text
┌───────────────────────────────┐
│                               │
│        WHITE BALANCE          │
│                               │
│          4,500 K              │
│                               │
│       Slight Magenta          │
│                               │
│      Δuv: -0.0021             │
│                               │
│       ● High Confidence       │
│                               │
│       Measured: 4482K         │
│                               │
│      [ Measure Again ]        │
│                               │
└───────────────────────────────┘
```

The recommended Kelvin value should be the strongest visual element.

---

# 26. Measurement History

MVP should support local measurement history.

Example:

```text
Studio Interview

4500K
Δuv +0.0018

17 Sep 2026 — 14:32
```

Allow users to:

* View measurement
* Rename measurement
* Delete measurement

Use local persistence.

No backend is required.

---

# 27. Technical Architecture

Recommended technologies:

* Swift
* SwiftUI
* AVFoundation
* Core Image
* ImageIO
* Accelerate where appropriate

Architecture:

```text
WBMeter/
│
├── App/
│
├── Camera/
│   ├── CameraManager
│   ├── CaptureSession.swift
│   └── RAWCaptureProcessor.swift
│
├── ColorScience/
│   ├── SensorRGB.swift
│   ├── SensorCalibration.swift
│   ├── XYZConverter.swift
│   ├── ChromaticityConverter.swift
│   ├── CCTCalculator.swift
│   ├── PlanckianLocus.swift
│   └── DuvCalculator.swift
│
├── Measurement/
│   ├── MeasurementEngine.swift
│   ├── ROIAnalyzer.swift
│   ├── ExposureValidator.swift
│   └── ConfidenceCalculator.swift
│
├── Models/
│   ├── WBMeasurement.swift
│   └── CameraProfile.swift
│
├── Persistence/
│   └── MeasurementStore.swift
│
└── UI/
    ├── CameraView.swift
    ├── MeasurementOverlay.swift
    ├── ResultView.swift
    ├── HistoryView.swift
    └── SettingsView.swift
```

Use protocols/interfaces where appropriate so colour algorithms can be unit tested independently from camera hardware.

---

# 28. Measurement Engine Interface

The application should expose a clean internal measurement API.

Conceptually:

```swift
protocol MeasurementEngineProtocol {

    func measure(
        input: MeasurementInput
    ) async throws -> MeasurementResult
}
```

Result:

```swift
struct MeasurementResult {

    let sensorRGB: SensorRGB

    let xyz: XYZColor

    let chromaticity: ChromaticityCoordinate

    let cct: Double

    let duv: Double

    let confidence: Double
}
```

UI code must **not** contain colour-science calculations.

---

# 29. Debug Mode

Implement a developer/debug measurement view.

This is essential during calibration.

Display:

```text
Device
Camera/Lens ID

ISO
Exposure

RAW R
RAW G
RAW B

X
Y
Z

x
y

u
v

CCT

Δuv

Confidence
```

Allow measurement data to be exported as:

* JSON
* CSV

Example JSON:

```json
{
    "device": "iPhone",
    "raw": {
        "r": 0.421,
        "g": 0.516,
        "b": 0.602
    },
    "xy": {
        "x": 0.361,
        "y": 0.349
    },
    "cct": 4482,
    "duv": 0.0026,
    "confidence": 0.93
}
```

This information will later be used for calibration and testing.

---

# 30. Reference Testing

Accuracy claims must not be based solely on visual inspection.

Measurements should eventually be compared against a known reference colour meter.

Create a test dataset containing:

```text
Reference CCT
Reference Δuv
Phone measurement
Phone model
Light type
Repeated measurements
```

Test lighting should eventually include:

* Daylight
* Cloudy daylight
* Shade
* Tungsten
* Warm LED
* Daylight LED
* Bi-colour LED
* Fluorescent
* RGB fixtures
* RGBWW fixtures
* Stage lighting

---

# 31. Accuracy Metrics

Calculate:

## CCT Error

```text
CCT Error = App CCT - Reference CCT
```

## Absolute CCT Error

```text
Absolute Error = abs(App CCT - Reference CCT)
```

## Δuv Error

```text
Δuv Error = App Δuv - Reference Δuv
```

Also calculate repeatability from repeated measurements.

Do not claim professional-meter accuracy until supported by physical testing.

---

# 32. Calibration Dataset

Design the system so future measurements can create records such as:

```swift
struct CalibrationMeasurement {

    let deviceModel: String

    let lightType: String

    let referenceCCT: Double
    let referenceDuv: Double

    let measuredCCT: Double
    let measuredDuv: Double

    let rawRGB: SensorRGB
}
```

This dataset may later be used to produce device-specific correction functions.

---

# 33. Mixed Lighting — Future Feature

Future versions should detect significant colour variation across different image regions.

Example:

```text
Window Side: 6100K

Subject:
4700K

Room LED:
3900K
```

Instead of pretending the entire scene has one correct white balance, display:

```text
⚠ Mixed Lighting Detected
```

The user should eventually be able to select the region or subject that should determine white balance.

Do not implement sophisticated mixed-light analysis in the initial MVP.

---

# 34. Quick Scan — Future Feature

Grey Card mode is the accuracy-first MVP.

Later introduce:

```text
Quick Scan
```

The user points the phone toward a scene without using a grey card.

The application estimates an appropriate white balance.

Quick Scan must be clearly distinguished from calibrated grey-card measurement because its uncertainty will be higher.

---

# 35. Multi-Camera Matching — Future Feature

Allow users to select multiple cameras.

Example measured illuminant:

```text
4470K
Δuv +0.002
```

Selected cameras:

```text
Sony A6700
Sony FX3
Canon R6 II
```

The application provides calibrated recommendations for each camera.

The goal is to make footage from different cameras match more closely.

---

# 36. Privacy

The MVP should operate entirely on-device.

Images captured for measurement should not be uploaded.

Unless explicitly saved by the user, temporary measurement images should be discarded after processing.

No account should be required.

---

# 37. Performance

Target measurement processing:

```text
< 2 seconds
```

under normal conditions.

The camera preview should remain real-time.

The UI must remain responsive while colour calculations occur.

Heavy processing must not execute on the main UI thread.

---

# 38. Error Handling

Handle:

* Camera permission denied
* RAW unavailable
* Unsupported device
* Camera capture failure
* Invalid calibration metadata
* Overexposure
* Underexposure
* Insufficient neutral target
* Invalid colour calculation
* CCT outside supported range

Never silently substitute fabricated measurement values.

---

# 39. Unit Testing

Colour-science code must have unit tests.

Tests should cover:

* RGB → XYZ conversion
* XYZ → xy conversion
* xy → uv conversion
* Planckian locus calculations
* CCT calculation
* Δuv calculation
* Kelvin rounding
* Confidence calculation

Tests should use known numerical reference values where possible.

Camera hardware code must remain separate from mathematical code so the majority of the measurement engine can be tested without an iPhone.

---

# 40. Development Milestones

## Milestone 1 — Camera

Deliver:

* SwiftUI project
* Camera permissions
* Camera preview
* Central grey-card ROI
* Capture/Measure button

No Kelvin calculation required.

### Acceptance Criteria

The application runs on a physical iPhone and displays a functional camera preview with a measurement target.

---

## Milestone 2 — Sensor Measurement

Deliver:

* RAW/DNG-compatible capture where supported
* Metadata inspection
* ROI extraction
* Linear RGB measurement
* Exposure validation

Debug screen must display:

```text
RAW R
RAW G
RAW B
```

---

## Milestone 3 — Colour Science

Implement:

```text
RAW RGB
   ↓
Calibrated XYZ
   ↓
xy
   ↓
uv
   ↓
CCT
   ↓
Δuv
```

Debug screen must display every intermediate result.

---

## Milestone 4 — User Measurement

Deliver:

* Measure workflow
* Kelvin result
* Tint/Δuv
* Confidence
* Invalid-measurement handling
* Measure Again

---

## Milestone 5 — Persistence

Deliver:

* Measurement history
* Rename
* Delete
* JSON debug export
* CSV debug export

---

## Milestone 6 — Physical Validation

Compare application readings against reference measurements across multiple lighting conditions.

Do not aggressively expand the feature set until measurement repeatability and error are understood.

---

# 41. MVP Acceptance Criteria

The MVP is complete when:

* [ ] Application runs on a supported physical iPhone.
* [ ] User can see a live camera preview.
* [ ] User can position a neutral card inside a defined ROI.
* [ ] App obtains suitable RAW/sensor-derived measurement data.
* [ ] App rejects obviously invalid exposure.
* [ ] App calculates XYZ/chromaticity.
* [ ] App calculates CCT.
* [ ] App calculates Δuv.
* [ ] App displays recommended Kelvin.
* [ ] App displays tint information.
* [ ] App displays measurement confidence.
* [ ] User can repeat a measurement.
* [ ] Measurements can be stored locally.
* [ ] Debug information can be exported.
* [ ] Colour calculations have unit tests.
* [ ] Repeated measurements under unchanged lighting demonstrate measurable repeatability.

---

# 42. Critical Engineering Rules

## Rule 1

Do not estimate Kelvin from processed JPEG RGB using simplistic formulas and present it as an accurate measurement.

## Rule 2

Keep these layers separate:

```text
Sensor Measurement
Colour Science
Calibration
Camera Profiles
UI
```

## Rule 3

Preserve unrounded scientific measurements internally.

## Rule 4

Do not fabricate calibration matrices when device calibration information is unavailable.

## Rule 5

Every measurement must include information about reliability/confidence.

## Rule 6

Invalid measurements must produce errors rather than plausible-looking numbers.

## Rule 7

All colour-science algorithms must be testable independently from AVFoundation.

## Rule 8

Prefer established CIE colour-science methods over ad-hoc RGB heuristics.

## Rule 9

Camera manufacturer tint values must not be treated as universally equivalent to Δuv.

## Rule 10

Do not claim accuracy that has not been established against physical reference measurements.

---

# 43. Instructions for Coding Agent

Read this entire PRD before implementation.

Build the application incrementally.

**Do not attempt to generate the entire production application in one implementation pass.**

For each milestone:

1. Read the milestone requirements.
2. Explain the proposed implementation.
3. Implement only that milestone.
4. Ensure the project builds.
5. Run existing tests.
6. Add appropriate tests.
7. Run tests again.
8. Report assumptions and limitations.
9. Stop before proceeding to the next milestone.

Do not replace difficult colour-science requirements with approximate RGB heuristics without explicitly identifying the limitation.

For colour-science algorithms, document the mathematical method or recognised standard being implemented.

The priority is:

> **Measurement correctness > repeatability > reliability > UI polish > additional features**

---

# 44. First Coding Task

Implement **Milestone 1 only**.

Requirements:

```text
SwiftUI
AVFoundation
Physical iPhone support
Camera permission handling
Live rear-camera preview
Central grey-card measurement ROI
Measure button
Clean separation between camera logic and UI
```

Do **not** implement:

```text
Kelvin calculation
CCT calculation
Δuv
RAW processing
RGB → XYZ
Camera profiles
Backend
Authentication
Subscriptions
```

Expected result:

```text
┌───────────────────────────────┐
│ WB Meter                      │
│                               │
│                               │
│        ┌─────────────┐        │
│        │             │        │
│        │             │        │
│        │             │        │
│        └─────────────┘        │
│                               │
│ Place grey card inside target │
│                               │
│         [ MEASURE ]           │
│                               │
└───────────────────────────────┘
```

The project must compile and run on a physical iPhone before proceeding to Milestone 2.

---

# 45. Long-Term Product Direction

Once measurement accuracy has been demonstrated, WB Meter can evolve from a Kelvin meter into a **camera colour-matching platform**.

Potential future capabilities:

* Camera-specific profiles
* Multi-camera matching
* Mixed-light analysis
* Continuous white-balance monitoring
* Saved locations/scenes
* Project-based measurements
* Lighting reports
* Camera presets
* Custom calibration profiles
* Professional calibration workflows
* Quick Scan without grey card

The long-term differentiator should not simply be:

> "Your phone says the light is 4500K."

The value proposition should become:

> **Measure the lighting once and know what white-balance settings to use across your cameras.**
