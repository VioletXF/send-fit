import Foundation
import XCTest
@testable import SendFit

final class PhotosVideoImportTests: XCTestCase {
    func testImportedMovieRetainsAManagedCopyAfterThePickerFileIsRemoved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotosVideoImportTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = directory.appendingPathComponent("picker-video.mp4")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("video bytes".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: directory) }

        let imported = try ImportedMovie(url: sourceURL)
        try FileManager.default.removeItem(at: sourceURL)

        XCTAssertEqual(imported.url.lastPathComponent, "picker-video.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.url.path))
        XCTAssertEqual(try Data(contentsOf: imported.url), Data("video bytes".utf8))
    }
}
