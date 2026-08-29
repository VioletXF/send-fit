import Foundation

enum SharedVideoHandoff {
    static let containingAppLaunchURL = URL(string: "sendfit://share")!
    static let mainAppLaunchUnavailableMessage = "Video is ready. Open SendFit to continue."
}

enum SharedVideoInboxError: Error, LocalizedError, Sendable {
    case sharedContainerUnavailable
    case invalidSharedVideo

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable:
            "SendFit couldn't access the shared video container."
        case .invalidSharedVideo:
            "SendFit couldn't open the shared video."
        }
    }
}

struct SharedVideoInbox: Sendable {
    static let appGroupIdentifier = "group.com.sendfit.app"

    private let containerURL: URL?

    init(containerURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)) {
        self.containerURL = containerURL
    }

    func stageVideo(from sourceURL: URL) throws {
        let inboxURL = try inboxURL()
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let pathExtension = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension.lowercased()
        let destinationURL = inboxURL.appendingPathComponent("\(UUID().uuidString).\(pathExtension)")
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        let data = try JSONEncoder().encode(SharedVideoHandoffManifest(fileName: destinationURL.lastPathComponent))
        try data.write(to: manifestURL(in: inboxURL), options: .atomic)
    }

    func consumePendingVideoURL() throws -> URL? {
        // A normal launch should remain quiet when a development provisioning
        // profile has not yet enabled the App Group. Staging still fails
        // explicitly so the share target never drops a selected video.
        guard let containerURL else { return nil }
        let inboxURL = containerURL.appendingPathComponent("SharedVideos", isDirectory: true)
        let manifestURL = manifestURL(in: inboxURL)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try Data(contentsOf: manifestURL)
        let handoff = try JSONDecoder().decode(SharedVideoHandoffManifest.self, from: data)
        try FileManager.default.removeItem(at: manifestURL)
        let videoURL = inboxURL.appendingPathComponent(handoff.fileName)
        guard videoURL.standardizedFileURL.deletingLastPathComponent() == inboxURL.standardizedFileURL,
              FileManager.default.fileExists(atPath: videoURL.path) else {
            throw SharedVideoInboxError.invalidSharedVideo
        }
        return videoURL
    }

    func removeSharedVideo(at url: URL) {
        guard let containerURL else { return }
        let inboxURL = containerURL.appendingPathComponent("SharedVideos", isDirectory: true)
        guard url.standardizedFileURL.deletingLastPathComponent() == inboxURL.standardizedFileURL else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func inboxURL() throws -> URL {
        guard let containerURL else { throw SharedVideoInboxError.sharedContainerUnavailable }
        return containerURL.appendingPathComponent("SharedVideos", isDirectory: true)
    }

    private func manifestURL(in inboxURL: URL) -> URL {
        inboxURL.appendingPathComponent("pending-video.json")
    }
}

private struct SharedVideoHandoffManifest: Codable, Sendable {
    let fileName: String
}
