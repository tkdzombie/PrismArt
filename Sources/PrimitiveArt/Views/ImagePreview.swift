#if os(macOS)
import SwiftUI

struct ImagePreview: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.inputDisplayName ?? "Image")
                        .font(.headline)
                        .lineLimit(1)
                    if model.resultImage != nil {
                        Label("Full-quality result", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if model.quickPreviewImage != nil {
                        Label("Quick preview", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if model.hasArtworkPreview {
                    Picker("Preview", selection: $model.showOriginal) {
                        Text("Artwork").tag(false)
                        Text("Original").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                Button {
                    model.openImagePanel()
                } label: {
                    Image(systemName: "photo.badge.plus")
                }
                .help("Choose a different image")
            }

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.055))

                    if let image = displayedImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: proxy.size.width - 28, maxHeight: proxy.size.height - 28)
                            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                    }

                    if model.isPreviewing && !model.showOriginal {
                        HStack(spacing: 9) {
                            ProgressView(value: model.progress)
                                .frame(width: 120)
                            Text("Updating preview…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private var displayedImage: NSImage? {
        if model.showOriginal || !model.hasArtworkPreview { return model.inputImage }
        return model.artworkImage
    }
}
#endif
