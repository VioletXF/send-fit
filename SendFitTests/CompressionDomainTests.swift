import XCTest
@testable import SendFit

final class CompressionDomainTests: XCTestCase {
    func testPlanForSixtySecondVideoAtTenMegabytesReservesAudioAndSafetyMargin() throws {
        let request = CompressionRequest(targetSizeBytes: 10_000_000)
        let source = CompressionSourceInfo(duration: 60, width: 1920, height: 1080, frameRate: 30, hasAudio: true)

        let plan = try CompressionEstimator().makePlan(for: request, source: source)

        XCTAssertEqual(plan.audioBitrate, 96_000)
        XCTAssertEqual(plan.videoBitrate, 1_034_666)
        XCTAssertEqual(plan.outputSize, VideoDimensions(width: 1280, height: 720))
        XCTAssertEqual(plan.outputFrameRate, 30)
    }

    func testPlanForThirtySecondFiveMegabyteVideoSelectsLowerAudioBitrate() throws {
        let request = CompressionRequest(targetSizeBytes: 5_000_000)
        let source = CompressionSourceInfo(duration: 30, width: 1920, height: 1080, frameRate: 60, hasAudio: true)

        let plan = try CompressionEstimator().makePlan(for: request, source: source)

        XCTAssertEqual(plan.audioBitrate, 96_000)
        XCTAssertEqual(plan.outputFrameRate, 30)
    }

    func testPlanForLongVideoWithTinyTargetIsRejected() {
        let request = CompressionRequest(targetSizeBytes: 1_000_000)
        let source = CompressionSourceInfo(duration: 10_800, width: 3840, height: 2160, frameRate: 60, hasAudio: true)

        XCTAssertThrowsError(try CompressionEstimator().makePlan(for: request, source: source)) { error in
            XCTAssertEqual(error as? CompressionPlanningError, .targetTooSmall)
        }
    }

    func testPlanForTenMinuteVideoAtTwentyFiveMegabytesStaysAboveMinimumQuality() throws {
        let request = CompressionRequest(targetSizeBytes: 25_000_000)
        let source = CompressionSourceInfo(duration: 600, width: 3840, height: 2160, frameRate: 60, hasAudio: true)

        let plan = try CompressionEstimator().makePlan(for: request, source: source)

        XCTAssertEqual(plan.videoBitrate, 218_666)
        XCTAssertEqual(plan.outputSize, VideoDimensions(width: 640, height: 360))
        XCTAssertEqual(plan.outputFrameRate, 30)
    }

    func testRetryBitrateUsesActualOutputSizeAndSafetyFactor() {
        let corrected = CompressionEstimator().correctedVideoBitrate(
            previousBitrate: 1_000_000,
            targetSizeBytes: 10_000_000,
            actualSizeBytes: 12_000_000
        )

        XCTAssertEqual(corrected, 791_666)
    }

    func testReductionPercentageAndByteFormattingAreStable() {
        XCTAssertEqual(FileSizeFormatter.reductionPercentage(originalBytes: 243_800_000, finalBytes: 24_600_000), 90)
        XCTAssertEqual(FileSizeFormatter.string(bytes: 24_600_000), "24.6 MB")
    }
}
