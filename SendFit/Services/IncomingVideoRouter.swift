import Foundation
import UniformTypeIdentifiers

@MainActor
final class IncomingVideoRouter {
    private let importService: VideoImportService

    init(importService: VideoImportService = VideoImportService()) {
        self.importService = importService
    }

    nonisolated static func isSupported(_ url: URL) -> Bool {
        let extensionType = UTType(filenameExtension: url.pathExtension)
        return extensionType?.conforms(to: .movie) == true || ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    func route(_ urls: [URL], compressionIsActive: Bool) async throws -> VideoAsset {
        guard urls.count == 1 else { throw VideoImportError.multipleVideos }
        guard !compressionIsActive else { throw VideoImportError.activeCompression }
        return try await importService.importFile(at: urls[0], source: .externalOpen, copyToManagedStorage: true)
    }
}
