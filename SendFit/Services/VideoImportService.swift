import Foundation

struct VideoImportService: Sendable {
    private let metadataReader: VideoMetadataReader
    private let temporaryStore: TemporaryFileStore

    init(metadataReader: VideoMetadataReader = VideoMetadataReader(), temporaryStore: TemporaryFileStore = TemporaryFileStore()) {
        self.metadataReader = metadataReader
        self.temporaryStore = temporaryStore
    }

    func importFile(at url: URL, source: VideoImportSource, copyToManagedStorage: Bool) async throws -> VideoAsset {
        guard IncomingVideoRouter.isSupported(url) else { throw VideoImportError.unsupportedFile }
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }
        let workingURL: URL
        let ownership: FileOwnership
        if copyToManagedStorage {
            workingURL = try await temporaryStore.copyIntoWorkingDirectory(from: url)
            ownership = .sendFitTemporary
        } else {
            workingURL = url
            ownership = .userOwned
        }
        return try await metadataReader.read(url: workingURL, importSource: source, ownership: ownership)
    }

    func importManagedFile(at url: URL, source: VideoImportSource) async throws -> VideoAsset {
        guard IncomingVideoRouter.isSupported(url) else { throw VideoImportError.unsupportedFile }
        return try await metadataReader.read(url: url, importSource: source, ownership: .sendFitTemporary)
    }
}
