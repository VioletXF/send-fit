import Photos
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ExportService {
    func saveToPhotos(_ result: CompressionResult) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: result.outputURL)
        }
    }

    func activityItems(for result: CompressionResult) -> [Any] { [result.outputURL] }
}
