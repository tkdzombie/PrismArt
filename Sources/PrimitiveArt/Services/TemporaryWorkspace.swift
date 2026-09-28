#if os(macOS)
import Foundation

enum TemporaryWorkspace {
    private static let folderName = "PrismArt"

    static var baseURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    static var importsURL: URL {
        baseURL.appendingPathComponent("Imports", isDirectory: true)
    }

    static func cleanStaleWorkspaces() {
        cleanAll()
    }

    static func cleanAll() {
        try? FileManager.default.removeItem(at: baseURL)
    }

    static func createRenderWorkspace() throws -> URL {
        let renders = baseURL.appendingPathComponent("Renders", isDirectory: true)
        try FileManager.default.createDirectory(at: renders, withIntermediateDirectories: true)
        let url = renders.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func importFile(data: Data, fileExtension: String = "png") throws -> URL {
        try FileManager.default.createDirectory(at: importsURL, withIntermediateDirectories: true)
        let ext = fileExtension.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let safeExtension = ext.isEmpty ? "png" : String(ext.prefix(8))
        let url = importsURL.appendingPathComponent("\(UUID().uuidString).\(safeExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func remove(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
