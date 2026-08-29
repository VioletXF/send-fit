import AVFoundation
import Foundation

struct VideoMetadataReader: Sendable {
    func read(url: URL, importSource: VideoImportSource, ownership: FileOwnership) async throws -> VideoAsset {
        guard FileManager.default.fileExists(atPath: url.path) else { throw VideoImportError.missingFile }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw VideoImportError.unsupportedFile }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let transformedSize = naturalSize.applying(transform)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
        let width = max(1, Int(abs(transformedSize.width).rounded()))
        let height = max(1, Int(abs(transformedSize.height).rounded()))

        return VideoAsset(
            id: UUID(),
            sourceURL: url,
            ownership: ownership,
            importSource: importSource,
            displayName: values.name ?? url.lastPathComponent,
            fileSizeBytes: Int64(values.fileSize ?? 0),
            duration: duration.seconds,
            dimensions: VideoDimensions(width: width, height: height),
            frameRate: Double(nominalFrameRate),
            hasAudio: !audioTracks.isEmpty
        )
    }
}
