#if os(macOS)
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        HSplitView {
            SettingsPanel(model: model)
                .frame(minWidth: 270, idealWidth: 300, maxWidth: 330)

            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(.background)
                    if model.inputImage == nil {
                        DropZone(model: model)
                            .padding(34)
                    } else {
                        ImagePreview(model: model)
                            .padding(24)
                    }
                }

                Divider()
                statusBar
            }
            .frame(minWidth: 650)
        }
        .onOpenURL { url in
            model.setInput(url)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.openImagePanel()
                } label: {
                    Label("Open", systemImage: "photo")
                }
                .help("Open Image (⌘O)")

                Button {
                    model.pasteImageFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .help("Paste an image from the clipboard")
            }

            ToolbarItemGroup {
                Button {
                    model.generate()
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .disabled(!model.canGenerate)
                .help("Generate Full Quality (⌘Return)")

                if model.isRendering || model.isPreviewing {
                    Button {
                        model.cancel()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .help("Cancel the current render")
                }
            }

            ToolbarItemGroup {
                Button {
                    model.copyPreviewToClipboard()
                } label: {
                    Label("Copy Artwork", systemImage: "doc.on.doc")
                }
                .disabled(!model.hasArtworkPreview)

                Button {
                    model.saveResultPanel()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(model.resultURL == nil)
                .help("Save Full-Quality Result (⌘S)")
            }
        }
        .alert("PrismArt", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if model.isRendering || model.isPreviewing {
                ProgressView(value: model.progress)
                    .frame(width: 130)
            }

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if model.isRendering {
                Text("Full quality")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            } else if model.isPreviewing {
                Text("Quick preview")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            } else if model.resultURL != nil {
                Button("Save Result As…") { model.saveResultPanel() }
                    .controlSize(.small)
                    .keyboardShortcut("s")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(.bar)
    }
}
#endif
