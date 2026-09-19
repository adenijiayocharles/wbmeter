import AVFoundation
import Combine
import Foundation

@MainActor
final class CameraService: ObservableObject {
    enum Authorization: Equatable {
        case notDetermined
        case authorized
        case denied
        case restricted
        case unavailable
        case failed(String)
    }

    @Published private(set) var authorization: Authorization = .notDetermined
    @Published private(set) var isRunning = false
    @Published private(set) var captureCapability = "Checking RAW support"
    @Published private(set) var captureMessage: String?
    @Published private(set) var captureDiagnostics: SensorCaptureDiagnostics?
    @Published private(set) var isCapturing = false

    private let camera = CameraSessionController()
    var session: AVCaptureSession { camera.session }

    var statusText: String {
        switch authorization {
        case .authorized: isRunning ? "Live camera" : "Starting camera"
        case .notDetermined: "Camera permission"
        case .denied, .restricted, .unavailable, .failed: "Camera unavailable"
        }
    }

    var statusSymbol: String {
        isRunning ? "video.fill" : "video.slash.fill"
    }

    var promptSymbol: String {
        switch authorization {
        case .denied: "video.slash"
        case .restricted: "lock.fill"
        case .unavailable, .failed: "exclamationmark.camera"
        case .notDetermined, .authorized: "camera.fill"
        }
    }

    var promptTitle: String {
        switch authorization {
        case .notDetermined: "Camera access is needed"
        case .denied: "Camera access is off"
        case .restricted: "Camera access is restricted"
        case .unavailable: "Camera unavailable"
        case .failed: "Could not start the camera"
        case .authorized: "Starting camera…"
        }
    }

    var promptMessage: String {
        switch authorization {
        case .notDetermined:
            "Allow camera access to see a live preview and position your grey card."
        case .denied:
            "Allow camera access in Settings to use the live preview."
        case .restricted:
            "Camera access is restricted on this device and cannot be changed here."
        case .unavailable:
            "This device does not have an available rear camera."
        case let .failed(message):
            message
        case .authorized:
            "Preparing the rear camera preview."
        }
    }

    func requestAccessAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        case .denied:
            authorization = .denied
        case .restricted:
            authorization = .restricted
        @unknown default:
            authorization = .unavailable
        }

        guard authorization == .authorized else {
            await camera.stop()
            isRunning = false
            return
        }

        do {
            captureCapability = try await camera.start()
            isRunning = true
        } catch {
            authorization = .failed(error.localizedDescription)
            isRunning = false
        }
    }

    func captureMeasurement() async {
        guard isRunning, !isCapturing else { return }
        isCapturing = true
        captureMessage = "Capturing RAW sensor data…"
        captureDiagnostics = nil

        do {
            captureDiagnostics = try await camera.captureRawMeasurement()
            captureMessage = nil
        } catch {
            captureMessage = error.localizedDescription
        }
        isCapturing = false
    }

    func stop() {
        Task {
            await camera.stop()
            isRunning = false
        }
    }
}
