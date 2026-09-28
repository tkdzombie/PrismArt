#if os(macOS)
import Foundation

final class PrimitiveRunner: @unchecked Sendable {
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

    private final class CancellationState: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }
    }

    private final class OutputAccumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var logTail = ""
        private var lineBuffer = ""

        func consume(_ chunk: String) -> [String] {
            lock.lock()
            defer { lock.unlock() }

            appendLogLocked(chunk)
            lineBuffer += chunk
            let parts = lineBuffer.components(separatedBy: .newlines)
            lineBuffer = parts.last ?? ""
            return Array(parts.dropLast())
        }

        func appendTail(_ chunk: String) {
            lock.lock()
            appendLogLocked(chunk)
            lock.unlock()
        }

        func capturedLog() -> String {
            lock.lock()
            defer { lock.unlock() }
            return logTail
        }

        private func appendLogLocked(_ chunk: String) {
            logTail += chunk
            if logTail.utf8.count > 32_768 {
                logTail = String(logTail.suffix(24_000))
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
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        try Task.checkCancellation()
        guard let executable = Self.engineURL(),
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RunnerError.engineMissing
        }

        let cancellation = CancellationState()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled || cancellation.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let process = Process()
                let pipe = Pipe()
                let output = OutputAccumulator()
                process.executableURL = executable
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

                    let lines = output.consume(chunk)
                    for line in lines {
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
                        output.appendTail(tailString)
                    }

                    if let self {
                        self.lock.lock()
                        if self.process === finished { self.process = nil }
                        self.lock.unlock()
                    }

                    if cancellation.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if finished.terminationStatus == 0 {
                        onProgress(1, "Finished")
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: RunnerError.failed(
                            exitCode: finished.terminationStatus,
                            log: output.capturedLog()
                        ))
                    }
                }

                do {
                    lock.lock()
                    self.process = process
                    lock.unlock()

                    if cancellation.isCancelled {
                        lock.lock()
                        if self.process === process { self.process = nil }
                        lock.unlock()
                        pipe.fileHandleForReading.readabilityHandler = nil
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    try process.run()
                    // Covers the narrow race where cancellation arrived after the
                    // pre-launch check but before Process became running.
                    if cancellation.isCancelled, process.isRunning {
                        process.terminate()
                    }
                } catch {
                    lock.lock()
                    if self.process === process { self.process = nil }
                    lock.unlock()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: RunnerError.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: { [weak self] in
            cancellation.cancel()
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
