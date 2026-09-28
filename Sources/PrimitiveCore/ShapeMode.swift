import Foundation

public enum ShapeMode: Int, CaseIterable, Identifiable, Codable, Sendable {
    case combo = 0
    case triangle = 1
    case rectangle = 2
    case ellipse = 3
    case circle = 4
    case rotatedRectangle = 5
    case bezier = 6
    case rotatedEllipse = 7
    case polygon = 8

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .combo: "Combo"
        case .triangle: "Triangle"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .circle: "Circle"
        case .rotatedRectangle: "Rotated Rectangle"
        case .bezier: "Bezier"
        case .rotatedEllipse: "Rotated Ellipse"
        case .polygon: "Polygon"
        }
    }
}
