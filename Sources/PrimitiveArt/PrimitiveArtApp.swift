#if os(macOS)
import SwiftUI

@main
struct PrismArtApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup("PrismArt") {
            ContentView(model: model)
                .frame(minWidth: 1020, minHeight: 660)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…") { model.openImagePanel() }
                    .keyboardShortcut("o")
                Button("Paste Image") { model.pasteImageFromClipboard() }
                    .keyboardShortcut("v")
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save Result As…") { model.saveResultPanel() }
                    .keyboardShortcut("s")
                    .disabled(model.resultURL == nil)
            }

            CommandMenu("Render") {
                Button("Generate Full Quality") { model.generate() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.canGenerate)
                Button("Cancel Render") { model.cancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!model.isRendering && !model.isPreviewing)
                Divider()
                Button("Copy Artwork") { model.copyPreviewToClipboard() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!model.hasArtworkPreview)
            }
        }
    }
}
#else
import Foundation

@main
struct PrismArtApp {
    static func main() {
        print("PrismArt GUI is available on macOS 13 or later.")
    }
}
#endif
