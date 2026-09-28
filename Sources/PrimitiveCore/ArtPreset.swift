import Foundation

public enum ArtPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case balanced
    case portrait
    case landscape
    case architecture
    case abstract
    case minimal
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .balanced: "Balanced"
        case .portrait: "Portrait"
        case .landscape: "Landscape"
        case .architecture: "Architecture"
        case .abstract: "Abstract"
        case .minimal: "Minimal"
        case .custom: "Custom"
        }
    }

    public var symbolName: String {
        switch self {
        case .balanced: "slider.horizontal.3"
        case .portrait: "person.crop.square"
        case .landscape: "mountain.2"
        case .architecture: "building.2"
        case .abstract: "scribble.variable"
        case .minimal: "circle.grid.cross"
        case .custom: "wrench.and.screwdriver"
        }
    }

    public var settings: RenderSettings? {
        switch self {
        case .balanced:
            RenderSettings(shapeMode: .triangle, shapeCount: 180, alpha: 128, inputSize: 256, outputSize: 2048, format: .png)
        case .portrait:
            RenderSettings(shapeMode: .triangle, shapeCount: 240, alpha: 112, inputSize: 256, outputSize: 2048, format: .png)
        case .landscape:
            RenderSettings(shapeMode: .polygon, shapeCount: 220, alpha: 144, inputSize: 256, outputSize: 2048, format: .png)
        case .architecture:
            RenderSettings(shapeMode: .rotatedRectangle, shapeCount: 220, alpha: 150, inputSize: 256, outputSize: 2048, format: .png)
        case .abstract:
            RenderSettings(shapeMode: .combo, shapeCount: 150, alpha: 104, inputSize: 256, outputSize: 2048, format: .png)
        case .minimal:
            RenderSettings(shapeMode: .circle, shapeCount: 80, alpha: 160, inputSize: 192, outputSize: 1536, format: .png)
        case .custom:
            nil
        }
    }

    public static func matching(_ settings: RenderSettings) -> ArtPreset {
        for preset in allCases where preset != .custom {
            if let value = preset.settings,
               value.shapeMode == settings.shapeMode,
               value.shapeCount == settings.shapeCount,
               value.alpha == settings.alpha,
               value.inputSize == settings.inputSize,
               value.outputSize == settings.outputSize {
                return preset
            }
        }
        return .custom
    }
}
