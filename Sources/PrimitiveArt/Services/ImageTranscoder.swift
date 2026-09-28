#if os(macOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageTranscoder: Sendable {
    enum TranscodeError: LocalizedError {
        case unreadableImage
        case cannotCreateThumbnail
        case cannotCreateDestination
        case cannotEncodePNG

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "The selected image could not be decoded by macOS."
            case .cannotCreateThumbnail: "The selected image could not be prepared for rendering."
            case .cannotCreateDestination: "A temporary image file could not be created."
            case .cannotEncodePNG: "The selected image could not be converted to PNG for the rendering engine."
            }
        }
    }

    /// Normalizes an arbitrary macOS-readable image into a small, orientation-correct PNG.
    /// Primitive downsamples its input anyway, so decoding a 48 MP HEIC at full size only
    /// wastes memory and blocks responsiveness. We cap the source near the requested
    /// working resolution before invoking the engine.
    func makeEngineInput(from sourceURL: URL, in workspace: URL, maxPixelSize: Int) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw TranscodeError.unreadableImage
        }

        let pixelCap = max(128, min(4_096, maxPixelSize))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelCap,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw TranscodeError.cannotCreateThumbnail
        }

        let destination = workspace.appendingPathComponent("input.png")
        guard let writer = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TranscodeError.cannotCreateDestination
        }

        CGImageDestinationAddImage(writer, image, nil)
        guard CGImageDestinationFinalize(writer) else {
            throw TranscodeError.cannotEncodePNG
        }
        return destination
    }
}
#endif
