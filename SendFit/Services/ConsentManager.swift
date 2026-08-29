import UIKit
import UserMessagingPlatform

@MainActor
protocol ConsentManaging: AnyObject {
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    func refresh(from viewController: UIViewController?) async
    func presentPrivacyOptions(from viewController: UIViewController?)
}

@MainActor
final class ConsentManager: ConsentManaging {
    private(set) var canRequestAds = false
    private(set) var privacyOptionsRequired = false

    func refresh(from viewController: UIViewController?) async {
        let parameters = RequestParameters()
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    self.canRequestAds = ConsentInformation.shared.canRequestAds
                    self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                    Task { @MainActor [weak self] in
                        _ = try? await ConsentForm.loadAndPresentIfRequired(from: viewController)
                        self?.canRequestAds = ConsentInformation.shared.canRequestAds
                        self?.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                        continuation.resume()
                    }
                }
            }
        }
    }

    func presentPrivacyOptions(from viewController: UIViewController?) {
        ConsentForm.presentPrivacyOptionsForm(from: viewController) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.canRequestAds = ConsentInformation.shared.canRequestAds
                self?.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            }
        }
    }
}
