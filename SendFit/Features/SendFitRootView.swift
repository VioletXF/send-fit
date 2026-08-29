import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SendFitRootView: View {
    @State private var model = SendFitModel()
    @State private var photosItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .empty:
                    EmptyStateView(openFiles: { model.isShowingFileImporter = true }, photosItem: $photosItem)
                case .selected(let asset):
                    SelectedVideoView(asset: asset, model: model, photosItem: $photosItem)
                case .compressing(let asset):
                    CompressionProgressView(asset: asset, model: model)
                case .result(let result):
                    CompressionResultView(result: result, model: model)
                }
            }
            .navigationTitle("SendFit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { model.isShowingSettings = true }
                        .accessibilityLabel("Settings")
                }
            }
        }
        .task {
            await model.initialize()
            await model.openSharedVideo()
        }
        .onChange(of: photosItem) { _, item in
            guard let item else { return }
            // PhotosPicker retains its bound item between presentations. Clear it
            // before importing so selecting the same video in a later session is
            // treated as a new selection rather than reusing stale picker state.
            photosItem = nil
            Task { await model.handlePhotosPicker(item) }
        }
        .fileImporter(isPresented: $model.isShowingFileImporter, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await model.selectFile(url: url, source: .files) }
            }
        }
        .onOpenURL { url in
            Task {
                if url.scheme == "sendfit", url.host == "share" {
                    await model.openSharedVideo()
                } else {
                    await model.openExternally(url: url)
                }
            }
        }
        .alert("SendFit", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $model.isShowingShareSheet) {
            if let result = model.result { ShareSheet(items: [result.outputURL]) }
        }
    }
}
