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
    /// UTF-8 优先，失败时回退 GB18030（部分 Rime 词库为 GBK 编码）。
    /// UTF-8 是 ASCII 的超集，ASCII 回退永远不会命中，故不再尝试。
    func readFileContent(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        if let content = String(data: data, encoding: .utf8) {
            return content
        }
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        return String(data: data, encoding: gb18030) ?? ""
    }

    /// Write content to a file, optionally creating a backup first.
    func writeFileContent(_ content: String, to url: URL, shouldBackup: Bool = true) throws {
        try rejectSymlink(at: url)
        if shouldBackup && fm.fileExists(atPath: url.path) {
            guard createBackup(of: url) != nil else {
                throw FileManagerError.backupFailed(url)
            }
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
        guard !isSymbolicLink(at: url) else { return nil }
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
        // A backup containing a symlink could later overwrite files outside Rime.
        guard (try? rejectSymlinkRecursively(in: directoryURL)) != nil else { return nil }
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
    func exportConfigAsZip(from sourceURL: URL, to destinationURL: URL) throws {
        try rejectSymlink(at: destinationURL)
        try rejectSymlinkRecursively(in: sourceURL)
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        // macOS ditto has no --exclude option. Stage only the portable config
        // entries so user dictionaries, sync state, and backups never leave Rime.
        let stageRoot = fm.temporaryDirectory
            .appendingPathComponent("rime_export_\(UUID().uuidString)")
        let stage = stageRoot.appendingPathComponent(sourceURL.lastPathComponent)
        defer { try? fm.removeItem(at: stageRoot) }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)

        let entries = try fm.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
        for entry in entries {
            let name = entry.lastPathComponent
            if name == "backups" || name == "build" || name == "sync" || name == "userdb"
                || name.hasPrefix("backup_") { continue }
            try fm.copyItem(at: entry, to: stage.appendingPathComponent(name))
        }

        let process = Process()
        process.launchPath = "/usr/bin/ditto"
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent",
                             stage.path, destinationURL.path]
        process.launch()
        process.waitUntilExit()

        guard process.terminationStatus == 0, fm.fileExists(atPath: destinationURL.path) else {
            try? fm.removeItem(at: destinationURL)
            throw FileManagerError.exportFailed
        }
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
        try rejectSymlink(at: sourceURL)
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
        guard createFullBackup(of: rimeDirURL) != nil else {
            throw FileManagerError.backupFailed(rimeDirURL)
        }

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

        // Extracted archives are untrusted: symlink entries can make later config
        // writes escape the selected Rime directory.
        try rejectSymlinkRecursively(in: tempDir)

        // 解压根：兼容带顶层目录的 zip（--keepParent 导出）与直接平铺文件的 zip
        let contents = (try? fm.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        var sourceRoot = tempDir
        if contents.count == 1,
           let isDir = try? contents[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
           isDir {
            sourceRoot = contents[0]
        }

        // Copy files from extracted directory to Rime directory
        let extractedFiles = (try? fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: nil)) ?? []
        guard !extractedFiles.isEmpty else {
            throw FileManagerError.writeFailed("No Rime config found in ZIP")
        }
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

    // MARK: - Symlink safety

    private func isSymbolicLink(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
    }

    private func rejectSymlink(at url: URL) throws {
        guard !isSymbolicLink(at: url) else {
            throw FileManagerError.symbolicLinkRejected(url)
        }
    }

    private func rejectSymlinkRecursively(in url: URL) throws {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else {
            throw FileManagerError.readFailed(url)
        }

        for case let item as URL in enumerator where isSymbolicLink(at: item) {
            throw FileManagerError.symbolicLinkRejected(item)
        }
    }

    func rejectSymbolicLinksRecursively(in url: URL) throws {
        try rejectSymlinkRecursively(in: url)
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
    case backupFailed(URL)
    case exportFailed
    case readFailed(URL)
    case symbolicLinkRejected(URL)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode content as UTF-8."
        case .writeFailed(let path):
            return "Failed to write file: \(path)"
        case .backupFailed(let url):
            return "Backup failed: \(url.lastPathComponent)"
        case .exportFailed:
            return "Failed to export configuration ZIP."
        case .readFailed(let url):
            return "Failed to read directory: \(url.lastPathComponent)"
        case .symbolicLinkRejected(let url):
            return "Rejected symbolic link for safety: \(url.lastPathComponent)"
        }
    }
}
