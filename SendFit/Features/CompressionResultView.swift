import SwiftUI

struct CompressionResultView: View {
    let result: CompressionResult
    @Bindable var model: SendFitModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Ready to Send").font(.title.bold())
                HStack(spacing: 12) {
                    ResultMetric(title: "Before", value: FileSizeFormatter.string(bytes: result.source.fileSizeBytes))
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    ResultMetric(title: "After", value: FileSizeFormatter.string(bytes: result.outputSizeBytes))
                }
                Text("\(result.reductionPercentage)% smaller")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                Text("\(result.dimensions.displayName) · \(Int(result.frameRate.rounded())) fps · \(Duration.seconds(result.duration).formatted(.time(pattern: .minuteSecond)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    Button { Task { await model.saveResult() } } label: {
                        Label("Save Video", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { model.showShareSheet() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button("Compress Another", action: model.compressAnother)
                        .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

private struct ResultMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }
}
