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
- [ ] Verify the denied state and Settings recovery path on an iPhone.
- [ ] Verify restricted permission handling on an iPhone.
- [x] Record the test device: iPhone 13 (iPhone14,5), iOS 27.0 (24A437).
- [ ] Pass the Phase 0 exit gate.

**Device run:** Signed and launched on iPhone 13 (iPhone14,5), iOS 27.0 (24A437). The live preview showed the monitor feed with the ROI and instruction. Opening Settings removed the camera-use indicator; foregrounding WB Meter restored it and resumed the preview. The app’s Camera switch was on in Settings. A temporary fresh bundle also opened with camera access already granted, so the not-determined prompt was not observed. Denied and restricted runtime states remain unverified; the temporary app was removed.

## Phase 1 — Sensor Capture and ROI

- [ ] Select and record the first supported iPhone model and sensor capture path.
- [ ] Implement capture and inspect available RAW/DNG and calibration metadata.
- [ ] Extract a centered ROI and calculate linear sensor-channel statistics.
- [ ] Reject clipped, underexposed, or insufficient ROI samples with clear errors.
- [ ] Add a debug readout for channel values and exposure.
- [ ] Unit-test ROI bounds, sample statistics, and invalid-pixel rejection with deterministic buffers.
- [ ] On-device, verify metadata and valid, overexposed, and underexposed captures.
- [ ] Confirm unsupported capture paths report an error without a processed-RGB fallback.
- [ ] Pass the Phase 1 exit gate.

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
