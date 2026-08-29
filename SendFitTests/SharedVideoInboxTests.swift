import Foundation
import XCTest
@testable import SendFit

final class SharedVideoInboxTests: XCTestCase {
    func testMissingDevelopmentContainerHasNoPendingVideo() throws {
        let inbox = SharedVideoInbox(containerURL: nil)

        XCTAssertNil(try inbox.consumePendingVideoURL())
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
