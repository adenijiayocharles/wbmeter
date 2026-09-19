import AVFoundation
import Foundation

/// Owns every AVCaptureSession mutation and runs session work on one serial queue.
final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.wbmeter.camera-session")
    private let photoOutput = AVCapturePhotoOutput()
    // Accessed only on `queue`.
    private var isConfigured = false
    private var activeCaptures: [Int64: RawPhotoCapture] = [:]

    func start() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    if !isConfigured {
                        try configureSession()
                    }
                    if !session.isRunning {
                        session.startRunning()
                    }
                    continuation.resume(returning: captureCapability)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func captureRawMeasurement() async throws -> SensorCaptureDiagnostics {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: SensorCaptureError.cameraNotRunning)
                    return
                }

                guard let rawPixelFormat = photoOutput.availableRawPhotoPixelFormatTypes.first(
                    where: AVCapturePhotoOutput.isBayerRAWPixelFormat
                ) else {
                    continuation.resume(throwing: SensorCaptureError.rawCaptureUnsupported)
                    return
                }
                guard photoOutput.availableRawPhotoFileTypes.contains(.dng) else {
                    continuation.resume(throwing: SensorCaptureError.dngUnavailable)
                    return
                }

                let settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawPixelFormat,
                    rawFileType: .dng,
                    processedFormat: nil,
                    processedFileType: nil
                )
                let captureID = settings.uniqueID
                let processor = RawPhotoCapture { [weak self] result in
                    continuation.resume(with: result)
                    self?.queue.async {
                        self?.activeCaptures[captureID] = nil
                    }
                }
                activeCaptures[captureID] = processor
                photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    private func configureSession() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.rearCameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard session.canAddInput(input) else {
            throw CameraError.cannotAddCameraInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddPhotoOutput
        }
        session.addOutput(photoOutput)

        isConfigured = true
    }

    private var captureCapability: String {
        let formats = photoOutput.availableRawPhotoPixelFormatTypes.filter(
            AVCapturePhotoOutput.isBayerRAWPixelFormat
        )
        guard !formats.isEmpty else { return "Bayer RAW unavailable" }
        guard photoOutput.availableRawPhotoFileTypes.contains(.dng) else {
            return "Bayer RAW available; DNG unavailable"
        }
        return "Bayer RAW DNG available (\(formats.count) format\(formats.count == 1 ? "" : "s"))"
    }

    private enum CameraError: LocalizedError {
        case rearCameraUnavailable
        case cannotAddCameraInput
        case cannotAddPhotoOutput

        var errorDescription: String? {
            switch self {
            case .rearCameraUnavailable:
                "WB Meter could not find a rear-facing camera."
            case .cannotAddCameraInput:
                "WB Meter could not configure the rear camera."
            case .cannotAddPhotoOutput:
                "WB Meter could not configure RAW photo capture."
            }
        }
    }
}
