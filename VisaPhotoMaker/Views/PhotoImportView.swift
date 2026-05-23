import PhotosUI
import SwiftUI
import UIKit

struct PhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    @Binding var editState: PhotoEditState

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var draftImage: UIImage?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                if let draftImage {
                    Image(uiImage: draftImage)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        Text(L10n.text(en: "Choose a clear front-facing photo", zh: "从相册选择一张正面照片"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(L10n.text(L10n.importPhoto), systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if let draftImage {
                    image = draftImage
                    editState = .default
                    dismiss()
                }
            } label: {
                Text(L10n.text(en: "Use This Photo", zh: "使用这张照片"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(draftImage == nil)

            Spacer()
        }
        .padding(18)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.text(en: "Upload Photo", zh: "上传照片"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(from: item) }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else {
            return
        }
        draftImage = loaded.preparedForIDPhotoProcessing()
    }
}

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    @Binding var editState: PhotoEditState
    let spec: PhotoSpec

    var body: some View {
        CameraPicker(spec: spec, image: Binding(
            get: { image },
            set: { newImage in
                image = newImage
                editState = .default
                if newImage != nil {
                    dismiss()
                }
            }
        ))
        .ignoresSafeArea()
        .navigationTitle(L10n.text(L10n.camera))
        .navigationBarTitleDisplayMode(.inline)
    }
}
