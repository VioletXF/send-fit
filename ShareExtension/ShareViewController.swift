import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private var hasStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Opening SendFit…"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -18),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        Task { await handOffVideo() }
    }

    private func handOffVideo() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: supportsVideo) else {
            finish(with: "Choose one video to compress with SendFit.")
            return
        }

        do {
            try await stageVideo(from: provider)
            extensionContext?.completeRequest(returningItems: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    _ = self?.openContainingApp()
                }
            }
        } catch {
            finish(with: error.localizedDescription)
        }
    }

    private func supportsVideo(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }

    private func stageVideo(from provider: NSItemProvider) async throws {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            try await stageFileRepresentation(from: provider, typeIdentifier: UTType.movie.identifier)
        } else {
            try await stageURLItem(from: provider)
        }
    }

    private func stageFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    do {
                        try Self.stageSharedVideo(at: url)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: SharedVideoInboxError.invalidSharedVideo)
                }
            }
        }
    }

    private func stageURLItem(from provider: NSItemProvider) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let url = (item as? URL)
                    ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                do {
                    guard let url else { throw SharedVideoInboxError.invalidSharedVideo }
                    try Self.stageSharedVideo(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func stageSharedVideo(at url: URL) throws {
        guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true else {
            throw SharedVideoInboxError.invalidSharedVideo
        }
        // The provider owns this URL. Copy while its completion handler is
        // active; retaining it afterwards is not supported by NSItemProvider.
        try SharedVideoInbox().stageVideo(from: url)
    }

    private func openContainingApp() -> Bool {
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:")

        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication,
               application.responds(to: selector) {
                if #available(iOS 18.0, *) {
                    application.open(SharedVideoHandoff.containingAppLaunchURL, options: [:])
                    return true
                }
                return application.perform(selector, with: SharedVideoHandoff.containingAppLaunchURL) != nil
            }
            responder = currentResponder.next
        }
        return false
    }

    private func finish(with message: String) {
        spinner.stopAnimating()
        statusLabel.text = message
    }
}
