import Foundation

/// Handles file system operations for the Rime configuration directory.
final class FileManagerService {

    private let fm = FileManager.default

    // MARK: - Directory scanning

    /// Recursively scan a directory and return a tree of RimeConfigFile nodes.
    func scanDirectory(_ url: URL) -> [RimeConfigFile] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .compactMap { fileURL -> RimeConfigFile? in
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                // Skip certain directories
                let name = fileURL.lastPathComponent
                if isDir && (name.hasPrefix(".") || name == "userdb" || name == "sync") {
                    return nil
                }

                let children: [RimeConfigFile]? = isDir ? scanDirectory(fileURL) : nil
                return RimeConfigFile(url: fileURL, isDirectory: isDir, children: children)
            }
            .sorted { lhs, rhs in
                // Directories first, then by name
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    // MARK: - File content

    /// Read the content of a text file.
    func readFileContent(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            // Try other encodings
            if let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .ascii) {
                return content
            }
            return ""
        }
        return content
    }

    /// Write content to a file, optionally creating a backup first.
    func writeFileContent(_ content: String, to url: URL, shouldBackup: Bool = true) throws {
        if shouldBackup && fm.fileExists(atPath: url.path) {
            createBackup(of: url)
        }
        guard let data = content.data(using: .utf8) else {
            throw FileManagerError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Backup

    /// Create a timestamped backup of a file in a backup subdirectory.
    @discardableResult
    func createBackup(of url: URL) -> URL? {
        let backupDir = url.deletingLastPathComponent()
            .appendingPathComponent("backup_\(dateFormatter.string(from: Date()))")

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let destURL = backupDir.appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: url, to: destURL)
            return destURL
        } catch {
            print("Backup failed for \(url.path): \(error)")
            return nil
        }
    }

    /// Create a full directory backup inside Rime/backups/ with timestamp.
    func createFullBackup(of directoryURL: URL) -> URL? {
        let backupDir = directoryURL.appendingPathComponent("backups")
        let backupName = "backup_\(dateFormatter.string(from: Date()))"
        let backupURL = backupDir.appendingPathComponent(backupName)

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            // Copy Rime files (excluding backups subdir and build cache)
            if fm.fileExists(atPath: backupURL.path) {
                try fm.removeItem(at: backupURL)
            }
            try fm.createDirectory(at: backupURL, withIntermediateDirectories: true)

            let contents = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            for file in contents {
                let name = file.lastPathComponent
                // Skip backups, build cache, userdb
                if name == "backups" || name == "build" || name.hasSuffix(".userdb") { continue }
                let dest = backupURL.appendingPathComponent(name)
                try fm.copyItem(at: file, to: dest)
            }
            return backupURL
        } catch {
            print("Full backup failed: \(error)")
            return nil
        }
    }

    // MARK: - Import / Export

    /// Export the entire Rime configuration directory as a ZIP file.
    func exportConfigAsZip(from sourceURL: URL) -> URL? {
        let downloadsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        let timestamp = dateFormatter.string(from: Date())
        let zipName = "RimeConfig_\(timestamp).zip"
        let zipURL = downloadsDir.appendingPathComponent(zipName)

        // Remove existing zip
        if fm.fileExists(atPath: zipURL.path) {
            try? fm.removeItem(at: zipURL)
        }

        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent",
                             sourceURL.path, zipURL.path]
        process.launch()
        process.waitUntilExit()

        if process.terminationStatus == 0 && fm.fileExists(atPath: zipURL.path) {
            return zipURL
        }
        return nil
    }

    /// Export a single file to a user-chosen location.
    func exportFile(from sourceURL: URL, to destinationURL: URL) throws {
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.copyItem(at: sourceURL, to: destinationURL)
    }

    /// Import a single file into the Rime config directory.
    func importFile(from sourceURL: URL, to rimeDirURL: URL) throws -> URL {
        let filename = sourceURL.lastPathComponent
        let destURL = rimeDirURL.appendingPathComponent(filename)

        // Create backup if file exists
        if fm.fileExists(atPath: destURL.path) {
            createBackup(of: destURL)
        }

        // Remove existing and copy new
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    /// Import a ZIP file containing Rime config into the Rime directory.
    func importZip(from zipURL: URL, to rimeDirURL: URL) throws {
        // Create a backup of the entire directory first
        createFullBackup(of: rimeDirURL)

        // Unzip to a temp directory
        let tempDir = fm.temporaryDirectory.appendingPathComponent("rime_import_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempDir) }

        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = ["-x", "-k", zipURL.path, tempDir.path]
        process.launch()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw FileManagerError.writeFailed("Failed to extract ZIP file")
        }

        // Find the Rime directory inside the extracted content
        let contents = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
        guard let rimeSource = contents.first else {
            throw FileManagerError.writeFailed("No Rime config found in ZIP")
        }

        // Copy files from extracted directory to Rime directory
        let extractedFiles = (try? fm.contentsOfDirectory(at: rimeSource, includingPropertiesForKeys: nil)) ?? []
        for fileURL in extractedFiles {
            let fileName = fileURL.lastPathComponent
            let destURL = rimeDirURL.appendingPathComponent(fileName)

            if fm.fileExists(atPath: destURL.path) {
                try? fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: fileURL, to: destURL)
        }
    }

    // MARK: - File info

    /// Check if a file exists.
    func fileExists(at url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }

    /// Get the file size as a human-readable string.
    func humanReadableSize(for url: URL) -> String? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize as? Int64 else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - Helpers

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()
}

enum FileManagerError: LocalizedError {
    case encodingFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode content as UTF-8."
        case .writeFailed(let path):
            return "Failed to write file: \(path)"
        }
    }
}
