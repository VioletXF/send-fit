import XCTest
@testable import SendFit

final class AdPolicyTests: XCTestCase {
    private let policy = AdPolicy(configuration: .init(
        firstInterstitialAfterSuccessfulCompressions: 3,
        compressionsBetweenInterstitials: 3,
        minimumInterstitialInterval: 300
    ))

    func testFirstAndSecondSuccessfulCompressionsAreNotEligible() {
        XCTAssertFalse(policy.shouldShowInterstitial(
            state: .init(successfulCompressionCount: 1, lastInterstitialDate: nil),
            now: Date(timeIntervalSince1970: 1_000),
            entitlement: FreeEntitlementProvider()
        ))
        XCTAssertFalse(policy.shouldShowInterstitial(
            state: .init(successfulCompressionCount: 2, lastInterstitialDate: nil),
            now: Date(timeIntervalSince1970: 1_000),
            entitlement: FreeEntitlementProvider()
        ))
    }

    func testThirdSuccessfulCompressionIsEligible() {
        XCTAssertTrue(policy.shouldShowInterstitial(
            state: .init(successfulCompressionCount: 3, lastInterstitialDate: nil),
            now: Date(timeIntervalSince1970: 1_000),
            entitlement: FreeEntitlementProvider()
        ))
    }

    func testMinimumIntervalAndDisabledEntitlementSuppressAdvertising() {
        XCTAssertFalse(policy.shouldShowInterstitial(
            state: .init(successfulCompressionCount: 6, lastInterstitialDate: Date(timeIntervalSince1970: 900)),
            now: Date(timeIntervalSince1970: 1_000),
            entitlement: FreeEntitlementProvider()
        ))
        XCTAssertFalse(policy.shouldShowInterstitial(
            state: .init(successfulCompressionCount: 6, lastInterstitialDate: nil),
            now: Date(timeIntervalSince1970: 1_000),
            entitlement: TestEntitlementProvider(adsEnabled: false)
        ))
    }

    func testImportSourceDoesNotChangeAdEligibilityOrCompressionAvailability() {
        let state = AdFrequencyState(successfulCompressionCount: 3, lastInterstitialDate: nil)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            policy.shouldShowInterstitial(state: state, now: now, entitlement: FreeEntitlementProvider(), source: .photos),
            policy.shouldShowInterstitial(state: state, now: now, entitlement: FreeEntitlementProvider(), source: .externalOpen)
        )
        XCTAssertTrue(CompressionFlowPolicy.canStartCompression(adAvailability: .unavailable))
    }
}
