import Foundation
import Observation
import PhotosUI
import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SendFitPhase: Equatable {
    case empty
    case selected(VideoAsset)
    case compressing(VideoAsset)
    case result(CompressionResult)
}

@MainActor
@Observable
final class SendFitModel {
    var phase: SendFitPhase = .empty
    var targetSizeMB: Double = 25
    var customTargetText = ""
    var progress = 0.0
    var stage = "Preparing…"
    var errorMessage: String?
    var isShowingSettings = false
    var isShowingFileImporter = false
    var isShowingShareSheet = false
    var privacyOptionsRequired = false
    var isSavingResult = false
    var saveConfirmationMessage: String?

    private let importService: VideoImportService
    private let incomingRouter: IncomingVideoRouter
    private let compressionService: VideoCompressionService
    private let exportService: any PhotoLibrarySaving
    private let consentManager: any ConsentManaging
    private let adService: any AdServing
    private let entitlement: any EntitlementProviding
    private let adPolicy: AdPolicy
    private let defaults: UserDefaults
    private var compressionTask: Task<Void, Never>?

    init(
        importService: VideoImportService = VideoImportService(),
        incomingRouter: IncomingVideoRouter = IncomingVideoRouter(),
        compressionService: VideoCompressionService = VideoCompressionService(),
        exportService: any PhotoLibrarySaving = ExportService(),
        consentManager: any ConsentManaging = ConsentManager(),
        adService: any AdServing = AdService(),
        entitlement: any EntitlementProviding = FreeEntitlementProvider(),
        adPolicy: AdPolicy = AdPolicy(configuration: .init(firstInterstitialAfterSuccessfulCompressions: 3, compressionsBetweenInterstitials: 3, minimumInterstitialInterval: 300)),
        defaults: UserDefaults = .standard
    ) {
        self.importService = importService
        self.incomingRouter = incomingRouter
        self.compressionService = compressionService
        self.exportService = exportService
        self.consentManager = consentManager
        self.adService = adService
        self.entitlement = entitlement
        self.adPolicy = adPolicy
        self.defaults = defaults
        let storedTarget = defaults.double(forKey: "targetSizeMB")
        if storedTarget > 0 { targetSizeMB = storedTarget }
    }

    var selectedAsset: VideoAsset? {
        switch phase {
        case .selected(let asset), .compressing(let asset): asset
        case .empty, .result: nil
        }
    }

    var result: CompressionResult? {
        guard case .result(let result) = phase else { return nil }
        return result
    }

    var targetSizeBytes: Int64? {
        let megabytes: Double
        if targetSizeMB == 0 {
            megabytes = Double(customTargetText) ?? 0
        } else {
            megabytes = targetSizeMB
        }
        guard megabytes > 0 else { return nil }
        return Int64(megabytes * 1_000_000)
    }

    func initialize() async {
        await consentManager.refresh(from: topViewController())
        privacyOptionsRequired = consentManager.privacyOptionsRequired
        adService.startIfPermitted(consentManager.canRequestAds, entitlement: entitlement)
    }

    func selectFile(url: URL, source: VideoImportSource, copyToManagedStorage: Bool = true) async {
        do {
            let asset = try await importService.importFile(at: url, source: source, copyToManagedStorage: copyToManagedStorage)
            phase = .selected(asset)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openExternally(url: URL) async {
        do {
            let asset = try await incomingRouter.route([url], compressionIsActive: isCompressing)
            phase = .selected(asset)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handlePhotosPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let transferred = try await item.loadTransferable(type: ImportedMovie.self) else {
                throw VideoImportError.unsupportedFile
            }
            await selectFile(url: transferred.url, source: .photos)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startCompression() {
        guard let source = selectedAsset, let targetSizeBytes else {
            errorMessage = "Enter a valid target size."
            return
        }
        defaults.set(targetSizeMB, forKey: "targetSizeMB")
        phase = .compressing(source)
        progress = 0
        stage = "Preparing…"
        compressionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.compressionService.compress(
                    source: source,
                    request: CompressionRequest(targetSizeBytes: targetSizeBytes)
                ) { [weak self] progress, stage in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.stage = stage
                    }
                }
                guard !Task.isCancelled else { return }
                self.recordSuccess()
                self.phase = .result(result)
                self.adService.preloadInterstitial(entitlement: self.entitlement)
            } catch is CancellationError {
                self.phase = .selected(source)
            } catch {
                self.phase = .selected(source)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancelCompression() {
        compressionTask?.cancel()
        if case .compressing(let source) = phase { phase = .selected(source) }
    }

    func saveResult() async {
        guard let result, !isSavingResult else { return }
        isSavingResult = true
        errorMessage = nil
        saveConfirmationMessage = nil
        defer { isSavingResult = false }
        do {
            try await exportService.saveToPhotos(result)
            saveConfirmationMessage = "Saved to Photos."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func compressAnother() {
        presentEligibleInterstitial()
        phase = .empty
    }

    func showShareSheet() { isShowingShareSheet = true }

    func presentPrivacyOptions() {
        consentManager.presentPrivacyOptions(from: topViewController())
    }

    private var isCompressing: Bool {
        if case .compressing = phase { return true }
        return false
    }

    private func recordSuccess() {
        defaults.set(defaults.integer(forKey: "successfulCompressionCount") + 1, forKey: "successfulCompressionCount")
    }

    private func presentEligibleInterstitial() {
        let state = AdFrequencyState(
            successfulCompressionCount: defaults.integer(forKey: "successfulCompressionCount"),
            lastInterstitialDate: defaults.object(forKey: "lastInterstitialDate") as? Date
        )
        guard adPolicy.shouldShowInterstitial(state: state, now: .now, entitlement: entitlement) else { return }
        if adService.presentInterstitialIfReady(from: topViewController(), entitlement: entitlement) {
            defaults.set(Date.now, forKey: "lastInterstitialDate")
        }
    }

    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    }
}

struct ImportedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            ImportedMovie(url: received.file)
        }
    }
}
