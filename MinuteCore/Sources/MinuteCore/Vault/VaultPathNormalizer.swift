import Foundation

public enum VaultPathNormalizer {
    public static func normalizedRelativeComponents(_ path: String) -> [String] {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    public static func directoryURL(from vaultRootURL: URL, relativePath: String) -> URL {
        normalizedRelativeComponents(relativePath).reduce(vaultRootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: true)
        }
    }

    public static func relativePath(from vaultRootURL: URL, to fileURL: URL) -> String {
        let rootPath = vaultRootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        if filePath.hasPrefix(rootPath) {
            var suffix = String(filePath.dropFirst(rootPath.count))
            if suffix.hasPrefix("/") {
                suffix.removeFirst()
            }
            return suffix
        }
        return fileURL.lastPathComponent
    }
}
