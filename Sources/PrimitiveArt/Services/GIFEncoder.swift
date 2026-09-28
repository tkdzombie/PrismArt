#if os(macOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct GIFEncoder: Sendable {
    enum GIFError: LocalizedError {
        case noFrames
        case cannotCreateDestination
        case cannotReadFrame(URL)
        case finalizeFailed

        var errorDescription: String? {
            switch self {
            case .noFrames: "No animation frames were generated."
            case .cannotCreateDestination: "Could not create the GIF output file."
            case .cannotReadFrame(let url): "Could not read animation frame \(url.lastPathComponent)."
            case .finalizeFailed: "Could not finalize the GIF file."
            }
        }
    }

    func encode(frameURLs: [URL], destination: URL, delay: Double = 0.08) throws {
        guard !frameURLs.isEmpty else { throw GIFError.noFrames }
        guard let dest = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.gif.identifier as CFString,
            frameURLs.count,
            nil
        ) else { throw GIFError.cannotCreateDestination }

        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(dest, gifProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: max(0.02, delay),
                kCGImagePropertyGIFUnclampedDelayTime: max(0.02, delay)
            ]
        ]

        for url in frameURLs {
            let added: Bool = autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    return false
                }
                CGImageDestinationAddImage(dest, image, frameProperties as CFDictionary)
                return true
            }
            if !added { throw GIFError.cannotReadFrame(url) }
        }

        guard CGImageDestinationFinalize(dest) else { throw GIFError.finalizeFailed }
    }
}
#endif
