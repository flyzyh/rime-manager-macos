import Foundation

/// Detects and validates Rime configuration directories on macOS.
final class RimePathService {

    /// The standard Rime configuration directory for Squirrel (macOS).
    /// Usually ~/Library/Rime
    var defaultRimeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Rime")
    }

    /// Check if a directory looks like a valid Rime configuration directory.
    func isValidRimeDirectory(_ url: URL) -> Bool {
        // Check for key indicator files
        let indicators = [
            "default.yaml",
            "squirrel.yaml",
            "installation.yaml",
            "user.yaml"
        ]

        let fm = FileManager.default
        for indicator in indicators {
            let fileURL = url.appendingPathComponent(indicator)
            if fm.fileExists(atPath: fileURL.path) {
                return true
            }
        }
        return false
    }

    /// Auto-detect the Rime directory. Returns nil if not found.
    func detectDefaultRimeDirectory() -> URL? {
        let url = defaultRimeDirectory
        if FileManager.default.fileExists(atPath: url.path) && isValidRimeDirectory(url) {
            return url
        }
        return nil
    }

    /// List all .schema.yaml files in the directory.
    func findSchemaFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { element -> URL? in
            guard let url = element as? URL else { return nil }
            let name = url.lastPathComponent.lowercased()
            if name.hasSuffix(".schema.yaml") || name.hasSuffix(".schema.yml") {
                return url
            }
            return nil
        }
    }

    /// Get the Rime build directory (compiled outputs).
    var buildDirectory: URL? {
        let url = defaultRimeDirectory.appendingPathComponent("build")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return url
        }
        return nil
    }

    /// Get the Squirrel application path.
    var squirrelAppPath: String {
        "/Library/Input Methods/Squirrel.app"
    }

    /// Get the Squirrel user data directory (synced config).
    var squirrelUserDataDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Squirrel")
    }
}
