# WB Meter Delivery TODOs

Track delivery against the two-week phases in [PRD.md, Section 40](PRD.md#40-two-week-development-phases). Each phase is a 10-working-day timebox. A phase is complete only when its exit checks pass; record device models, iOS versions, test results, and known limitations as you go.

## Phase 0 — Camera Foundation

**Status:** Implementation is present; physical-device validation remains open.

- [x] Add the SwiftUI camera screen and camera permission state handling.
- [x] Add the rear-camera preview, central target, instruction, and Measure control.
- [x] Build for a generic iOS device and for the connected iPhone.
- [x] Verify the authorized path, live rear-camera preview, target, and instruction on an iPhone.
- [x] Verify the camera session stops on background and resumes on foreground.
- [ ] Verify the first-launch not-determined prompt on an iPhone.
- [x] Verify the denied state on an iPhone; the app shows its camera-off explanation and an Open Settings action.
- [x] Verify camera access can be restored in iPhone Settings and the live preview resumes.
- [ ] Verify restricted permission handling on an iPhone.
- [x] Record the test device: iPhone 13 (iPhone14,5), iOS 27.0 (24A437).
- [ ] Pass the Phase 0 exit gate.

**Device run:** Signed and launched on iPhone 13 (iPhone14,5), iOS 27.0 (24A437). The live preview showed the monitor feed with the ROI and instruction. Opening Settings removed the camera-use indicator; foregrounding WB Meter restored it and resumed the preview. With Camera permission off, relaunching the app displayed the denied explanation and Open Settings button. After camera access was restored in iPhone Settings, the live rear-camera preview resumed and the camera-use indicator returned. A temporary fresh bundle also opened with camera access already granted, so the not-determined prompt was not observed. Restricted handling remains unverified; the temporary app was removed.

## Phase 1 — Sensor Capture and ROI

- [x] Select the initial physical test candidate and sensor path: iPhone 13 rear-camera Bayer RAW DNG.
- [x] Implement Bayer RAW DNG capture and DNG metadata inspection for black/white levels, calibration tags, ISO, and exposure.
- [ ] Inspect actual captured DNG metadata on a qualifying physical iPhone.
- [x] Extract a centered 20% RAW sensor ROI and calculate normalized linear Bayer-channel medians.
- [x] Reject clipped, underexposed, or insufficient ROI samples with clear errors.
- [x] Add a debug readout for channel values, RAW dimensions, ROI bounds, ISO, exposure, and DNG tags.
- [x] Unit-test ROI bounds, sample statistics, and clipped, dark, invalid, and insufficient sample rejection with deterministic buffers.
- [x] Probe the connected iPhone 13 (iPhone14,5) for Bayer RAW/DNG availability; after configuring the still-photo session preset, runtime reports one Bayer RAW DNG format.
- [ ] On-device, verify metadata and valid, overexposed, and underexposed captures.
- [x] Implement explicit unsupported capture errors without a processed-RGB fallback.
- [ ] Pass the Phase 1 exit gate.

**Device run:** On iPhone 13 (iPhone14,5), iOS 27.0 (24A437), the runtime now advertises one Bayer RAW DNG format after configuring the photo session preset. Before that change the video-oriented `.high` preset exposed none. A real RAW capture is still needed to validate DNG metadata and the valid/overexposed/underexposed paths. Support only devices that advertise Bayer RAW and DNG and produce a capture with usable black/white levels; never fall back to preview RGB. Phase 1 remains open pending those physical checks.

## Phase 2 — Calibration and XYZ

- [ ] Document supported calibration metadata combinations.
- [ ] Parse capture calibration metadata and convert linear sensor values to XYZ.
- [ ] Return explicit errors for missing or invalid calibration; do not invent a matrix.
- [ ] Unit-test metadata parsing, matrix application, invalid inputs, and known XYZ fixtures.
- [ ] Verify finite XYZ output from a physical capture on the supported iPhone.
- [ ] Document unsupported devices and capture modes.
- [ ] Pass the Phase 2 exit gate.

## Phase 3 — Chromaticity, CCT, Δuv, and Kelvin Rounding

- [ ] Implement XYZ → xy → CIE 1960 uv conversion.
- [ ] Implement nearest supported Planckian-locus CCT and signed Δuv calculations.
- [ ] Implement configurable recommended-Kelvin rounding; retain unrounded internal values.
- [ ] Document methods, references, and supported CCT range.
- [ ] Unit-test transforms, CCT, Δuv, range errors, and rounding against traceable reference values.
- [ ] Pass the deterministic test suite without AVFoundation or an iPhone.
- [ ] Pass the Phase 3 exit gate.

## Phase 4 — Measurement Workflow and Confidence

- [ ] Connect Measure to the sensor measurement pipeline.
- [ ] Collect and robustly aggregate repeated samples.
- [ ] Validate exposure and target coverage; reject invalid readings.
- [ ] Add configurable confidence scoring and result, tint/Δuv, and error states.
- [ ] Add Measure Again.
- [ ] Unit-test aggregation, confidence thresholds, invalid results, and workflow states.
- [ ] On-device, verify valid, invalid-exposure, unsupported-calibration, repeat, and retry flows.
- [ ] Confirm processing stays off the main thread and preview remains responsive.
- [ ] Pass the Phase 4 exit gate.

## Phase 5 — Local History and Debug Export

- [ ] Persist measurements on-device.
- [ ] Implement history view, measurement view, rename, and delete.
- [ ] Export documented measurement data as JSON and CSV.
- [ ] Test persistence across relaunch, rename/delete, export contents, and older or malformed records.
- [ ] On-device, save a measurement, relaunch, and verify history and both exports.
- [ ] Confirm images and readings remain on-device.
- [ ] Pass the Phase 5 exit gate.

## Phase 6 — Physical Validation and MVP Release Gate

- [ ] Agree numerical CCT, Δuv, and repeatability tolerances before collecting release data.
- [ ] Using a known colour meter and the first supported iPhone, test daylight, tungsten, warm LED, and daylight LED.
- [ ] Collect at least three repeated readings for each light type (12 readings minimum).
- [ ] Record phone, iOS version, capture mode, reference readings, and app results.
- [ ] Calculate CCT/Δuv error and repeatability; investigate and document outliers and limits.
- [ ] Re-run automated tests and the fixed physical test matrix.
- [ ] Pass the agreed accuracy and repeatability gates; make no unsupported professional-accuracy claims.
- [ ] Pass the Phase 6 exit gate and MVP acceptance criteria in [PRD.md, Section 41](PRD.md#41-mvp-acceptance-criteria).
