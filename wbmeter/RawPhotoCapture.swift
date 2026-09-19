import AVFoundation
import CoreVideo
import Foundation
import ImageIO

nonisolated struct SensorCaptureDiagnostics: Equatable, Sendable {
    let statistics: SensorROIStatistics
    let rawWidth: Int
    let rawHeight: Int
    let iso: Double?
    let exposureSeconds: Double?
    let pixelFormat: String
    let metadataSummary: String
}

nonisolated enum SensorCaptureError: Error, Equatable, Sendable, LocalizedError {
    case cameraNotRunning
    case rawCaptureUnsupported
    case dngUnavailable
    case captureFailed(String)
    case missingRawPixels
    case unsupportedBayerFormat
    case dngMetadataUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraNotRunning:
            "The camera is not ready. Try again when the live preview is active."
        case .rawCaptureUnsupported:
            "This rear camera does not provide Bayer RAW capture. No processed-image fallback was used."
        case .dngUnavailable:
            "This rear camera does not provide DNG output for Bayer RAW captures."
        case .captureFailed(let detail):
            "RAW capture failed: \(detail)"
        case .missingRawPixels:
            "The camera returned no RAW sensor pixels."
        case .unsupportedBayerFormat:
            "The camera returned an unsupported Bayer RAW pixel format."
        case .dngMetadataUnavailable:
            "The DNG is missing the black or white level metadata needed to normalize sensor values."
        }
    }
}

/// Captures one Bayer RAW DNG in memory and analyzes its sensor buffer; it never writes an image to disk.
nonisolated final class RawPhotoCapture: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<SensorCaptureDiagnostics, any Error>) -> Void
    private let completionLock = NSLock()
    private var didComplete = false

    init(completion: @escaping @Sendable (Result<SensorCaptureDiagnostics, any Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            finish(.failure(SensorCaptureError.captureFailed(error.localizedDescription)))
            return
        }

        do {
            finish(.success(try Self.analyze(photo)))
        } catch let error as SensorROIError {
            finish(.failure(error))
        } catch let error as SensorCaptureError {
            finish(.failure(error))
        } catch {
            finish(.failure(SensorCaptureError.captureFailed(error.localizedDescription)))
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        if let error {
            finish(.failure(SensorCaptureError.captureFailed(error.localizedDescription)))
        }
    }

    private func finish(_ result: Result<SensorCaptureDiagnostics, any Error>) {
        completionLock.lock()
        defer { completionLock.unlock() }
        guard !didComplete else { return }
        didComplete = true
        completion(result)
    }

    private static func analyze(_ photo: AVCapturePhoto) throws -> SensorCaptureDiagnostics {
        guard let pixelBuffer = photo.pixelBuffer else { throw SensorCaptureError.missingRawPixels }
        guard photo.isRawPhoto else { throw SensorCaptureError.missingRawPixels }
        guard let pattern = bayerPattern(for: CVPixelBufferGetPixelFormatType(pixelBuffer)) else {
            throw SensorCaptureError.unsupportedBayerFormat
        }
        guard let data = photo.fileDataRepresentation(),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let dng = properties[kCGImagePropertyDNGDictionary as String] as? [String: Any],
              let blackLevels = numericArray(dng[kCGImagePropertyDNGBlackLevel as String]),
              let whiteLevels = numericArray(dng[kCGImagePropertyDNGWhiteLevel as String]),
              let whiteLevel = whiteLevels.first else {
            throw SensorCaptureError.dngMetadataUnavailable
        }

        let fourBlackLevels: [Double]
        if blackLevels.count == 1 {
            fourBlackLevels = Array(repeating: blackLevels[0], count: 4)
        } else if blackLevels.count == 4 {
            fourBlackLevels = blackLevels
        } else {
            throw SensorCaptureError.dngMetadataUnavailable
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw SensorCaptureError.missingRawPixels
        }

        let pixels = baseAddress.assumingMemoryBound(to: UInt16.self)
        let statistics = try SensorROIAnalyzer().analyze(
            width: width,
            height: height,
            pattern: pattern,
            blackLevels: fourBlackLevels,
            whiteLevel: whiteLevel
        ) { x, y in
            // CoreVideo Bayer RAW samples are 14-bit values stored in 16-bit little-endian elements.
            pixels[(y * bytesPerRow / MemoryLayout<UInt16>.stride) + x] & 0x3FFF
        }

        let exif = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let iso = numericArray(exif[kCGImagePropertyExifISOSpeedRatings as String])?.first
        let exposure = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
        let inspectedKeys = [
            kCGImagePropertyDNGBlackLevel,
            kCGImagePropertyDNGWhiteLevel,
            kCGImagePropertyDNGColorMatrix1,
            kCGImagePropertyDNGColorMatrix2,
            kCGImagePropertyDNGCalibrationIlluminant1,
            kCGImagePropertyDNGCalibrationIlluminant2,
            kCGImagePropertyDNGAsShotNeutral,
            kCGImagePropertyDNGAnalogBalance
        ]
        let availableMetadata = inspectedKeys
            .filter { dng[$0 as String] != nil }
            .map { $0 as String }
            .joined(separator: ", ")
        let format = pixelFormatDescription(CVPixelBufferGetPixelFormatType(pixelBuffer))

        return SensorCaptureDiagnostics(
            statistics: statistics,
            rawWidth: width,
            rawHeight: height,
            iso: iso,
            exposureSeconds: exposure,
            pixelFormat: format,
            metadataSummary: availableMetadata.isEmpty ? "No DNG calibration tags found" : availableMetadata
        )
    }

    private static func numericArray(_ value: Any?) -> [Double]? {
        if let number = value as? NSNumber { return [number.doubleValue] }
        if let values = value as? [NSNumber] { return values.map(\.doubleValue) }
        if let values = value as? [Double] { return values }
        return nil
    }

    private static func bayerPattern(for type: OSType) -> BayerPattern? {
        switch type {
        case kCVPixelFormatType_14Bayer_RGGB: .rggb
        case kCVPixelFormatType_14Bayer_BGGR: .bggr
        case kCVPixelFormatType_14Bayer_GRBG: .grbg
        case kCVPixelFormatType_14Bayer_GBRG: .gbrg
        default: nil
        }
    }

    private static func pixelFormatDescription(_ type: OSType) -> String {
        switch type {
        case kCVPixelFormatType_14Bayer_RGGB: "14-bit Bayer RGGB"
        case kCVPixelFormatType_14Bayer_BGGR: "14-bit Bayer BGGR"
        case kCVPixelFormatType_14Bayer_GRBG: "14-bit Bayer GRBG"
        case kCVPixelFormatType_14Bayer_GBRG: "14-bit Bayer GBRG"
        default: "Unknown Bayer format"
        }
    }
}

nonisolated extension SensorCaptureDiagnostics {
    var debugLines: [String] {
        let roi = statistics.roi
        var lines = [
            "RAW DNG · \(pixelFormat) · \(rawWidth)×\(rawHeight)",
            "ROI \(roi.x),\(roi.y) · \(roi.width)×\(roi.height)",
            "R \(statistics.red.median.formatted(.number.precision(.fractionLength(3))))  " +
                "G \(statistics.green.median.formatted(.number.precision(.fractionLength(3))))  " +
                "B \(statistics.blue.median.formatted(.number.precision(.fractionLength(3))))"
        ]

        let exposureDetails = [
            iso.map { "ISO \(Int($0.rounded()))" },
            exposureSeconds.flatMap { seconds in
                guard seconds.isFinite, seconds > 0 else { return nil }
                return seconds >= 1
                    ? "\(seconds.formatted(.number.precision(.fractionLength(1)))) s"
                    : "1/\(Int((1 / seconds).rounded())) s"
            }
        ].compactMap { $0 }
        if !exposureDetails.isEmpty { lines.append(exposureDetails.joined(separator: " · ")) }
        lines.append("DNG tags: \(metadataSummary)")
        return lines
    }
}
