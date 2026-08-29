@preconcurrency import GoogleMobileAds
import SwiftUI
import UIKit

struct AdConfiguration: Sendable {
    let bannerAdUnitID: String
    let interstitialAdUnitID: String

    static let current: AdConfiguration = {
        #if DEBUG
        return AdConfiguration(
            bannerAdUnitID: "ca-app-pub-3940256099942544/2435281174",
            interstitialAdUnitID: "ca-app-pub-3940256099942544/4411468910"
        )
        #else
        return AdConfiguration(
            bannerAdUnitID: Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String ?? "",
            interstitialAdUnitID: Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_AD_UNIT_ID") as? String ?? ""
        )
        #endif
    }()
}

@MainActor
protocol AdServing: AnyObject {
    func startIfPermitted(_ permitted: Bool, entitlement: any EntitlementProviding)
    func preloadInterstitial(entitlement: any EntitlementProviding)
    func presentInterstitialIfReady(from viewController: UIViewController?, entitlement: any EntitlementProviding) -> Bool
}

@MainActor
final class AdService: NSObject, AdServing, FullScreenContentDelegate {
    private let configuration: AdConfiguration
    nonisolated(unsafe) private var interstitial: InterstitialAd?
    private var hasStarted = false

    init(configuration: AdConfiguration = .current) {
        self.configuration = configuration
    }

    func startIfPermitted(_ permitted: Bool, entitlement: any EntitlementProviding) {
        guard permitted, entitlement.adsEnabled, !hasStarted else { return }
        hasStarted = true
        MobileAds.shared.start(completionHandler: nil)
        preloadInterstitial(entitlement: entitlement)
    }

    func preloadInterstitial(entitlement: any EntitlementProviding) {
        guard entitlement.adsEnabled, hasStarted, interstitial == nil, !configuration.interstitialAdUnitID.isEmpty else { return }
        InterstitialAd.load(with: configuration.interstitialAdUnitID, request: Request()) { [weak self] ad, _ in
            guard let self else { return }
            self.interstitial = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    func presentInterstitialIfReady(from viewController: UIViewController?, entitlement: any EntitlementProviding) -> Bool {
        guard entitlement.adsEnabled, let interstitial else { return false }
        guard (try? interstitial.canPresent(from: viewController)) != nil else { return false }
        self.interstitial = nil
        interstitial.present(from: viewController)
        return true
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        interstitial = nil
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        interstitial = nil
    }
}

struct BannerAdView: UIViewRepresentable {
    let enabled: Bool
    let adUnitID: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        guard enabled, !adUnitID.isEmpty else { return container }
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        banner.load(Request())
        banner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
