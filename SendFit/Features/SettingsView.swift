import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: SendFitModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Text("Your videos never leave your device. Video compression happens entirely on your iPhone or iPad.")
                    if model.privacyOptionsRequired {
                        Button("Privacy Options", action: model.presentPrivacyOptions)
                    }
                }
                Section("About") {
                    Text("Advertising uses Google Mobile Ads when consent permits. Advertising availability never affects compression.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss.callAsFunction) }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
