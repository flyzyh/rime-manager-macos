import SwiftUI
import Combine
import Yams

/// Manages loading, merging, and persisting Rime configuration settings.
@MainActor
final class ConfigManager: ObservableObject {
    // MARK: - Published Config Models

    @Published var squirrelConfig = SquirrelConfig()
    @Published var inputSettings = InputSettings()
    @Published var dictSettings = DictSettings()
    @Published var schemaSettings = SchemaSettings()
    @Published var phraseSettings = PhraseSettings()
    @Published var punctuatorSettings = PunctuatorSettings()
    @Published var keyBindingSettings = KeyBindingSettings()
    @Published var luaSettings = LuaSettings()
    @Published var advancedSettings = AdvancedSettings()

    // MARK: - Services

    private let fileService: FileManaging
    private let pathService: PathDetecting
    private var cancellables = Set<AnyCancellable>()
    /// 加载时的 rime_mint.custom.yaml 原始内容（回写时保留用户其他自定义）
    private var originalSchemaCustomDict: [String: Any] = [:]

    init(fileService: FileManaging = FileManagerService(),
         pathService: PathDetecting = RimePathService()) {
        self.fileService = fileService
        self.pathService = pathService

        // Forward child object changes
        squirrelConfig.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        inputSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        dictSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        schemaSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        phraseSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        punctuatorSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        keyBindingSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        luaSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        advancedSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    // MARK: - Load All Configs

    func loadAllConfigs(in rimeDirectory: URL?) {
        guard let url = rimeDirectory else { return }

        // Load main schema (rime_mint or first found)
        let schemas = pathService.findSchemaFiles(in: url)
        let mainSchemaURL = schemas.first { $0.lastPathComponent == "rime_mint.schema.yaml" }
            ?? schemas.first

        let schemaYAML = mainSchemaURL.map { fileService.readFileContent(at: $0) } ?? ""
        let defaultCustomURL = url.appendingPathComponent("default.custom.yaml")
        let defaultCustomYAML = fileService.fileExists(at: defaultCustomURL)
            ? fileService.readFileContent(at: defaultCustomURL) : ""
        let defaultYAMLURL = url.appendingPathComponent("default.yaml")
        let defaultYAML = fileService.fileExists(at: defaultYAMLURL)
            ? fileService.readFileContent(at: defaultYAMLURL) : ""

        inputSettings.load(schemaYAML: schemaYAML, defaultCustomYAML: defaultCustomYAML)

        // Load squirrel config — merge base + custom
        let squirrelBaseURL = url.appendingPathComponent("squirrel.yaml")
        let squirrelCustomURL = url.appendingPathComponent("squirrel.custom.yaml")

        let baseYAML = fileService.fileExists(at: squirrelBaseURL)
            ? fileService.readFileContent(at: squirrelBaseURL) : ""
        let customYAML = fileService.fileExists(at: squirrelCustomURL)
            ? fileService.readFileContent(at: squirrelCustomURL) : ""

        squirrelConfig.load(baseYAML: baseYAML, customYAML: customYAML)

        // Load dict settings
        let dictURL = url.appendingPathComponent("rime_mint.dict.yaml")
        if fileService.fileExists(at: dictURL) {
            dictSettings.load(from: dictURL)
            dictSettings.scanEntryCounts(in: url)
        }

        // Scan schemas
        schemaSettings.scanSchemas(in: url)

        // 自定义短语
        let phraseURL = url.appendingPathComponent("custom_phrase.txt")
        if fileService.fileExists(at: phraseURL) {
            phraseSettings.load(from: fileService.readFileContent(at: phraseURL))
        }

        // 标点映射
        punctuatorSettings.load(schemaYAML: schemaYAML)

        // 按键绑定
        keyBindingSettings.load(schemaYAML: schemaYAML, defaultYAML: defaultYAML)
        keyBindingSettings.snapshot()

        // Lua 扩展
        luaSettings.load(schemaYAML: schemaYAML)

        // 保存 rime_mint.custom.yaml 原始内容
        let schemaCustomURL = url.appendingPathComponent("rime_mint.custom.yaml")
        originalSchemaCustomDict = [:]
        if fileService.fileExists(at: schemaCustomURL) {
            let content = fileService.readFileContent(at: schemaCustomURL)
            originalSchemaCustomDict = (try? Yams.load(yaml: content) as? [String: Any]) ?? [:]
        }

        // 高级设置（同步/简繁/快捷键/用户词库）
        let installationURL = url.appendingPathComponent("installation.yaml")
        let installationYAML = fileService.fileExists(at: installationURL)
            ? fileService.readFileContent(at: installationURL) : ""
        advancedSettings.load(installationYAML: installationYAML, defaultYAML: defaultYAML, schemaYAML: schemaYAML)
        advancedSettings.scanUserDB(in: url)
    }

    // MARK: - Apply & Save All Changes

    func applyAllConfigChanges(in rimeDirectory: URL?) throws {
        guard let dirURL = rimeDirectory else {
            throw AppError.directoryNotSet
        }

        let shouldBackup = UserDefaults.standard.object(forKey: "autoBackupBeforeSave") as? Bool ?? true

        // 1. Save squirrel.custom.yaml (style only)
        let squirrelYAML = squirrelConfig.generateYAML()
        let squirrelURL = dirURL.appendingPathComponent("squirrel.custom.yaml")
        do {
            try fileService.writeFileContent(squirrelYAML, to: squirrelURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(squirrelURL, error.localizedDescription)
        }

        // 2. Save default.custom.yaml (merge input + schema + keybinder + advanced patches)
        let defaultCustomURL = dirURL.appendingPathComponent("default.custom.yaml")
        do {
            let mergedYAML = buildDefaultCustomYAML()
            try fileService.writeFileContent(mergedYAML, to: defaultCustomURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(defaultCustomURL, error.localizedDescription)
        }

        // 3. Save dict settings (rime_mint.dict.yaml)
        let dictURL = dirURL.appendingPathComponent("rime_mint.dict.yaml")
        if fileService.fileExists(at: dictURL) {
            let dictYAML = dictSettings.generateYAML()
            do {
                try fileService.writeFileContent(dictYAML, to: dictURL, shouldBackup: shouldBackup)
            } catch {
                throw AppError.fileWriteFailed(dictURL, error.localizedDescription)
            }
        }

        // 4. Save custom phrases (custom_phrase.txt)
        let phraseURL = dirURL.appendingPathComponent("custom_phrase.txt")
        do {
            try fileService.writeFileContent(phraseSettings.generateContent(), to: phraseURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(phraseURL, error.localizedDescription)
        }

        // 5. Save schema custom patch (punctuator + lua engine)
        let schemaCustomURL = dirURL.appendingPathComponent("rime_mint.custom.yaml")
        let schemaPatchYAML = buildSchemaCustomYAML()
        if !schemaPatchYAML.isEmpty {
            do {
                try fileService.writeFileContent(schemaPatchYAML, to: schemaCustomURL, shouldBackup: shouldBackup)
            } catch {
                throw AppError.fileWriteFailed(schemaCustomURL, error.localizedDescription)
            }
        }

        // 6. Save installation.yaml (sync settings)
        let installationURL = dirURL.appendingPathComponent("installation.yaml")
        do {
            try fileService.writeFileContent(advancedSettings.generateInstallationYAML(), to: installationURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(installationURL, error.localizedDescription)
        }
    }

    // MARK: - Build Merged YAML

    private func buildDefaultCustomYAML() -> String {
        var patch: [String: Any] = [:]

        // Input settings: menu, ascii_composer, key_binder
        let inputYAML = inputSettings.generateDefaultCustomPatch()
        if let inputDict = try? Yams.load(yaml: inputYAML) as? [String: Any],
           let inputPatch = inputDict["patch"] as? [String: Any] {
            for (k, v) in inputPatch { patch[k] = v }
        }

        // Schema list
        let schemaPatch = schemaSettings.schemaListPatch()
        for (k, v) in schemaPatch { patch[k] = v }

        // 按键绑定：仅当用户修改过才整体回写；否则保留 InputSettings 的 key_binder/bindings/+ 追加项
        if keyBindingSettings.hasChanges {
            patch["key_binder"] = ["bindings": keyBindingSettings.generateBindings()]
        }

        // Advanced (switcher hotkeys + simplifier filters)
        let advPatch = advancedSettings.generateDefaultPatch()
        for (k, v) in advPatch {
            if k == "engine/filters" {
                patch["engine/filters"] = v
            } else {
                patch[k] = v
            }
        }

        let result: [String: Any] = patch.isEmpty ? [:] : ["patch": patch]
        return (try? Yams.dump(object: result)) ?? ""
    }

    private func buildSchemaCustomYAML() -> String {
        // 以原始 rime_mint.custom.yaml 为基底，仅合并本程序管理的配置项
        var patch = originalSchemaCustomDict["patch"] as? [String: Any] ?? [:]

        // Punctuator
        for (k, v) in punctuatorSettings.generatePatch() { patch[k] = v }

        // Lua engine sections
        for (k, v) in luaSettings.generatePatch() { patch[k] = v }

        let result: [String: Any] = patch.isEmpty ? [:] : ["patch": patch]
        return (try? Yams.dump(object: result)) ?? ""
    }
}
