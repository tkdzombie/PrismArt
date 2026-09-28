import Foundation

public struct RenderSettings: Equatable, Codable, Sendable {
    public var shapeMode: ShapeMode = .triangle
    public var shapeCount: Int = 1000
    public var alpha: Int = 128
    public var inputSize: Int = 256
    public var outputSize: Int = 2048
    public var format: OutputFormat = .png

    public init(
        shapeMode: ShapeMode = .triangle,
        shapeCount: Int = 1000,
        alpha: Int = 128,
        inputSize: Int = 256,
        outputSize: Int = 2048,
        format: OutputFormat = .png
    ) {
        self.shapeMode = shapeMode
        self.shapeCount = shapeCount
        self.alpha = alpha
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.format = format
    }

    public func validated() throws -> RenderSettings {
        guard (1...5_000).contains(shapeCount) else { throw RenderValidationError.invalidShapeCount }
        guard (0...255).contains(alpha) else { throw RenderValidationError.invalidAlpha }
        guard (32...2_048).contains(inputSize) else { throw RenderValidationError.invalidInputSize }
        guard (128...8_192).contains(outputSize) else { throw RenderValidationError.invalidOutputSize }
        return self
    }

    /// A deliberately cheap render used for responsive previews while preserving the
    /// artistic choices of the final settings.
    public func quickPreviewSettings() -> RenderSettings {
        var preview = self
        preview.shapeCount = min(180, max(64, shapeCount / 5))
        preview.inputSize = min(inputSize, 256)
        preview.outputSize = min(outputSize, 1_536)
        preview.format = .png
        return preview
    }
}

public enum RenderValidationError: LocalizedError, Equatable {
    case invalidShapeCount
    case invalidAlpha
    case invalidInputSize
    case invalidOutputSize
    case missingInput
    case missingOutput

    public var errorDescription: String? {
        switch self {
        case .invalidShapeCount: "Shape count must be between 1 and 5000."
        case .invalidAlpha: "Alpha must be between 0 and 255."
        case .invalidInputSize: "Input size must be between 32 and 2048 pixels."
        case .invalidOutputSize: "Output size must be between 128 and 8192 pixels."
        case .missingInput: "Choose an input image first."
        case .missingOutput: "At least one output path is required."
        }
    }
}
