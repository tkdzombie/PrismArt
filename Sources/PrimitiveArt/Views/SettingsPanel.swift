#if os(macOS)
import SwiftUI
import PrimitiveCore

struct SettingsPanel: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider()
                presetSection
                shapeSection
                qualitySection
                exportSection
                generateButton
                privacyNote
            }
            .padding(18)
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "triangle.inset.filled")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("PrismArt")
                    .font(.title2.bold())
            }
            Text("Turn photos into geometric artwork.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var presetSection: some View {
        GroupBox("Style") {
            VStack(alignment: .leading, spacing: 11) {
                Picker("Preset", selection: Binding(
                    get: { model.selectedPreset },
                    set: { model.applyPreset($0) }
                )) {
                    ForEach(ArtPreset.allCases) { preset in
                        Label(preset.displayName, systemImage: preset.symbolName)
                            .tag(preset)
                    }
                }
                .pickerStyle(.menu)

                if model.selectedPreset == .custom {
                    Text("Custom settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Presets are starting points — changing a control switches to Custom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var shapeSection: some View {
        GroupBox("Geometry") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Shape", selection: $model.settings.shapeMode) {
                    ForEach(ShapeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                labeledSlider(
                    title: "Shapes",
                    value: Binding(
                        get: { Double(model.settings.shapeCount) },
                        set: { model.settings.shapeCount = Int($0.rounded()) }
                    ),
                    range: 25...800,
                    step: 25,
                    valueText: "\(model.settings.shapeCount)"
                )

                labeledSlider(
                    title: "Opacity",
                    value: Binding(
                        get: { Double(model.settings.alpha) },
                        set: { model.settings.alpha = Int($0.rounded()) }
                    ),
                    range: 0...255,
                    step: 1,
                    valueText: model.settings.alpha == 0 ? "Auto" : "\(model.settings.alpha)"
                )
            }
            .padding(8)
        }
    }

    private var qualitySection: some View {
        GroupBox("Quality") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Analysis", selection: $model.settings.inputSize) {
                    Text("128 px · Fast").tag(128)
                    Text("256 px · Balanced").tag(256)
                    Text("512 px · Detailed").tag(512)
                }

                Picker("Output", selection: $model.settings.outputSize) {
                    Text("1024 px").tag(1024)
                    Text("1536 px").tag(1536)
                    Text("2048 px").tag(2048)
                    Text("4096 px").tag(4096)
                    Text("8192 px").tag(8192)
                }

                Label("Quick preview uses up to 72 shapes at 128 px analysis size.", systemImage: "bolt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var exportSection: some View {
        GroupBox("Export") {
            Picker("Format", selection: $model.settings.format) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
        }
    }

    private var generateButton: some View {
        Button {
            model.generate()
        } label: {
            Label(model.isRendering ? "Rendering…" : "Generate Full Quality", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canGenerate)
        .keyboardShortcut(.return, modifiers: [.command])
    }

    private var privacyNote: some View {
        Label {
            Text("Local-only processing. PrismArt does not create an app database, login item, or background service.")
        } icon: {
            Image(systemName: "lock.shield")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func labeledSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
#endif
