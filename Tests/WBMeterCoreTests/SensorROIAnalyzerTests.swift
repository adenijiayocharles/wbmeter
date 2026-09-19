import XCTest
@testable import WBMeterCore

final class SensorROIAnalyzerTests: XCTestCase {
    func testUsesCenteredTwentyPercentROIAndReturnsChannelMedians() throws {
        let analyzer = SensorROIAnalyzer(minimumSamplesPerChannel: 32)
        let result = try analyzer.analyze(
            width: 100,
            height: 50,
            pattern: .rggb,
            blackLevels: [64, 64, 64, 64],
            whiteLevel: 16_383,
            pixelValue: { x, y in
                let value: Double
                switch BayerPattern.rggb.channel(x: x, y: y) {
                case .red: value = 0.25
                case .green: value = 0.50
                case .blue: value = 0.75
                }
                return UInt16((64 + value * (16_383 - 64)).rounded())
            }
        )

        XCTAssertEqual(result.roi, SensorROI(x: 40, y: 20, width: 20, height: 10))
        XCTAssertEqual(result.red.median, 0.25, accuracy: 0.001)
        XCTAssertEqual(result.green.median, 0.50, accuracy: 0.001)
        XCTAssertEqual(result.blue.median, 0.75, accuracy: 0.001)
        XCTAssertEqual(result.red.sampleCount, 50)
        XCTAssertEqual(result.green.sampleCount, 100)
        XCTAssertEqual(result.blue.sampleCount, 50)
    }

    func testRejectsClippedROI() {
        let analyzer = SensorROIAnalyzer(minimumSamplesPerChannel: 1)
        XCTAssertThrowsError(try analyzer.analyze(
            width: 20,
            height: 20,
            pattern: .rggb,
            blackLevels: [0, 0, 0, 0],
            whiteLevel: 16_383,
            pixelValue: { _, _ in 16_383 }
        )) { XCTAssertEqual($0 as? SensorROIError, .overexposed) }
    }

    func testRejectsUnderexposedROI() {
        let analyzer = SensorROIAnalyzer(minimumSamplesPerChannel: 1)
        XCTAssertThrowsError(try analyzer.analyze(
            width: 20,
            height: 20,
            pattern: .rggb,
            blackLevels: [64, 64, 64, 64],
            whiteLevel: 16_383,
            pixelValue: { _, _ in 64 }
        )) { XCTAssertEqual($0 as? SensorROIError, .underexposed) }
    }

    func testRejectsInsufficientPerChannelSamples() {
        let analyzer = SensorROIAnalyzer(minimumSamplesPerChannel: 100)
        XCTAssertThrowsError(try analyzer.analyze(
            width: 10,
            height: 10,
            pattern: .rggb,
            blackLevels: [0, 0, 0, 0],
            whiteLevel: 1_000,
            pixelValue: { _, _ in 500 }
        )) { XCTAssertEqual($0 as? SensorROIError, .insufficientSamples(.red)) }
    }

    func testRejectsInvalidDimensionsAndMetadataLevels() {
        let analyzer = SensorROIAnalyzer()
        XCTAssertThrowsError(try analyzer.analyze(
            width: 0, height: 4, pattern: .rggb,
            blackLevels: [0, 0, 0, 0], whiteLevel: 100,
            pixelValue: { _, _ in 50 }
        )) { XCTAssertEqual($0 as? SensorROIError, .invalidDimensions) }
        XCTAssertThrowsError(try analyzer.analyze(
            width: 4, height: 4, pattern: .rggb,
            blackLevels: [0, 0], whiteLevel: 100,
            pixelValue: { _, _ in 50 }
        )) { XCTAssertEqual($0 as? SensorROIError, .invalidLevels) }
    }
}
