import SwiftUI
import Combine

/// Manages file browsing, selection, and editing within the Rime config directory.
@MainActor
final class FileBrowserModel: ObservableObject {
    // MARK: - Published State

    @Published var configFiles: [RimeConfigFile] = []
    @Published var selectedFile: RimeConfigFile? {
        didSet {
            if let file = selectedFile {
                loadFileContent(file)
            } else {
                editingContent = ""
            }
        }
    }

    // MARK: - Editor state

    @Published var editingContent: String = ""
    @Published var isEditing: Bool = false
    @Published var hasUnsavedChanges: Bool = false

    // MARK: - Preview

    @Published var parsedSchema: RimeSchema?
    @Published var colorSchemes: [ColorScheme] = []

    // MARK: - Services

    private let fileService: FileManaging
    private let schemaAnalyzer = SchemaAnalyzer()

    init(fileService: FileManaging = FileManagerService()) {
        self.fileService = fileService
    }

    // MARK: - File Operations

    func reloadFiles(in directory: URL?) {
        guard let url = directory else {
            configFiles = []
            return
        }
        configFiles = fileService.scanDirectory(url)
    }

    private func loadFileContent(_ file: RimeConfigFile) {
        editingContent = fileService.readFileContent(at: file.url)
        isEditing = false
        hasUnsavedChanges = false

        // Parse schema if applicable
        if file.fileType == .schema {
            parsedSchema = schemaAnalyzer.parse(content: editingContent)
            colorSchemes = schemaAnalyzer.extractColorSchemes(from: editingContent)
        } else {
            parsedSchema = nil
            colorSchemes = []
        }
    }

    func saveCurrentFile() throws {
        guard let file = selectedFile else { return }
        let shouldBackup = UserDefaults.standard.object(forKey: "autoBackupBeforeSave") as? Bool ?? true
        try fileService.writeFileContent(editingContent, to: file.url, shouldBackup: shouldBackup)
        hasUnsavedChanges = false

        // Re-parse after save
        if file.fileType == .schema {
            parsedSchema = schemaAnalyzer.parse(content: editingContent)
            colorSchemes = schemaAnalyzer.extractColorSchemes(from: editingContent)
        }
    }

    func fileContentDidChange(_ newContent: String) {
        editingContent = newContent
        hasUnsavedChanges = true
    }

    /// Reload current file content if not being edited locally.
    func refreshCurrentFileIfNeeded() {
        if let file = selectedFile, !isEditing {
            loadFileContent(file)
        }
    }
}
