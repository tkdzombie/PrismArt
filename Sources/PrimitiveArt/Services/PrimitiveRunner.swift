#if os(macOS)
import Foundation

final class PrimitiveRunner {
    enum RunnerError: LocalizedError {
        case engineMissing
        case launchFailed(String)
        case failed(exitCode: Int32, log: String)

        var errorDescription: String? {
            switch self {
            case .engineMissing:
                "The bundled Primitive engine could not be found. Rebuild PrismArt with scripts/package.sh."
            case .launchFailed(let message):
                "Could not launch the Primitive engine: \(message)"
            case .failed(let code, let log):
                "Primitive exited with code \(code).\n\(log.suffix(4_000))"
            }
        }
    }

    private var process: Process?
    private let lock = NSLock()

    func cancel() {
        lock.lock()
        let running = process
        lock.unlock()
        if running?.isRunning == true {
            running?.terminate()
        }
    }

    func run(
        arguments: [String],
        expectedSteps: Int,
        onProgress: @escaping (Double, String) -> Void
    ) async throws {
        try Task.checkCancellation()
        guard let executable = Self.engineURL(),
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RunnerError.engineMissing
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let process = Process()
                let pipe = Pipe()
                process.executableURL = executable
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                let outputLock = NSLock()
                var logTail = ""
                var lineBuffer = ""

                func appendLog(_ chunk: String) {
                    logTail += chunk
                    if logTail.utf8.count > 32_768 {
                        logTail = String(logTail.suffix(24_000))
                    }
                }

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

                    outputLock.lock()
                    appendLog(chunk)
                    lineBuffer += chunk
                    let lines = lineBuffer.components(separatedBy: .newlines)
                    lineBuffer = lines.last ?? ""
                    outputLock.unlock()

                    for line in lines.dropLast() {
                        if let step = Self.parseStep(line) {
                            let progress = min(1, Double(step) / Double(max(1, expectedSteps)))
                            onProgress(progress, "Drawing shape \(step) of \(expectedSteps)…")
                        }
                    }
                }

                process.terminationHandler = { [weak self] finished in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let tail = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let tailString = String(data: tail, encoding: .utf8) {
                        outputLock.lock()
                        appendLog(tailString)
                        outputLock.unlock()
                    }

                    if let self {
                        self.lock.lock()
                        if self.process === finished { self.process = nil }
                        self.lock.unlock()
                    }

                    outputLock.lock()
                    let captured = logTail
                    outputLock.unlock()

                    if finished.terminationStatus == 0 {
                        onProgress(1, "Finished")
                        continuation.resume()
                    } else if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: RunnerError.failed(
                            exitCode: finished.terminationStatus,
                            log: captured
                        ))
                    }
                }

                do {
                    lock.lock()
                    self.process = process
                    lock.unlock()
                    try process.run()
                } catch {
                    lock.lock()
                    if self.process === process { self.process = nil }
                    lock.unlock()
                    continuation.resume(throwing: RunnerError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }

    private static func parseStep(_ line: String) -> Int? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let prefix = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(prefix)
    }

    private static func engineURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "primitive", withExtension: nil, subdirectory: "bin") {
            return bundled
        }
        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/bin/primitive")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}
#endif
