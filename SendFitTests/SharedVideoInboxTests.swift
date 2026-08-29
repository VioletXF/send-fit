import Foundation
import XCTest
@testable import SendFit

final class SharedVideoInboxTests: XCTestCase {
    func testHandoffUsesTheContainingAppDeepLink() {
        XCTAssertEqual(SharedVideoHandoff.containingAppLaunchURL.absoluteString, "sendfit://share")
    }

    func testLaunchFallbackExplainsHowToResumeInMainApp() {
        XCTAssertEqual(
            SharedVideoHandoff.mainAppLaunchUnavailableMessage,
            "Video is ready. Open SendFit to continue."
        )
    }

    func testMissingDevelopmentContainerHasNoPendingVideo() throws {
        let inbox = SharedVideoInbox(containerURL: nil)

        XCTAssertNil(try inbox.consumePendingVideoURL())
    }

    func testPruneStaleVideosRemovesOnlyExpiredOrphans() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedVideoPruneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let inbox = SharedVideoInbox(containerURL: directory)
        let sourceURL = directory.appendingPathComponent("source.mov")
        try Data("video bytes".utf8).write(to: sourceURL)
        try inbox.stageVideo(from: sourceURL)
        let staleURL = try XCTUnwrap(inbox.consumePendingVideoURL())
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-172_800)], ofItemAtPath: staleURL.path)

        try inbox.stageVideo(from: sourceURL)
        let pendingURL = directory.appendingPathComponent("SharedVideos", isDirectory: true)
        let manifestData = try Data(contentsOf: pendingURL.appendingPathComponent("pending-video.json"))
        let pendingName = try JSONDecoder().decode(TestHandoffManifest.self, from: manifestData).fileName
        let activeURL = pendingURL.appendingPathComponent(pendingName)

        try inbox.pruneStaleVideos(olderThan: Date().addingTimeInterval(-86_400))

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: activeURL.path))
    }

    func testStagedVideoIsConsumedOnceAndCanBeCleanedUp() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedVideoInboxTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("source.mov")
        try Data("video bytes".utf8).write(to: sourceURL)
        let inbox = SharedVideoInbox(containerURL: directory)

        try inbox.stageVideo(from: sourceURL)
        let sharedURL = try XCTUnwrap(inbox.consumePendingVideoURL())

        XCTAssertEqual(try Data(contentsOf: sharedURL), Data("video bytes".utf8))
        XCTAssertNil(try inbox.consumePendingVideoURL())
        inbox.removeSharedVideo(at: sharedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedURL.path))
    }
}

private struct TestHandoffManifest: Codable {
    let fileName: String
}
