import SwiftUI

struct CompressionProgressView: View {
    let asset: VideoAsset
    @Bindable var model: SendFitModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 52))
                .symbolEffect(.rotate, options: .repeating)
            Text(model.stage).font(.title2.bold())
            ProgressView(value: model.progress)
                .accessibilityLabel("Compression progress")
                .accessibilityValue("\(Int(model.progress * 100)) percent")
            Text("\(Int(model.progress * 100))%")
                .font(.headline.monospacedDigit())
            Text("Your video stays on this device while it is compressed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            BannerAdView(enabled: true, adUnitID: AdConfiguration.current.bannerAdUnitID)
                .frame(height: 50)
                .accessibilityLabel("Sponsored advertisement")
            Button("Cancel", role: .cancel, action: model.cancelCompression)
                .buttonStyle(.bordered)
                .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}
