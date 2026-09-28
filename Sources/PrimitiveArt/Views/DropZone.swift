#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    @ObservedObject var model: AppViewModel
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "triangle.inset.filled")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 7) {
                Text("Create geometric art")
                    .font(.title2.weight(.semibold))
                Text("Drop an image, paste one, or choose a file")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Choose Image…") { model.openImagePanel() }
                    .buttonStyle(.borderedProminent)
                Button("Paste Image") { model.pasteImageFromClipboard() }
                    .buttonStyle(.bordered)
            }

            Text("HEIC, JPEG, PNG, TIFF and other formats supported by macOS")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(targeted ? Color.accentColor.opacity(0.09) : Color.secondary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            targeted ? Color.accentColor : Color.secondary.opacity(0.28),
                            style: StrokeStyle(lineWidth: targeted ? 2 : 1.25, dash: [8, 7])
                        )
                )
        )
        .animation(.easeOut(duration: 0.15), value: targeted)
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }

            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in model.setInput(url) }
                }
                return true
            }

            if let contentType = provider.registeredContentTypes.first(where: { $0.conforms(to: .image) }) {
                _ = provider.loadDataRepresentation(for: contentType) { data, _ in
                    guard let data else { return }
                    let fileExtension = contentType.preferredFilenameExtension ?? "img"
                    let displayName = provider.suggestedName ?? "Dropped Image"
                    Task { @MainActor in
                        model.setInput(data: data, suggestedExtension: fileExtension, displayName: displayName)
                    }
                }
                return true
            }

            return false
        }
    }
}
#endif
