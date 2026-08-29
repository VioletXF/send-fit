import Foundation
import Photos

@MainActor
protocol PhotoLibrarySaving {
    func saveToPhotos(_ result: CompressionResult) async throws
}

enum PhotoExportError: LocalizedError {
    case outputFileMissing
    case photoLibraryAccessDenied

    var errorDescription: String? {
        switch self {
        case .outputFileMissing:
            "The compressed video is no longer available. Compress it again before saving."
        case .photoLibraryAccessDenied:
            "Allow Add Photos Only access in Settings to save the compressed video."
        }
    }
}

@MainActor
final class ExportService: PhotoLibrarySaving {
    func saveToPhotos(_ result: CompressionResult) async throws {
        try validateOutputFile(at: result.outputURL)
        guard await hasAddOnlyPhotoLibraryAccess() else {
            throw PhotoExportError.photoLibraryAccessDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: result.outputURL, options: nil)
        }
    }

    func activityItems(for result: CompressionResult) -> [Any] { [result.outputURL] }

    private func validateOutputFile(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
            throw PhotoExportError.outputFileMissing
        }
    }

    private func hasAddOnlyPhotoLibraryAccess() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status: PHAuthorizationStatus
        if currentStatus == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        } else {
            status = currentStatus
        }
        return status == .authorized || status == .limited
    }
}
