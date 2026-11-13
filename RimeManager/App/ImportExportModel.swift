import SwiftUI
import AppKit

/// Manages import, export, and backup operations.
@MainActor
final class ImportExportModel: ObservableObject {
    private let fileService: FileManaging

    init(fileService: FileManaging = FileManagerService()) {
        self.fileService = fileService
    }

    // MARK: - Export

    func exportCurrentConfig(from rimeDirectory: URL?) {
        guard let dirURL = rimeDirectory else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "export.config_title".localized
        savePanel.nameFieldStringValue = "RimeConfig_\(Date().formatted(.iso8601.dateSeparator(.dash))).zip"
        savePanel.allowedContentTypes = [.zip]

        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            do {
                try fileService.exportConfigAsZip(from: dirURL, to: destURL)
                NSWorkspace.shared.activateFileViewerSelecting([destURL])
                FeedbackManager.shared.showSuccess("export.success".localized)
            } catch {
                FeedbackManager.shared.showError("export.failed".localized)
            }
        }
    }

    func exportSelectedFile(_ file: RimeConfigFile?) {
        guard let file = file, !file.isDirectory else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "export.file_title".localized
        savePanel.nameFieldStringValue = file.name

        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            do {
                try fileService.exportFile(from: file.url, to: destURL)
                NSWorkspace.shared.activateFileViewerSelecting([destURL])
                FeedbackManager.shared.showSuccess("export.success".localized)
            } catch {
                FeedbackManager.shared.showError("export.failed".localized)
            }
        }
    }

    // MARK: - Import

    func importConfig(to rimeDirectory: URL?, onComplete: @escaping () -> Void) {
        guard let dirURL = rimeDirectory else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "import.title".localized
        openPanel.allowedContentTypes = [.zip, .yaml, .json, .plainText]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let sourceURL = openPanel.url {
            do {
                if sourceURL.pathExtension.lowercased() == "zip" {
                    try fileService.importZip(from: sourceURL, to: dirURL)
                } else {
                    _ = try fileService.importFile(from: sourceURL, to: dirURL)
                }
                onComplete()
                FeedbackManager.shared.showSuccess("import.success".localized)
            } catch {
                FeedbackManager.shared.showAlert(for: .importFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Backup

    func createBackup(of rimeDirectory: URL?) {
        guard let dirURL = rimeDirectory else { return }

        if let backupURL = fileService.createFullBackup(of: dirURL) {
            NSWorkspace.shared.activateFileViewerSelecting([backupURL])
            FeedbackManager.shared.showSuccess("backup.success".localized)
        } else {
            FeedbackManager.shared.showError("backup.failed".localized)
        }
    }

    // MARK: - Backup List Management

    func listBackups(in rimeDirectory: URL?) -> [URL] {
        guard let d = rimeDirectory else { return [] }
        let bd = d.appendingPathComponent("backups")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: bd,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        return files
            .filter { $0.lastPathComponent.hasPrefix("backup_") }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return dateA > dateB
            }
    }

    func restoreBackup(_ backupURL: URL, to rimeDirectory: URL?) {
        guard let rd = rimeDirectory else { return }

        // Create a safety backup first
        guard fileService.createFullBackup(of: rd) != nil else {
            FeedbackManager.shared.showError("backup.failed".localized)
            return
        }

        // Restore files
        do {
            try fileService.rejectSymbolicLinksRecursively(in: backupURL)
            let files = try FileManager.default.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil)
            try stageAndRestore(files, from: backupURL, to: rd)
            FeedbackManager.shared.showSuccess("backup.restored".localized)
        } catch {
            FeedbackManager.shared.showAlert(for: .backupFailed(error.localizedDescription))
        }
    }

    private func stageAndRestore(_ files: [URL], from backupURL: URL, to destination: URL) throws {
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("rime_restore_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: stage) }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)

        // Stage a complete copy first so copy failures leave the active config untouched.
        for f in files {
            try fm.copyItem(at: f, to: stage.appendingPathComponent(f.lastPathComponent))
        }
        let stagedFiles = try fm.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil)

        for f in stagedFiles {
            let dest = destination.appendingPathComponent(f.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: f, to: dest)
        }
    }

    func deleteBackup(_ backupURL: URL) {
        try? FileManager.default.removeItem(at: backupURL)
        FeedbackManager.shared.showInfo("backup.deleted".localized)
    }
}
