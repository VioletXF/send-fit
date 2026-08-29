import Foundation
import XCTest
@testable import SendFit

@MainActor
final class SaveResultTests: XCTestCase {
    func testSaveDelegatesTheCurrentCompressionResultToThePhotoLibraryService() async {
        let saver = SaveSpy()
        let model = SendFitModel(exportService: saver, defaults: makeDefaults())
        let result = makeResult()
        model.phase = .result(result)

        await model.saveResult()

        XCTAssertEqual(saver.savedResult, result)
        XCTAssertNil(model.errorMessage)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SaveResultTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeResult() -> CompressionResult {
        let source = VideoAsset(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/source.mov"),
            ownership: .sendFitTemporary,
            importSource: .files,
            displayName: "source.mov",
            fileSizeBytes: 20_000_000,
            duration: 10,
            dimensions: VideoDimensions(width: 1920, height: 1080),
            frameRate: 30,
            hasAudio: true
        )
        return CompressionResult(
            id: UUID(),
            source: source,
            outputURL: URL(fileURLWithPath: "/tmp/output.mp4"),
            outputSizeBytes: 5_000_000,
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 30,
            duration: 10
        )
    }
}

@MainActor
private final class SaveSpy: PhotoLibrarySaving {
    private(set) var savedResult: CompressionResult?

    func saveToPhotos(_ result: CompressionResult) async throws {
        savedResult = result
    }
}
