import AVFoundation
import Foundation

/// Owns every AVCaptureSession mutation and runs session work on one serial queue.
final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.wbmeter.camera-session")
    // Accessed only on `queue`.
    private var isConfigured = false

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    if !isConfigured {
                        try configureSession()
                    }
                    if !session.isRunning {
                        session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
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
        session.sessionPreset = .high

        guard session.canAddInput(input) else {
            throw CameraError.cannotAddCameraInput
        }
        session.addInput(input)

        // This milestone displays a preview only; no capture output is attached.
        isConfigured = true
    }

    private enum CameraError: LocalizedError {
        case rearCameraUnavailable
        case cannotAddCameraInput

        var errorDescription: String? {
            switch self {
            case .rearCameraUnavailable:
                "WB Meter could not find a rear-facing camera."
            case .cannotAddCameraInput:
                "WB Meter could not configure the rear camera."
            }
        }
    }
}
