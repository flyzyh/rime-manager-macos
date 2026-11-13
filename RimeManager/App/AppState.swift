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
            guard isValidRimeRoot(url) else {
                FeedbackManager.shared.showError("Selected folder is not a valid Rime configuration directory.")
                return
            }
            setRimeDirectory(url)
        }
    }

    private func isValidRimeRoot(_ url: URL) -> Bool {
        guard !((try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false) else { return false }
        return pathService.isValidRimeDirectory(url)
    }

    private func setRimeDirectory(_ url: URL) {
        rimeDirectoryURL = url
        rimeDirectoryName = url.lastPathComponent
        reloadFiles()
        configManager.loadAllConfigs(in: url)
        if let error = configManager.loadError {
            FeedbackManager.shared.showAlert(for: .configLoadFailed(error))
        }
        startWatching()
    }

    // MARK: - File management

    func reloadFiles() {
        fileBrowser.reloadFiles(in: rimeDirectoryURL)
    }

    func saveCurrentFile() {
        do {
            try fileBrowser.saveCurrentFile()
            // 原始编辑器可能修改的是受管理配置；保存后立即重建模型。
            configManager.loadAllConfigs(in: rimeDirectoryURL)
            if let error = configManager.loadError {
                FeedbackManager.shared.showAlert(for: .configLoadFailed(error))
            }
            FeedbackManager.shared.showSuccess("save.success".localized)
        } catch {
            FeedbackManager.shared.showError(error.localizedDescription)
        }
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
                // 外部/原始编辑器变更必须同步到设置模型，否则“应用”会用旧状态覆盖。
                self.configManager.loadAllConfigs(in: self.rimeDirectoryURL)
                if let error = self.configManager.loadError {
                    FeedbackManager.shared.showAlert(for: .configLoadFailed(error))
                }
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

        // stderr 落盘临时文件而非管道：管道缓冲 64KB，deployer 输出过大时
        // 进程会阻塞在写管道上，terminationHandler 永不触发。
        // 使用一次性文件名，避免并发部署或 symlink 竞争复用旧日志文件
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rime_manager_deploy_stderr_\(UUID().uuidString).log")
        try? FileManager.default.removeItem(at: stderrURL)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stderrHandle = FileHandle(forWritingAtPath: stderrURL.path)

        let task = Process()
        task.launchPath = deployer
        task.arguments = ["--build", rimeDir.path, sharedSupport]
        task.standardError = stderrHandle
        task.terminationHandler = { [weak self] process in
            try? stderrHandle?.close()
            let stderrText = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: stderrURL)
            Task { @MainActor in
                guard let self else { return }
                // 检查部署结果：失败（如 YAML 语法错误）时不重启输入法，并展示错误
                if process.terminationStatus == 0 {
                    self.restartSquirrel(appPath: squirrelApp)
                    self.configManager.loadAllConfigs(in: self.rimeDirectoryURL)
                    FeedbackManager.shared.showSuccess("deploy.success".localized)
                } else {
                    // 只取最后几行（通常是根因），并保留本地化的失败前缀
                    let detail = stderrText.split(separator: "\n").suffix(3).joined(separator: "\n")
                    // 部署失败时文件可能已经改变；重建模型，避免 UI 继续持有生成失败前的状态。
                    self.configManager.loadAllConfigs(in: self.rimeDirectoryURL)
                    FeedbackManager.shared.showError(
                        detail.isEmpty ? "deploy.failed".localized : "deploy.failed".localized + "\n" + detail
                    )
                }
            }
        }
        do {
            try task.run()
        } catch {
            try? stderrHandle?.close()
            try? FileManager.default.removeItem(at: stderrURL)
            FeedbackManager.shared.showError("deploy.failed".localized)
        }
    }

    /// 完全重启 Squirrel：--reload 只重载方案/词库，
    /// 面板外观（squirrel.custom.yaml 的 style）必须重启输入法才生效
    private func restartSquirrel(appPath: String) {
        let squirrel = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.path == appPath
        }
        let reopen = {
            let reopen = Process()
            reopen.launchPath = "/usr/bin/open"
            reopen.arguments = [appPath]
            try? reopen.run()
        }

        if let squirrel, squirrel.terminate() {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                reopen()
            }
        } else {
            reopen()
        }
    }

    // MARK: - Apply all changes

    @discardableResult
    func applyAllConfigChanges() -> Bool {
        do {
            try configManager.applyAllConfigChanges(in: rimeDirectoryURL)
            reloadFiles()
            configManager.loadAllConfigs(in: rimeDirectoryURL)
            FeedbackManager.shared.showSuccess("save.success".localized)
            return true
        } catch let error as AppError {
            FeedbackManager.shared.showAlert(for: error)
            return false
        } catch {
            FeedbackManager.shared.showError(error.localizedDescription)
            return false
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
