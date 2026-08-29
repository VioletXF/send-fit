import Foundation

actor TemporaryFileStore {
    private let rootURL: URL

    init(fileManager: FileManager = .default) {
        rootURL = fileManager.temporaryDirectory.appendingPathComponent("SendFit", isDirectory: true)
    }

    nonisolated static func copyReceivedPickerFile(from sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent("SendFit", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let transferDirectory = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: transferDirectory, withIntermediateDirectories: true)
        let destination = transferDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func copyIntoWorkingDirectory(from sourceURL: URL, preferredName: String? = nil) throws -> URL {
        try prepare()
        let filename = preferredName ?? sourceURL.lastPathComponent
        let destination = rootURL.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func newOutputURL() throws -> URL {
        try prepare()
        return rootURL.appendingPathComponent("SendFit-\(UUID().uuidString).mp4")
    }

    func removeManagedFile(at url: URL) {
        guard url.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func removeAllManagedFiles() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
