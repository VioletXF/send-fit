@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

enum CompressionServiceError: Error, LocalizedError, Sendable {
    case readerFailed
    case writerFailed
    case outputTooLarge

    var errorDescription: String? {
        switch self {
        case .readerFailed: "SendFit couldn't read this video for compression."
        case .writerFailed: "SendFit couldn't finish compressing this video."
        case .outputTooLarge: "SendFit couldn't fit this video into the selected size. Try a larger target."
        }
    }
}

actor VideoCompressionService {
    private let estimator: CompressionEstimator
    private let temporaryStore: TemporaryFileStore

    private final class EncodingContext: @unchecked Sendable {
        let reader: AVAssetReader
        let writer: AVAssetWriter
        let videoOutput: AVAssetReaderVideoCompositionOutput
        let videoInput: AVAssetWriterInput
        let audioOutput: AVAssetReaderTrackOutput?
        let audioInput: AVAssetWriterInput?

        init(reader: AVAssetReader, writer: AVAssetWriter, videoOutput: AVAssetReaderVideoCompositionOutput, videoInput: AVAssetWriterInput, audioOutput: AVAssetReaderTrackOutput?, audioInput: AVAssetWriterInput?) {
            self.reader = reader
            self.writer = writer
            self.videoOutput = videoOutput
            self.videoInput = videoInput
            self.audioOutput = audioOutput
            self.audioInput = audioInput
        }
    }

    init(estimator: CompressionEstimator = CompressionEstimator(), temporaryStore: TemporaryFileStore = TemporaryFileStore()) {
        self.estimator = estimator
        self.temporaryStore = temporaryStore
    }

    func compress(
        source: VideoAsset,
        request: CompressionRequest,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> CompressionResult {
        let sourceInfo = CompressionSourceInfo(
            duration: source.duration,
            width: source.dimensions.width,
            height: source.dimensions.height,
            frameRate: source.frameRate,
            hasAudio: source.hasAudio
        )
        var plan = try estimator.makePlan(for: request, source: sourceInfo)

        for attempt in 1...3 {
            try Task.checkCancellation()
            progress(0, attempt == 1 ? "Preparing…" : "Optimizing size…")
            let outputURL = try await temporaryStore.newOutputURL()
            do {
                try await encode(source: source, plan: plan, outputURL: outputURL, progress: progress)
                let values = try outputURL.resourceValues(forKeys: [.fileSizeKey])
                let outputSize = Int64(values.fileSize ?? 0)
                if outputSize <= request.targetSizeBytes {
                    progress(1, "Finishing…")
                    return CompressionResult(
                        id: UUID(),
                        source: source,
                        outputURL: outputURL,
                        outputSizeBytes: outputSize,
                        dimensions: plan.outputSize,
                        frameRate: plan.outputFrameRate,
                        duration: source.duration
                    )
                }
                await temporaryStore.removeManagedFile(at: outputURL)
                guard attempt < 3 else { throw CompressionServiceError.outputTooLarge }
                plan = CompressionPlan(
                    videoBitrate: estimator.correctedVideoBitrate(
                        previousBitrate: plan.videoBitrate,
                        targetSizeBytes: request.targetSizeBytes,
                        actualSizeBytes: outputSize
                    ),
                    audioBitrate: plan.audioBitrate,
                    outputSize: plan.outputSize,
                    outputFrameRate: plan.outputFrameRate,
                    safetyMarginBitrate: plan.safetyMarginBitrate
                )
            } catch {
                await temporaryStore.removeManagedFile(at: outputURL)
                throw error
            }
        }
        throw CompressionServiceError.outputTooLarge
    }

    private func encode(
        source: VideoAsset,
        plan: CompressionPlan,
        outputURL: URL,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let asset = AVURLAsset(url: source.sourceURL)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw CompressionServiceError.readerFailed }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoComposition = try await makeVideoComposition(track: videoTrack, duration: duration, plan: plan)
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        )
        videoOutput.videoComposition = videoComposition
        guard reader.canAdd(videoOutput) else { throw CompressionServiceError.readerFailed }
        reader.add(videoOutput)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: plan.outputSize.width,
            AVVideoHeightKey: plan.outputSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: plan.videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: max(1, Int(plan.outputFrameRate * 2))
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw CompressionServiceError.writerFailed }
        writer.add(videoInput)

        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audioTrack, plan.audioBitrate > 0 {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: plan.audioBitrate,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100
            ])
            if reader.canAdd(output), writer.canAdd(input) {
                reader.add(output)
                writer.add(input)
                audioOutput = output
                audioInput = input
            }
        }

        try await run(reader: reader, writer: writer, videoOutput: videoOutput, videoInput: videoInput, audioOutput: audioOutput, audioInput: audioInput, duration: duration, progress: progress)
    }

    private func makeVideoComposition(track: AVAssetTrack, duration: CMTime, plan: CompressionPlan) async throws -> AVMutableVideoComposition {
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)
        let orientedSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        let outputSize = CGSize(width: plan.outputSize.width, height: plan.outputSize.height)
        let scale = min(outputSize.width / orientedSize.width, outputSize.height / orientedSize.height)

        let composition = AVMutableVideoComposition()
        composition.renderSize = outputSize
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, plan.outputFrameRate.rounded())))
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let scaledTransform = preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        layer.setTransform(scaledTransform, at: .zero)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]
        return composition
    }

    private func run(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoOutput: AVAssetReaderVideoCompositionOutput,
        videoInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderTrackOutput?,
        audioInput: AVAssetWriterInput?,
        duration: CMTime,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let context = EncodingContext(reader: reader, writer: writer, videoOutput: videoOutput, videoInput: videoInput, audioOutput: audioOutput, audioInput: audioInput)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard context.writer.startWriting(), context.reader.startReading() else {
                continuation.resume(throwing: CompressionServiceError.writerFailed)
                return
            }
            context.writer.startSession(atSourceTime: .zero)
            let queue = DispatchQueue(label: "com.sendfit.encoding", qos: .userInitiated)
            let group = DispatchGroup()

            group.enter()
            context.videoInput.requestMediaDataWhenReady(on: queue) {
                while context.videoInput.isReadyForMoreMediaData {
                    guard let sample = context.videoOutput.copyNextSampleBuffer() else {
                        context.videoInput.markAsFinished()
                        group.leave()
                        return
                    }
                    if !context.videoInput.append(sample) {
                        group.leave()
                        return
                    }
                    let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                    let fraction = duration.seconds > 0 ? min(0.98, max(0, time / duration.seconds)) : 0
                    progress(fraction, "Compressing…")
                }
            }

            if context.audioOutput != nil, context.audioInput != nil {
                group.enter()
                context.audioInput?.requestMediaDataWhenReady(on: queue) {
                    guard let audioInput = context.audioInput, let audioOutput = context.audioOutput else {
                        group.leave()
                        return
                    }
                    while audioInput.isReadyForMoreMediaData {
                        guard let sample = audioOutput.copyNextSampleBuffer() else {
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }
                        if !audioInput.append(sample) {
                            group.leave()
                            return
                        }
                    }
                }
            }

            group.notify(queue: queue) {
                writer.finishWriting {
                    if context.writer.status == .completed {
                        continuation.resume()
                    } else if context.reader.status == .failed {
                        continuation.resume(throwing: context.reader.error ?? CompressionServiceError.readerFailed)
                    } else {
                        continuation.resume(throwing: context.writer.error ?? CompressionServiceError.writerFailed)
                    }
                }
            }
        }
    }
}
