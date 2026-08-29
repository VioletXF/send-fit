import Foundation

protocol EntitlementProviding: Sendable {
    var adsEnabled: Bool { get }
}

struct FreeEntitlementProvider: EntitlementProviding, Sendable {
    let adsEnabled = true
}

struct TestEntitlementProvider: EntitlementProviding, Sendable {
    let adsEnabled: Bool
}

enum VideoImportSource: String, Codable, Sendable {
    case photos
    case files
    case externalOpen
}

enum AdAvailability: Sendable {
    case available
    case unavailable
}

struct AdFrequencyState: Equatable, Sendable {
    var successfulCompressionCount: Int
    var lastInterstitialDate: Date?
}

struct AdPolicyConfiguration: Sendable {
    let firstInterstitialAfterSuccessfulCompressions: Int
    let compressionsBetweenInterstitials: Int
    let minimumInterstitialInterval: TimeInterval
}

struct AdPolicy: Sendable {
    let configuration: AdPolicyConfiguration

    func shouldShowInterstitial(
        state: AdFrequencyState,
        now: Date,
        entitlement: any EntitlementProviding,
        source: VideoImportSource = .photos
    ) -> Bool {
        guard entitlement.adsEnabled else { return false }
        let count = state.successfulCompressionCount
        guard count >= configuration.firstInterstitialAfterSuccessfulCompressions else { return false }
        guard (count - configuration.firstInterstitialAfterSuccessfulCompressions).isMultiple(of: configuration.compressionsBetweenInterstitials) else { return false }
        if let lastShown = state.lastInterstitialDate,
           now.timeIntervalSince(lastShown) < configuration.minimumInterstitialInterval {
            return false
        }
        return true
    }
}

enum CompressionFlowPolicy {
    static func canStartCompression(adAvailability: AdAvailability) -> Bool { true }
}
