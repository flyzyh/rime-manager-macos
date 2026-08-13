import SwiftUI
import Combine

/// Central application state coordinator.
/// Holds sub-models and manages global navigation state.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Rime directory

    @Published var rimeDirectoryURL: URL?
    @Published var rimeDirectoryName: String = ""

    // MARK: - Sub-models

    let fileBrowser: FileBrowserModel
    let configManager: ConfigManager
    let importExport: ImportExportModel

    // MARK: - Services

    private let pathService: PathDetecting
    private var directoryWatcher: DirectoryWatcher?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Convenience accessors (for backward compatibility during migration)

    var configFiles: [RimeConfigFile] { fileBrowser.configFiles }
    var selectedFile: RimeConfigFile? {
        get { fileBrowser.selectedFile }
        set { fileBrowser.selectedFile = newValue }
    }
    var editingContent: String {
        get { fileBrowser.editingContent }
        set { fileBrowser.editingContent = newValue }
    }
    var isEditing: Bool {
        get { fileBrowser.isEditing }
        set { fileBrowser.isEditing = newValue }
    }
    var hasUnsavedChanges: Bool { fileBrowser.hasUnsavedChanges }
    var parsedSchema: RimeSchema? { fileBrowser.parsedSchema }
    var colorSchemes: [ColorScheme] { fileBrowser.colorSchemes }

    // MARK: - Init

    init(pathService: PathDetecting = RimePathService()) {
        self.pathService = pathService
        self.fileBrowser = FileBrowserModel()
        self.configManager = ConfigManager()
        self.importExport = ImportExportModel()

        // Forward sub-model changes to AppState
        configManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        fileBrowser.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        autoDetectRimeDirectory()
    }

    // MARK: - Rime directory

    func autoDetectRimeDirectory() {
        if let url = pathService.detectDefaultRimeDirectory() {
            setRimeDirectory(url)
        }
    }

    func selectRimeDirectory() {
        let panel = NSOpenPanel()
        panel.title = "dialog.select_dir_title".localized
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = rimeDirectoryURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
        panel.message = "dialog.select_dir_message".localized

        if panel.runModal() == .OK, let url = panel.url {
            setRimeDirectory(url)
        }
    }

    private func setRimeDirectory(_ url: URL) {
        rimeDirectoryURL = url
        rimeDirectoryName = url.lastPathComponent
        reloadFiles()
        configManager.loadAllConfigs(in: url)
        startWatching()
    }

    // MARK: - File management

    func reloadFiles() {
        fileBrowser.reloadFiles(in: rimeDirectoryURL)
    }

    func saveCurrentFile() {
        do {
            try fileBrowser.saveCurrentFile()
            FeedbackManager.shared.showSuccess("save.success".localized)
        } catch {
            FeedbackManager.shared.showError(error.localizedDescription)
        }
    }

    func fileContentDidChange(_ newContent: String) {
        fileBrowser.fileContentDidChange(newContent)
    }

    // MARK: - File watching

    private func startWatching() {
        directoryWatcher?.stop()

        // Respect user preference
        let watchEnabled = UserDefaults.standard.object(forKey: "watchExternalChanges") as? Bool ?? true
        guard watchEnabled, let url = rimeDirectoryURL else { return }

        directoryWatcher = DirectoryWatcher(url: url)
        directoryWatcher?.onChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.reloadFiles()
                self.fileBrowser.refreshCurrentFileIfNeeded()
            }
        }
        directoryWatcher?.start()
    }

    // MARK: - Rime deployment

    func deployRime() {
        let deployer = "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
        let squirrelApp = "/Library/Input Methods/Squirrel.app"
        let sharedSupport = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport"
        guard let rimeDir = rimeDirectoryURL else {
            FeedbackManager.shared.showError("error.dir_not_set".localized)
            return
        }

        let task = Process()
        task.launchPath = deployer
        task.arguments = ["--build", rimeDir.path, sharedSupport]
        task.terminationHandler = { [weak self] _ in
            // 完全重启 Squirrel：--reload 只重载方案/词库，
            // 面板外观（squirrel.custom.yaml 的 style）必须重启输入法才生效
            let kill = Process()
            kill.launchPath = "/usr/bin/pkill"
            kill.arguments = ["-f", "Squirrel.app/Contents/MacOS/Squirrel"]
            kill.terminationHandler = { _ in
                let reopen = Process()
                reopen.launchPath = "/usr/bin/open"
                reopen.arguments = [squirrelApp]
                try? reopen.run()
            }
            do {
                try kill.run()
            } catch {
                let reopen = Process()
                reopen.launchPath = "/usr/bin/open"
                reopen.arguments = [squirrelApp]
                try? reopen.run()
            }

            Task { @MainActor in
                self?.configManager.loadAllConfigs(in: self?.rimeDirectoryURL)
                FeedbackManager.shared.showSuccess("deploy.success".localized)
            }
        }
        do {
            try task.run()
        } catch {
            FeedbackManager.shared.showError("deploy.failed".localized)
        }
    }

    // MARK: - Apply all changes

    func applyAllConfigChanges() {
        do {
            try configManager.applyAllConfigChanges(in: rimeDirectoryURL)
            reloadFiles()
            configManager.loadAllConfigs(in: rimeDirectoryURL)
            FeedbackManager.shared.showSuccess("save.success".localized)
        } catch let error as AppError {
            FeedbackManager.shared.showAlert(for: error)
        } catch {
            FeedbackManager.shared.showError(error.localizedDescription)
        }
    }

    // MARK: - Import / Export (delegated)

    func exportCurrentConfig() {
        importExport.exportCurrentConfig(from: rimeDirectoryURL)
    }

    func importConfig() {
        importExport.importConfig(to: rimeDirectoryURL) { [weak self] in
            self?.reloadFiles()
        }
    }

    func exportSelectedFile() {
        importExport.exportSelectedFile(fileBrowser.selectedFile)
    }

    func createBackup() {
        importExport.createBackup(of: rimeDirectoryURL)
    }
}
