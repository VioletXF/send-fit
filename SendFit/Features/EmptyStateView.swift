import PhotosUI
import SwiftUI

struct EmptyStateView: View {
    let openFiles: () -> Void
    @Binding var photosItem: PhotosPickerItem?

    var body: some View {
        ContentUnavailableView {
            Label("SendFit", systemImage: "arrow.down.to.line.compact")
        } description: {
            VStack(spacing: 8) {
                Text("Make videos fit any upload limit.")
                Text("Your videos never leave your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } actions: {
            VStack(spacing: 12) {
                PhotosPicker(selection: $photosItem, matching: .videos) {
                    Label("Choose Video", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)

                Button(action: openFiles) {
                    Label("Open from Files", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
