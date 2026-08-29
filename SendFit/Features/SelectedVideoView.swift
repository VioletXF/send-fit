import AVKit
import SwiftUI

struct SelectedVideoView: View {
    let asset: VideoAsset
    @Bindable var model: SendFitModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VideoPlayer(player: AVPlayer(url: asset.sourceURL))
                    .frame(height: 230)
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityLabel("Selected video preview")

                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.displayName).font(.headline).lineLimit(1)
                    MetadataGrid(asset: asset)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Size").font(.headline)
                    Picker("Target Size", selection: $model.targetSizeMB) {
                        Text("5 MB").tag(5.0)
                        Text("10 MB").tag(10.0)
                        Text("25 MB").tag(25.0)
                        Text("50 MB").tag(50.0)
                        Text("100 MB").tag(100.0)
                        Text("Custom").tag(0.0)
                    }
                    .pickerStyle(.segmented)

                    if model.targetSizeMB == 0 {
                        TextField("Custom size in MB", text: $model.customTargetText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Custom target size in megabytes")
                    }
                    if let target = model.targetSizeBytes,
                       let plan = try? CompressionEstimator().makePlan(
                        for: CompressionRequest(targetSizeBytes: target),
                        source: CompressionSourceInfo(duration: asset.duration, width: asset.dimensions.width, height: asset.dimensions.height, frameRate: asset.frameRate, hasAudio: asset.hasAudio)
                       ) {
                        Label("Estimated \(plan.outputSize.displayName), \(Int(plan.outputFrameRate.rounded())) fps", systemImage: "wand.and.stars")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: model.startCompression) {
                    Label("Compress Video", systemImage: "arrow.down.right.and.arrow.up.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }
}

struct MetadataGrid: View {
    let asset: VideoAsset

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
            GridRow { Text("Size").foregroundStyle(.secondary); Text(FileSizeFormatter.string(bytes: asset.fileSizeBytes)) }
            GridRow { Text("Duration").foregroundStyle(.secondary); Text(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond))) }
            GridRow { Text("Resolution").foregroundStyle(.secondary); Text(asset.dimensions.displayName) }
            GridRow { Text("Frame rate").foregroundStyle(.secondary); Text("\(Int(asset.frameRate.rounded())) fps") }
        }
        .font(.subheadline)
    }
}
