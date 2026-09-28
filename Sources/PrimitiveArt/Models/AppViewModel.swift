#if os(macOS)
import AppKit
import Foundation
import PrimitiveCore
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var inputURL: URL?
    @Published var inputImage: NSImage?
    @Published var inputDisplayName: String?
    @Published var resultURL: URL?
    @Published var resultImage: NSImage?
    @Published var quickPreviewImage: NSImage?
    @Published var selectedPreset: ArtPreset = .balanced
    @Published var settings = RenderSettings() {
        didSet {
            guard oldValue != settings else { return }
            selectedPreset = ArtPreset.matching(settings)
            invalidateFinalResult()
            if oldValue.shapeMode != settings.shapeMode ||
                oldValue.shapeCount != settings.shapeCount ||
                oldValue.alpha != settings.alpha ||
                oldValue.inputSize != settings.inputSize {
                schedulePreview()
            }
        }
    }
    @Published var isRendering = false
    @Published var isPreviewing = false
    @Published var progress = 0.0
    @Published var status = "Drop an image to begin"
    @Published var errorMessage: String?
    @Published var showOriginal = false

    private let commandBuilder = PrimitiveCommandBuilder()
    private var workspaceURL: URL?
    private var importedInputURL: URL?
    private var outputBaseName: String?
    private var activeRunner: PrimitiveRunner?
    private var activeTask: Task<Void, Never>?
    private var previewDebounceTask: Task<Void, Never>?
    private var renderToken = UUID()
    private var terminationObserver: NSObjectProtocol?

    init() {
        TemporaryWorkspace.cleanStaleWorkspaces()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopActiveRendering(silent: true)
                TemporaryWorkspace.cleanAll()
            }
        }
    }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }

    var canGenerate: Bool { inputURL != nil && !isRendering }
    var hasArtworkPreview: Bool { resultImage != nil || quickPreviewImage != nil }

    var artworkImage: NSImage? {
        resultImage ?? quickPreviewImage
    }

    var suggestedOutputName: String {
        let base = outputBaseName ?? "artwork"
        return "\(base)-prismart.\(settings.format.fileExtension)"
    }

    func setInput(_ url: URL) {
        stopActiveRendering(silent: true)
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "That file is not a supported image."
            return
        }

        TemporaryWorkspace.remove(importedInputURL)
        importedInputURL = nil
        inputURL = url
        inputImage = image
        inputDisplayName = url.lastPathComponent
        outputBaseName = url.deletingPathExtension().lastPathComponent
        resetForNewInput()
        status = "Ready — building a quick preview…"
        schedulePreview(delayNanoseconds: 120_000_000)
    }

    func setInput(data: Data, suggestedExtension: String = "png", displayName: String = "Pasted Image") {
        stopActiveRendering(silent: true)
        guard let image = NSImage(data: data) else {
            errorMessage = "The dropped or pasted image could not be decoded."
            return
        }

        do {
            TemporaryWorkspace.remove(importedInputURL)
            let url = try TemporaryWorkspace.importFile(data: data, fileExtension: suggestedExtension)
            importedInputURL = url
            inputURL = url
            inputImage = image
            inputDisplayName = displayName
            let candidate = URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent
            outputBaseName = candidate.isEmpty ? "artwork" : candidate
            resetForNewInput()
            status = "Ready — building a quick preview…"
            schedulePreview(delayNanoseconds: 120_000_000)
        } catch {
            errorMessage = "Could not prepare the image: \(error.localizedDescription)"
        }
    }

    func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image to turn into geometric artwork."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setInput(url)
    }

    func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation else {
            errorMessage = "The clipboard does not contain an image."
            return
        }
        setInput(data: tiff, suggestedExtension: "tiff", displayName: "Pasted Image")
    }

    func applyPreset(_ preset: ArtPreset) {
        selectedPreset = preset
        guard var presetSettings = preset.settings else { return }
        presetSettings.format = settings.format
        settings = presetSettings
    }

    func schedulePreview(delayNanoseconds: UInt64 = 500_000_000) {
        guard inputURL != nil, !isRendering else { return }

        previewDebounceTask?.cancel()
        if isPreviewing {
            activeTask?.cancel()
            activeRunner?.cancel()
            isPreviewing = false
        }

        previewDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                try Task.checkCancellation()
                await self?.startQuickPreview()
            } catch {
                // Debouncing and replacement previews are expected cancellation paths.
            }
        }
    }

    func generate() {
        guard let inputURL else {
            errorMessage = "Choose an input image first."
            return
        }

        previewDebounceTask?.cancel()
        stopActiveRendering(silent: true)
        resultURL = nil
        resultImage = nil
        showOriginal = false
        let token = beginRender()
        isRendering = true
        isPreviewing = false
        progress = 0
        status = "Preparing full-quality render…"
        errorMessage = nil

        activeTask = Task { [weak self] in
            await self?.renderFinal(inputURL: inputURL, token: token)
        }
    }

    func cancel() {
        let hadWork = isRendering || isPreviewing
        stopActiveRendering(silent: true)
        if hadWork { status = "Cancelled" }
    }

    func saveResultPanel() {
        guard let resultURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedOutputName
        if let type = UTType(filenameExtension: settings.format.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: resultURL, to: destination)
            status = "Saved \(destination.lastPathComponent)"
        } catch {
            errorMessage = "Could not save the result: \(error.localizedDescription)"
        }
    }

    func copyPreviewToClipboard() {
        guard let image = artworkImage,
              let tiff = image.tiffRepresentation else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)
        status = "Artwork copied to clipboard"
    }

    private func resetForNewInput() {
        cleanupWorkspace()
        resultURL = nil
        resultImage = nil
        quickPreviewImage = nil
        showOriginal = false
        progress = 0
        errorMessage = nil
    }

    private func invalidateFinalResult() {
        guard inputURL != nil else { return }
        resultURL = nil
        resultImage = nil
        showOriginal = false
    }

    private func startQuickPreview() async {
        guard !isRendering, let inputURL else { return }
        stopActiveRendering(silent: true)
        let token = beginRender()
        isPreviewing = true
        progress = 0
        status = "Quick preview…"

        activeTask = Task { [weak self] in
            await self?.renderPreview(inputURL: inputURL, token: token)
        }
    }

    private func renderPreview(inputURL: URL, token: UUID) async {
        let previewSettings = settings.quickPreviewSettings()
        do {
            let workspace = try TemporaryWorkspace.createRenderWorkspace()
            guard isCurrent(token) else {
                TemporaryWorkspace.remove(workspace)
                return
            }
            replaceWorkspace(with: workspace)

            let engineInput = try await prepareEngineInput(
                inputURL: inputURL,
                workspace: workspace,
                inputSize: previewSettings.inputSize
            )
            try Task.checkCancellation()
            guard isCurrent(token) else { return }

            let output = workspace.appendingPathComponent("quick-preview.png")
            let args = try commandBuilder.arguments(
                input: engineInput,
                outputs: [output],
                settings: previewSettings,
                verbose: true
            )

            let runner = PrimitiveRunner()
            activeRunner = runner
            try await runner.run(arguments: args, expectedSteps: previewSettings.shapeCount) { [weak self] value, _ in
                Task { @MainActor in
                    guard let self, self.isCurrent(token), self.isPreviewing else { return }
                    self.progress = value
                    self.status = "Quick preview \(Int(value * 100))%"
                }
            }
            try Task.checkCancellation()
            guard isCurrent(token) else { return }

            guard let image = NSImage(contentsOf: output) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            quickPreviewImage = image
            progress = 1
            status = "Preview ready — Generate for full quality"
            isPreviewing = false
            activeRunner = nil
        } catch is CancellationError {
            finishCancelledRenderIfCurrent(token)
        } catch {
            if Task.isCancelled {
                finishCancelledRenderIfCurrent(token)
            } else if isCurrent(token) {
                isPreviewing = false
                activeRunner = nil
                progress = 0
                status = "Preview unavailable — full render is still available"
                // Preview failure should not block the user with an alert; final render can
                // still work and will surface a concrete error if it fails too.
            }
        }
    }

    private func renderFinal(inputURL: URL, token: UUID) async {
        do {
            let validated = try settings.validated()
            let workspace = try TemporaryWorkspace.createRenderWorkspace()
            guard isCurrent(token) else {
                TemporaryWorkspace.remove(workspace)
                return
            }
            replaceWorkspace(with: workspace)

            let engineInput = try await prepareEngineInput(
                inputURL: inputURL,
                workspace: workspace,
                inputSize: validated.inputSize
            )
            try Task.checkCancellation()
            guard isCurrent(token) else { return }

            let plan = try makeOutputPlan(workspace: workspace, settings: validated)
            let args = try commandBuilder.arguments(
                input: engineInput,
                outputs: plan.engineOutputs,
                settings: validated,
                frameStride: plan.frameStride,
                verbose: true
            )

            status = "Rendering…"
            let runner = PrimitiveRunner()
            activeRunner = runner
            try await runner.run(arguments: args, expectedSteps: validated.shapeCount) { [weak self] value, _ in
                Task { @MainActor in
                    guard let self, self.isCurrent(token), self.isRendering else { return }
                    self.progress = value
                    self.status = "Rendering \(Int(value * 100))%"
                }
            }
            try Task.checkCancellation()
            guard isCurrent(token) else { return }

            if validated.format == .gif {
                status = "Encoding GIF…"
                var frames = try frameFiles(in: plan.framesDirectory!)
                if let stride = plan.frameStride, validated.shapeCount % stride != 0 {
                    // Primitive's %d output saves every Nth frame. Append the final PNG
                    // when the last iteration is between frame boundaries so the GIF
                    // always lands on the completed artwork.
                    frames.append(plan.preview)
                }
                let destination = plan.finalResult
                try await Task.detached(priority: .userInitiated) {
                    try GIFEncoder().encode(frameURLs: frames, destination: destination, delay: 0.08)
                }.value
            }

            guard let preview = NSImage(contentsOf: plan.preview) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            resultURL = plan.finalResult
            resultImage = preview
            quickPreviewImage = preview
            progress = 1
            status = "Done — save the result when you’re ready"
            isRendering = false
            activeRunner = nil
        } catch is CancellationError {
            finishCancelledRenderIfCurrent(token)
        } catch {
            if Task.isCancelled {
                finishCancelledRenderIfCurrent(token)
            } else if isCurrent(token) {
                isRendering = false
                activeRunner = nil
                status = "Render failed"
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareEngineInput(inputURL: URL, workspace: URL, inputSize: Int) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try ImageTranscoder().makeEngineInput(
                from: inputURL,
                in: workspace,
                maxPixelSize: max(128, inputSize)
            )
        }.value
    }

    private struct OutputPlan {
        let engineOutputs: [URL]
        let preview: URL
        let finalResult: URL
        let framesDirectory: URL?
        let frameStride: Int?
    }

    private func makeOutputPlan(workspace: URL, settings: RenderSettings) throws -> OutputPlan {
        let preview = workspace.appendingPathComponent("preview.png")
        switch settings.format {
        case .png:
            return OutputPlan(engineOutputs: [preview], preview: preview, finalResult: preview, framesDirectory: nil, frameStride: nil)
        case .jpeg:
            let result = workspace.appendingPathComponent("result.jpg")
            return OutputPlan(engineOutputs: [preview, result], preview: preview, finalResult: result, framesDirectory: nil, frameStride: nil)
        case .svg:
            let result = workspace.appendingPathComponent("result.svg")
            return OutputPlan(engineOutputs: [preview, result], preview: preview, finalResult: result, framesDirectory: nil, frameStride: nil)
        case .gif:
            let frames = workspace.appendingPathComponent("frames", isDirectory: true)
            try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
            let pattern = frames.appendingPathComponent("frame-%04d.png")
            let result = workspace.appendingPathComponent("result.gif")
            let stride = max(1, settings.shapeCount / 56)
            return OutputPlan(engineOutputs: [preview, pattern], preview: preview, finalResult: result, framesDirectory: frames, frameStride: stride)
        }
    }

    private func frameFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }

    private func beginRender() -> UUID {
        let token = UUID()
        renderToken = token
        return token
    }

    private func isCurrent(_ token: UUID) -> Bool {
        renderToken == token
    }

    private func finishCancelledRenderIfCurrent(_ token: UUID) {
        guard isCurrent(token) else { return }
        isRendering = false
        isPreviewing = false
        activeRunner = nil
    }

    private func stopActiveRendering(silent: Bool) {
        previewDebounceTask?.cancel()
        previewDebounceTask = nil
        activeTask?.cancel()
        activeTask = nil
        activeRunner?.cancel()
        activeRunner = nil
        renderToken = UUID()
        let hadWork = isRendering || isPreviewing
        isRendering = false
        isPreviewing = false
        progress = 0
        if hadWork && !silent { status = "Cancelled" }
    }

    private func replaceWorkspace(with newWorkspace: URL) {
        if workspaceURL != newWorkspace {
            TemporaryWorkspace.remove(workspaceURL)
        }
        workspaceURL = newWorkspace
    }

    private func cleanupWorkspace() {
        TemporaryWorkspace.remove(workspaceURL)
        workspaceURL = nil
    }
}
#endif
