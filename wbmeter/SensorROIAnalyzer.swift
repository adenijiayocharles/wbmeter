import Foundation

nonisolated enum BayerPattern: Sendable {
    case rggb
    case bggr
    case grbg
    case gbrg

    func channel(x: Int, y: Int) -> SensorChannel {
        switch self {
        case .rggb:
            return y.isMultiple(of: 2)
                ? (x.isMultiple(of: 2) ? .red : .green)
                : (x.isMultiple(of: 2) ? .green : .blue)
        case .bggr:
            return y.isMultiple(of: 2)
                ? (x.isMultiple(of: 2) ? .blue : .green)
                : (x.isMultiple(of: 2) ? .green : .red)
        case .grbg:
            return y.isMultiple(of: 2)
                ? (x.isMultiple(of: 2) ? .green : .red)
                : (x.isMultiple(of: 2) ? .blue : .green)
        case .gbrg:
            return y.isMultiple(of: 2)
                ? (x.isMultiple(of: 2) ? .green : .blue)
                : (x.isMultiple(of: 2) ? .red : .green)
        }
    }
}

nonisolated enum SensorChannel: CaseIterable, Sendable {
    case red
    case green
    case blue
}

nonisolated struct SensorROI: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

nonisolated struct SensorChannelStatistics: Equatable, Sendable {
    let median: Double
    let sampleCount: Int
}

nonisolated struct SensorROIStatistics: Equatable, Sendable {
    let roi: SensorROI
    let red: SensorChannelStatistics
    let green: SensorChannelStatistics
    let blue: SensorChannelStatistics
    let clippedFraction: Double
    let underexposedFraction: Double
}

nonisolated enum SensorROIError: Error, Equatable, Sendable, LocalizedError {
    case invalidDimensions
    case invalidRegion
    case invalidLevels
    case overexposed
    case underexposed
    case insufficientSamples(SensorChannel)

    var errorDescription: String? {
        switch self {
        case .invalidDimensions:
            "The RAW capture has invalid dimensions."
        case .invalidRegion:
            "The measurement region is invalid."
        case .invalidLevels:
            "RAW black or white level metadata is missing or invalid."
        case .overexposed:
            "The measurement area is clipped. Reduce exposure and try again."
        case .underexposed:
            "The measurement area is too dark. Increase exposure and try again."
        case .insufficientSamples(let channel):
            "The RAW capture has too few usable \(channel.name) sensor samples."
        }
    }
}

nonisolated struct SensorROIAnalyzer: Sendable {
    var roiWidthFraction = 0.20
    var roiHeightFraction = 0.20
    var clippedThreshold = 0.995
    var underexposedThreshold = 0.01
    var maximumClippedFraction = 0.10
    var maximumUnderexposedFraction = 0.90
    var minimumSamplesPerChannel = 32

    func analyze(
        width: Int,
        height: Int,
        pattern: BayerPattern,
        blackLevels: [Double],
        whiteLevel: Double,
        pixelValue: (Int, Int) -> UInt16
    ) throws -> SensorROIStatistics {
        guard width > 0, height > 0 else { throw SensorROIError.invalidDimensions }
        guard roiWidthFraction > 0, roiWidthFraction <= 1,
              roiHeightFraction > 0, roiHeightFraction <= 1 else {
            throw SensorROIError.invalidRegion
        }
        guard blackLevels.count == 4,
              blackLevels.allSatisfy(\.isFinite),
              blackLevels.allSatisfy({ $0 >= 0 && $0 < whiteLevel }),
              whiteLevel.isFinite,
              whiteLevel > 0 else {
            throw SensorROIError.invalidLevels
        }

        let roiWidth = max(1, Int((Double(width) * roiWidthFraction).rounded(.down)))
        let roiHeight = max(1, Int((Double(height) * roiHeightFraction).rounded(.down)))
        let roi = SensorROI(
            x: (width - roiWidth) / 2,
            y: (height - roiHeight) / 2,
            width: roiWidth,
            height: roiHeight
        )

        var channelValues: [SensorChannel: [Double]] = Dictionary(
            uniqueKeysWithValues: SensorChannel.allCases.map { ($0, []) }
        )
        let totalPixelCount = roiWidth * roiHeight
        var clippedCount = 0
        var underexposedCount = 0

        for y in roi.y..<(roi.y + roi.height) {
            for x in roi.x..<(roi.x + roi.width) {
                let levelIndex = (y % 2) * 2 + (x % 2)
                let blackLevel = blackLevels[levelIndex]
                let sample = Double(pixelValue(x, y))
                let normalized = (sample - blackLevel) / (whiteLevel - blackLevel)

                if normalized >= clippedThreshold {
                    clippedCount += 1
                    continue
                }
                if normalized <= underexposedThreshold {
                    underexposedCount += 1
                    continue
                }

                let channel = pattern.channel(x: x, y: y)
                channelValues[channel, default: []].append(normalized)
            }
        }

        let clippedFraction = Double(clippedCount) / Double(totalPixelCount)
        let underexposedFraction = Double(underexposedCount) / Double(totalPixelCount)
        if clippedFraction > maximumClippedFraction { throw SensorROIError.overexposed }
        if underexposedFraction > maximumUnderexposedFraction { throw SensorROIError.underexposed }

        func statistics(for channel: SensorChannel) throws -> SensorChannelStatistics {
            var values = channelValues[channel, default: []]
            guard values.count >= minimumSamplesPerChannel else {
                throw SensorROIError.insufficientSamples(channel)
            }
            values.sort()
            let midpoint = values.count / 2
            let median = values.count.isMultiple(of: 2)
                ? (values[midpoint - 1] + values[midpoint]) / 2
                : values[midpoint]
            return SensorChannelStatistics(median: median, sampleCount: values.count)
        }

        return try SensorROIStatistics(
            roi: roi,
            red: statistics(for: .red),
            green: statistics(for: .green),
            blue: statistics(for: .blue),
            clippedFraction: clippedFraction,
            underexposedFraction: underexposedFraction
        )
    }
}

nonisolated private extension SensorChannel {
    var name: String {
        switch self {
        case .red: "red"
        case .green: "green"
        case .blue: "blue"
        }
    }
}
