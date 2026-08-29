import XCTest
@testable import SendFit

final class IncomingVideoRoutingTests: XCTestCase {
    func testMovieExtensionsAreAcceptedAndUnexpectedFilesAreRejected() {
        XCTAssertTrue(IncomingVideoRouter.isSupported(URL(fileURLWithPath: "/tmp/clip.mp4")))
        XCTAssertTrue(IncomingVideoRouter.isSupported(URL(fileURLWithPath: "/tmp/clip.MOV")))
        XCTAssertTrue(IncomingVideoRouter.isSupported(URL(fileURLWithPath: "/tmp/clip.m4v")))
        XCTAssertFalse(IncomingVideoRouter.isSupported(URL(fileURLWithPath: "/tmp/photo.jpg")))
        XCTAssertFalse(IncomingVideoRouter.isSupported(URL(fileURLWithPath: "/tmp/document.pdf")))
    }

    func testExternalAssetsRecordTheirImportSourceAndManagedOwnership() {
        let asset = VideoAsset(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/working-copy.mp4"),
            ownership: .sendFitTemporary,
            importSource: .externalOpen,
            displayName: "clip.mp4",
            fileSizeBytes: 42,
            duration: 3,
            dimensions: VideoDimensions(width: 1920, height: 1080),
            frameRate: 30,
            hasAudio: true
        )

        XCTAssertEqual(asset.importSource, .externalOpen)
        XCTAssertEqual(asset.ownership, .sendFitTemporary)
    }
}
