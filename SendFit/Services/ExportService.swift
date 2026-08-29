import Foundation
import Photos

protocol PhotoLibrarySaving: Sendable {
    func saveToPhotos(_ result: CompressionResult) async throws
}

enum PhotoExportError: LocalizedError {
    case outputFileMissing
    case photoLibraryAccessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .outputFileMissing:
            "The compressed video is no longer available. Compress it again before saving."
        case .photoLibraryAccessDenied:
            "Allow Add Photos Only access in Settings to save the compressed video."
        case .saveFailed:
            "SendFit couldn't save this video to Photos. Try again."
        }
    }
}

struct ExportService: PhotoLibrarySaving, Sendable {
    func saveToPhotos(_ result: CompressionResult) async throws {
        try validateOutputFile(at: result.outputURL)
        guard await hasAddOnlyPhotoLibraryAccess() else {
            throw PhotoExportError.photoLibraryAccessDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: result.outputURL, options: nil)
            }
        } catch {
            throw PhotoExportError.saveFailed
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
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            status = currentStatus
        }
        return status == .authorized || status == .limited
    }
}
