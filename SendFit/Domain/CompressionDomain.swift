import Foundation

struct VideoDimensions: Equatable, Sendable {
    let width: Int
    let height: Int

    var displayName: String { "\(width) × \(height)" }
}

struct CompressionSourceInfo: Equatable, Sendable {
    let duration: TimeInterval
    let width: Int
    let height: Int
    let frameRate: Double
    let hasAudio: Bool
}

struct CompressionRequest: Equatable, Sendable {
    let targetSizeBytes: Int64
}

struct CompressionPlan: Equatable, Sendable {
    let videoBitrate: Int
    let audioBitrate: Int
    let outputSize: VideoDimensions
    let outputFrameRate: Double
    let safetyMarginBitrate: Int
}

enum CompressionPlanningError: Error, Equatable, LocalizedError, Sendable {
    case invalidDuration
    case targetTooSmall

    var errorDescription: String? {
        switch self {
        case .invalidDuration: "The video duration could not be determined."
        case .targetTooSmall: "This video is too long to fit into that size at a usable quality. Try a larger target size."
        }
    }
}

struct CompressionEstimator: Sendable {
    static let safetyMarginFraction = 0.152
    static let minimumVideoBitrate = 150_000
    static let minimumAudioBitrate = 32_000

    func makePlan(for request: CompressionRequest, source: CompressionSourceInfo) throws -> CompressionPlan {
        guard source.duration > 0 else { throw CompressionPlanningError.invalidDuration }
        let totalBitrate = Int((Double(request.targetSizeBytes) * 8 / source.duration).rounded(.down))
        let audioBitrate = source.hasAudio ? selectedAudioBitrate(totalBitrate: totalBitrate) : 0
        let safetyMargin = Int((Double(totalBitrate) * Self.safetyMarginFraction).rounded(.up))
        let videoBitrate = totalBitrate - audioBitrate - safetyMargin
        guard videoBitrate >= Self.minimumVideoBitrate else { throw CompressionPlanningError.targetTooSmall }

        return CompressionPlan(
            videoBitrate: videoBitrate,
            audioBitrate: audioBitrate,
            outputSize: selectedDimensions(source: source, videoBitrate: videoBitrate),
            outputFrameRate: selectedFrameRate(source.frameRate),
            safetyMarginBitrate: safetyMargin
        )
    }

    func correctedVideoBitrate(previousBitrate: Int, targetSizeBytes: Int64, actualSizeBytes: Int64) -> Int {
        guard actualSizeBytes > 0 else { return previousBitrate }
        let correction = Double(targetSizeBytes) / Double(actualSizeBytes) * 0.95
        return max(Self.minimumVideoBitrate, Int((Double(previousBitrate) * correction).rounded(.down)))
    }

    private func selectedAudioBitrate(totalBitrate: Int) -> Int {
        switch totalBitrate {
        case 1_500_000...: 128_000
        case 700_000...: 96_000
        case 250_000...: 64_000
        case 180_000...: Self.minimumAudioBitrate
        default: 0
        }
    }

    private func selectedDimensions(source: CompressionSourceInfo, videoBitrate: Int) -> VideoDimensions {
        let sourceDimensions = VideoDimensions(width: source.width, height: source.height)
        let maxLongEdge: Int
        switch videoBitrate {
        case 1_700_000...: return sourceDimensions
        case 900_000...: maxLongEdge = 1280
        case 450_000...: maxLongEdge = 960
        case 250_000...: maxLongEdge = 640
        default: maxLongEdge = 640
        }
        let longEdge = max(source.width, source.height)
        guard longEdge > maxLongEdge else { return sourceDimensions }
        let scale = Double(maxLongEdge) / Double(longEdge)
        let width = even(Int((Double(source.width) * scale).rounded(.down)))
        let height = even(Int((Double(source.height) * scale).rounded(.down)))
        return VideoDimensions(width: max(2, width), height: max(2, height))
    }

    private func selectedFrameRate(_ sourceFrameRate: Double) -> Double {
        if sourceFrameRate > 60 { return 60 }
        if sourceFrameRate > 30 { return 30 }
        return sourceFrameRate
    }

    private func even(_ value: Int) -> Int { value.isMultiple(of: 2) ? value : value - 1 }
}

enum FileSizeFormatter {
    static func string(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal)
    }

    static func reductionPercentage(originalBytes: Int64, finalBytes: Int64) -> Int {
        guard originalBytes > 0 else { return 0 }
        let ratio = Double(finalBytes) / Double(originalBytes)
        let reduction = (1 - ratio) * 100
        return max(0, Int(reduction.rounded()))
    }
}
