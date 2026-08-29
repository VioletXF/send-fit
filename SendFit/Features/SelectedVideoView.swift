import AVKit
import PhotosUI
import SwiftUI

struct SelectedVideoView: View {
    let asset: VideoAsset
    @Bindable var model: SendFitModel
    @Binding var photosItem: PhotosPickerItem?

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Video").font(.headline)
                    HStack {
                        PhotosPicker(selection: $photosItem, matching: .videos) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            model.isShowingFileImporter = true
                        } label: {
                            Label("Browse Files", systemImage: "folder")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Size").font(.headline)
                    Picker("Target Size", selection: $model.targetSizeMB) {
                        ForEach(CompressionTargetPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Prioritize").font(.headline)
                    Picker("Prioritize", selection: $model.compressionPriority) {
                        ForEach(CompressionPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(model.compressionPriority == .frameRate
                         ? "Keeps the original frame rate when possible by reducing resolution first."
                         : "Keeps more resolution when possible by reducing frame rate first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Advanced") {
                        Toggle("Set video bitrate", isOn: $model.isAdvancedMode)

                        if model.isAdvancedMode {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Video bitrate")
                                    Spacer()
                                    Text("\(Int(model.videoBitrateKbps)) kbps")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $model.videoBitrateKbps, in: 150...10_000, step: 50)
                                    .accessibilityLabel("Video bitrate")
                                Text("SendFit uses this rate when it fits the selected size, and lowers it only if needed to honor the size limit.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if model.targetSizeMB == 0 {
                        TextField("Custom size in MB", text: $model.customTargetText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Custom target size in megabytes")
                    }
                    if let target = model.targetSizeBytes,
                       let plan = try? CompressionEstimator().makePlan(
                        for: CompressionRequest(
                            targetSizeBytes: target,
                            priority: model.compressionPriority,
                            videoBitrateOverride: model.videoBitrateOverride
                        ),
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
