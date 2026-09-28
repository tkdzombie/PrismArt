import Foundation

public enum OutputFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case png, jpeg, svg, gif

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .svg: "SVG"
        case .gif: "GIF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        default: rawValue
        }
    }
}
