import Foundation

public struct PrimitiveCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        input: URL,
        outputs: [URL],
        settings: RenderSettings,
        frameStride: Int? = nil,
        verbose: Bool = true
    ) throws -> [String] {
        let settings = try settings.validated()
        guard !input.path.isEmpty else { throw RenderValidationError.missingInput }
        guard !outputs.isEmpty else { throw RenderValidationError.missingOutput }

        var args: [String] = [
            "-i", input.path,
            "-n", String(settings.shapeCount),
            "-m", String(settings.shapeMode.rawValue),
            "-a", String(settings.alpha),
            "-r", String(settings.inputSize),
            "-s", String(settings.outputSize),
            // Upstream defines 0 as "use all cores". Keeping it explicit makes the
            // performance policy deterministic on Apple Silicon and Intel Macs.
            "-j", "0"
        ]

        if let frameStride {
            args += ["-nth", String(max(1, frameStride))]
        }

        for output in outputs {
            args += ["-o", output.path]
        }

        if verbose { args.append("-v") }
        return args
    }
}
