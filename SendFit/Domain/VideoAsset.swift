import Foundation

enum FileOwnership: String, Codable, Equatable, Sendable {
    case userOwned
    case sendFitTemporary
    case sendFitOutput
}

struct VideoAsset: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceURL: URL
    let ownership: FileOwnership
    let importSource: VideoImportSource
    let displayName: String
    let fileSizeBytes: Int64
    let duration: TimeInterval
    let dimensions: VideoDimensions
    let frameRate: Double
    let hasAudio: Bool
}

struct CompressionResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: VideoAsset
    let outputURL: URL
    let outputSizeBytes: Int64
    let dimensions: VideoDimensions
    let frameRate: Double
    let duration: TimeInterval

    var reductionPercentage: Int {
        FileSizeFormatter.reductionPercentage(originalBytes: source.fileSizeBytes, finalBytes: outputSizeBytes)
    }
}

enum VideoImportError: Error, LocalizedError, Sendable {
    case unsupportedFile
    case missingFile
    case multipleVideos
    case activeCompression
    case metadataUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "SendFit couldn't open this video."
        case .missingFile: "The selected video is no longer available."
        case .multipleVideos: "SendFit currently compresses one video at a time."
        case .activeCompression: "A compression is currently running. Finish or cancel it before opening another video."
        case .metadataUnavailable: "SendFit couldn't read this video's details."
        }
    }
}
