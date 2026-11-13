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
    @Published var luaSettings = LuaSettings()
    @Published var advancedSettings = AdvancedSettings()

    // MARK: - Services

    private let fileService: FileManaging
    private let pathService: PathDetecting
    private var cancellables = Set<AnyCancellable>()
    /// 加载时的 rime_mint.custom.yaml 原始内容（回写时保留用户其他自定义）
    private var originalSchemaCustomDict: [String: Any] = [:]
    /// 加载时的 default.custom.yaml 原始内容（回写时保留用户其他自定义）
    private var originalDefaultCustomDict: [String: Any] = [:]
    private var activeSchemaYAML = ""
    private var activeSchemaCustomYAML = ""
    @Published private(set) var loadError: String?

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
        luaSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        advancedSettings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    // MARK: - Load All Configs

    func loadAllConfigs(in rimeDirectory: URL?) {
        guard let url = rimeDirectory else { return }
        loadError = nil
        originalSchemaCustomDict = [:]
        originalDefaultCustomDict = [:]
        activeSchemaYAML = ""
        activeSchemaCustomYAML = ""

        // Load main schema (rime_mint or first found)
        let schemas = pathService.findSchemaFiles(in: url)
        let mainSchemaURL = schemas.first { $0.lastPathComponent == "rime_mint.schema.yaml" }
            ?? schemas.first

        let schemaYAML = mainSchemaURL.map { fileService.readFileContent(at: $0) } ?? ""
        activeSchemaYAML = schemaYAML
        guard parseObject(schemaYAML, file: mainSchemaURL?.lastPathComponent ?? "schema.yaml") != nil else { return }
        let defaultCustomURL = url.appendingPathComponent("default.custom.yaml")
        let defaultCustomYAML = fileService.fileExists(at: defaultCustomURL)
            ? fileService.readFileContent(at: defaultCustomURL) : ""
        let defaultYAMLURL = url.appendingPathComponent("default.yaml")
        let defaultYAML = fileService.fileExists(at: defaultYAMLURL)
            ? fileService.readFileContent(at: defaultYAMLURL) : ""
        let schemaCustomURL = url.appendingPathComponent("rime_mint.custom.yaml")
        let schemaCustomYAML = fileService.fileExists(at: schemaCustomURL)
            ? fileService.readFileContent(at: schemaCustomURL) : ""
        activeSchemaCustomYAML = schemaCustomYAML

        guard let defaultCustomDict = parseObject(defaultCustomYAML, file: "default.custom.yaml"),
              let schemaCustomDict = parseObject(schemaCustomYAML, file: "rime_mint.custom.yaml") else {
            return
        }
        originalDefaultCustomDict = defaultCustomDict
        originalSchemaCustomDict = schemaCustomDict

        inputSettings.load(
            schemaYAML: schemaYAML,
            defaultCustomYAML: defaultCustomYAML,
            schemaCustomYAML: schemaCustomYAML
        )

        // Load squirrel config — merge base + custom
        let squirrelBaseURL = url.appendingPathComponent("squirrel.yaml")
        let squirrelCustomURL = url.appendingPathComponent("squirrel.custom.yaml")

        let baseYAML = fileService.fileExists(at: squirrelBaseURL)
            ? fileService.readFileContent(at: squirrelBaseURL) : ""
        let customYAML = fileService.fileExists(at: squirrelCustomURL)
            ? fileService.readFileContent(at: squirrelCustomURL) : ""
        guard parseObject(baseYAML, file: "squirrel.yaml") != nil,
              parseObject(customYAML, file: "squirrel.custom.yaml") != nil else { return }

        squirrelConfig.load(baseYAML: baseYAML, customYAML: customYAML)

        // Load the dictionary actually referenced by the effective translator.
        let dictionaryName = Self.effectiveTranslatorDictionary(
            schemaYAML: schemaYAML,
            schemaCustomYAML: schemaCustomYAML
        ) ?? "rime_mint"
        let dictURL = Self.dictionaryURL(for: dictionaryName, in: url)
        if fileService.fileExists(at: dictURL) {
            dictSettings.load(from: dictURL)
            dictSettings.scanEntryCounts(in: url)
        } else {
            dictSettings.reset()
        }

        // Scan schemas
        schemaSettings.scanSchemas(in: url)

        // 自定义短语
        let phraseURL = url.appendingPathComponent("custom_phrase.txt")
        if fileService.fileExists(at: phraseURL) {
            phraseSettings.load(from: fileService.readFileContent(at: phraseURL))
        } else {
            phraseSettings.load(from: "")
        }
        let phraseSchemaNames = Self.schemaTranslatorNames(
            schemaYAML: schemaYAML,
            schemaCustomYAML: schemaCustomYAML
        )
        phraseSettings.setSchemaSupport(
            phraseSchemaNames.contains("table_translator@custom_phrase"),
            translatorNames: phraseSchemaNames
        )

        // 标点映射（合并 rime_mint.custom.yaml 的 punctuator 补丁，
        // 否则用户/程序写入的标点修改会在下一次应用时被 schema 版本覆盖）
        punctuatorSettings.load(schemaYAML: schemaYAML, customYAML: schemaCustomYAML)

        // Lua 扩展
        luaSettings.load(schemaYAML: schemaYAML, customYAML: schemaCustomYAML)

        // 高级设置（同步/简繁/快捷键/用户词库）
        let installationURL = url.appendingPathComponent("installation.yaml")
        let installationYAML = fileService.fileExists(at: installationURL)
            ? fileService.readFileContent(at: installationURL) : ""
        guard parseObject(installationYAML, file: "installation.yaml") != nil else { return }
        advancedSettings.load(
            installationYAML: installationYAML,
            defaultYAML: defaultYAML,
            schemaYAML: schemaYAML,
            defaultCustomYAML: defaultCustomYAML,
            schemaCustomYAML: schemaCustomYAML
        )
        advancedSettings.scanUserDB(in: url)
    }

    // MARK: - Apply & Save All Changes

    func applyAllConfigChanges(in rimeDirectory: URL?) throws {
        guard let dirURL = rimeDirectory else {
            throw AppError.directoryNotSet
        }
        if let loadError {
            throw AppError.configLoadFailed(loadError)
        }

        let shouldBackup = UserDefaults.standard.object(forKey: "autoBackupBeforeSave") as? Bool ?? true

        // 先生成并校验全部内容，再开始写入，避免中途失败造成半新半旧配置。
        let dictionaryName = Self.effectiveTranslatorDictionary(
            schemaYAML: pathSchemaYAML(),
            schemaCustomYAML: pathSchemaCustomYAML()
        ) ?? "rime_mint"
        let dictURL = Self.dictionaryURL(for: dictionaryName, in: dirURL)
        let squirrelURL = dirURL.appendingPathComponent("squirrel.custom.yaml")
        let defaultCustomURL = dirURL.appendingPathComponent("default.custom.yaml")
        let schemaCustomURL = dirURL.appendingPathComponent("rime_mint.custom.yaml")
        let phraseURL = dirURL.appendingPathComponent("custom_phrase.txt")
        let installationURL = dirURL.appendingPathComponent("installation.yaml")

        let squirrelYAML = squirrelConfig.generateYAML()
        let mergedYAML = buildDefaultCustomYAML()
        let dictYAML = fileService.fileExists(at: dictURL) ? dictSettings.generateYAML() : ""
        let phraseContent = phraseSettings.generateContent()
        let schemaPatchYAML = buildSchemaCustomYAML()
        let installationYAML = advancedSettings.generateInstallationYAML()

        try validateGeneratedYAML(squirrelYAML, file: squirrelURL)
        try validateGeneratedYAML(mergedYAML, file: defaultCustomURL)
        if !dictYAML.isEmpty { try validateGeneratedYAML(dictYAML, file: dictURL, allowsMultipleDocuments: true) }
        try validateGeneratedYAML(schemaPatchYAML, file: schemaCustomURL)
        try validateGeneratedYAML(installationYAML, file: installationURL)

        // 1. Save squirrel.custom.yaml (style only)
        do {
            try fileService.writeFileContent(squirrelYAML, to: squirrelURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(squirrelURL, error.localizedDescription)
        }

        do {
            try fileService.writeFileContent(mergedYAML, to: defaultCustomURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(defaultCustomURL, error.localizedDescription)
        }

        // 3. Save dictionary settings for the schema's translator/dictionary.
        if fileService.fileExists(at: dictURL) {
            do {
                try fileService.writeFileContent(dictYAML, to: dictURL, shouldBackup: shouldBackup)
            } catch {
                throw AppError.fileWriteFailed(dictURL, error.localizedDescription)
            }
        }

        // 4. Save custom phrases (custom_phrase.txt)
        do {
            try fileService.writeFileContent(phraseContent, to: phraseURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(phraseURL, error.localizedDescription)
        }

        // 5. Save schema custom patch (input switches/translator + punctuator + lua engine)
        if !schemaPatchYAML.isEmpty {
            do {
                try fileService.writeFileContent(schemaPatchYAML, to: schemaCustomURL, shouldBackup: shouldBackup)
            } catch {
                throw AppError.fileWriteFailed(schemaCustomURL, error.localizedDescription)
            }
        }

        // 6. Save installation.yaml (sync settings)
        do {
            try fileService.writeFileContent(installationYAML, to: installationURL, shouldBackup: shouldBackup)
        } catch {
            throw AppError.fileWriteFailed(installationURL, error.localizedDescription)
        }
    }

    // MARK: - Build Merged YAML

    /// 递归合并字典：同为映射的键继续向下合并，其余（标量/数组）直接覆盖。
    /// 用于把本程序管理的配置键合并进原始 patch，避免整体替换节点时
    /// 丢掉用户手工添加的同级配置。
    private func deepMerge(base: inout [String: Any], with new: [String: Any]) {
        base = Self.deepMerged(base, new)
    }

    private static func deepMerged(_ base: [String: Any], _ new: [String: Any]) -> [String: Any] {
        var result = base
        for (key, newValue) in new {
            if let baseDict = result[key] as? [String: Any],
               let newDict = newValue as? [String: Any] {
                result[key] = deepMerged(baseDict, newDict)
            } else {
                result[key] = newValue
            }
        }
        return result
    }

    private func parseObject(_ yaml: String, file: String) -> [String: Any]? {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        do {
            guard let dict = try Yams.load(yaml: yaml) as? [String: Any] else {
                loadError = "\(file): YAML root must be a mapping"
                return nil
            }
            return dict
        } catch {
            loadError = "\(file): \(error.localizedDescription)"
            return nil
        }
    }

    private func validateGeneratedYAML(
        _ yaml: String,
        file: URL,
        allowsMultipleDocuments: Bool = false
    ) throws {
        guard !yaml.contains("YAML serialization failed") && !yaml.contains("RIME_MANAGER_SERIALIZATION_FAILED") else {
            throw AppError.yamlParseFailed("Yams failed to serialize \(file.lastPathComponent)")
        }
        if allowsMultipleDocuments {
            let documents = try Yams.load_all(yaml: yaml)
            var documentIterator = documents.makeIterator()
            guard documentIterator.next() != nil else {
                throw AppError.yamlParseFailed("Generated \(file.lastPathComponent) is empty or invalid")
            }
            return
        }
        guard try Yams.load(yaml: yaml) != nil else {
            throw AppError.yamlParseFailed("Generated \(file.lastPathComponent) is empty or invalid")
        }
    }

    private func pathSchemaYAML() -> String { activeSchemaYAML }
    private func pathSchemaCustomYAML() -> String { activeSchemaCustomYAML }

    private static func firstMap(_ yaml: String) -> [String: Any]? {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        if let dict = try? Yams.load(yaml: yaml) as? [String: Any] { return dict }
        if let documents = try? Yams.load_all(yaml: yaml) {
            return documents.compactMap { $0 as? [String: Any] }.first
        }
        return nil
    }

    private static func patchRoot(_ yaml: String) -> [String: Any] {
        let dict = firstMap(yaml) ?? [:]
        return dict["patch"] as? [String: Any] ?? dict
    }

    private static func effectiveTranslatorDictionary(schemaYAML: String, schemaCustomYAML: String) -> String? {
        let schema = firstMap(schemaYAML) ?? [:]
        let patch = patchRoot(schemaCustomYAML)
        let custom = (patch["translator"] as? [String: Any])?["dictionary"]
            ?? patch["translator/dictionary"]
        return (custom ?? (schema["translator"] as? [String: Any])?["dictionary"]) as? String
    }

    private static func dictionaryURL(for name: String, in directory: URL) -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(".dict.yaml") || trimmed.hasSuffix(".yaml") {
            return directory.appendingPathComponent(trimmed)
        }
        return directory.appendingPathComponent("\(trimmed).dict.yaml")
    }

    private static func schemaTranslatorNames(schemaYAML: String, schemaCustomYAML: String) -> Set<String> {
        var names = Set<String>()
        names.formUnion(RimePatchNormalizer.effectiveEngineSections(
            schemaYAML: schemaYAML,
            patchYAML: schemaCustomYAML
        )["translators"] ?? [])
        return names
    }

    /// 将 `root: {...}` 转成 `root/field` 字段级 patch。
    /// `recursive` 用于 ascii_composer 的 switch_key 子映射。
    private static func flattenNode(
        patch: inout [String: Any],
        root: String,
        recursive: Bool
    ) {
        var values = patch[root] as? [String: Any] ?? [:]
        let prefix = root + "/"
        for (key, value) in patch where key.hasPrefix(prefix) {
            let path = String(key.dropFirst(prefix.count))
            setPathValue(&values, path: path, value: value)
        }
        patch.removeValue(forKey: root)

        for (key, value) in values {
            let path = prefix + key
            if recursive, let child = value as? [String: Any] {
                flattenMap(patch: &patch, prefix: path, map: child)
            } else {
                patch[path] = value
            }
        }
    }

    private static func flattenMap(
        patch: inout [String: Any],
        prefix: String,
        map: [String: Any]
    ) {
        for (key, value) in map {
            let path = prefix + "/" + key
            if let child = value as? [String: Any] {
                flattenMap(patch: &patch, prefix: path, map: child)
            } else {
                patch[path] = value
            }
        }
    }

    private static func setPathValue(
        _ dict: inout [String: Any],
        path: String,
        value: Any
    ) {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return }
        if parts.count == 1 {
            dict[parts[0]] = value
            return
        }
        var child = dict[parts[0]] as? [String: Any] ?? [:]
        setPathValue(&child, path: parts.dropFirst().joined(separator: "/"), value: value)
        dict[parts[0]] = child
    }

    private func buildDefaultCustomYAML() -> String {
        // 以原始 default.custom.yaml 为基底，仅覆盖本程序管理的键，
        // 保留用户或发行版手工写入的其它自定义内容
        var patch = originalDefaultCustomDict["patch"] as? [String: Any] ?? [:]

        // 先把旧 nested patch 迁移为字段级路径，避免 patch 目标节点覆盖 base 同级字段。
        Self.flattenNode(patch: &patch, root: "menu", recursive: false)
        Self.flattenNode(patch: &patch, root: "ascii_composer", recursive: true)
        Self.flattenNode(patch: &patch, root: "translator", recursive: false)
        Self.flattenNode(patch: &patch, root: "switcher", recursive: false)

        // Input settings: menu、ascii_composer、显式 Return 设置
        let incoming = inputSettings.defaultCustomPatchDict()
        deepMerge(base: &patch, with: incoming)

        // Schema list（默认方案排第一，保持原始顺序）
        deepMerge(base: &patch, with: schemaSettings.schemaListPatch())

        // Advanced（switcher 扁平键，仅修改过的键才写入）
        let advancedIncoming = advancedSettings.generateDefaultPatch()
        deepMerge(base: &patch, with: advancedIncoming)

        var result = originalDefaultCustomDict
        result["patch"] = patch
        guard let yaml = try? Yams.dump(object: result), !yaml.isEmpty else {
            return "patch: RIME_MANAGER_SERIALIZATION_FAILED\n"
        }
        return yaml
    }

    private func buildSchemaCustomYAML() -> String {
        // 以原始 rime_mint.custom.yaml 为基底，仅合并本程序管理的配置项
        var patch = originalSchemaCustomDict["patch"] as? [String: Any] ?? [:]
        RimePatchNormalizer.normalizeEnginePatch(patch: &patch, schemaYAML: activeSchemaYAML)

        // 候选词数量：schema 层 page_size 必须 patch 到 schema custom，default.custom.yaml 不生效
        Self.flattenNode(patch: &patch, root: "menu", recursive: false)
        Self.flattenNode(patch: &patch, root: "translator", recursive: false)
        Self.flattenNode(patch: &patch, root: "engine", recursive: false)
        Self.flattenNode(patch: &patch, root: "punctuator", recursive: false)

        deepMerge(base: &patch, with: inputSettings.schemaCustomPatchDict())

        let currentTranslators = RimePatchNormalizer.effectiveEngineSections(
            schemaYAML: activeSchemaYAML,
            patchYAML: activeSchemaCustomYAML
        )["translators"] ?? []
        let hasExistingTranslatorPatch = patch["engine/translators"] != nil
            || (originalSchemaCustomDict["patch"] as? [String: Any])?["engine/translators"] != nil
        deepMerge(
            base: &patch,
            with: phraseSettings.customPhraseSchemaPatch(
                currentTranslators: currentTranslators,
                hasExistingTranslatorPatch: hasExistingTranslatorPatch
            )
        )

        // OpenCC 简繁：engine 在 schema 层定义，default 层的 engine/filters
        // patch 会被 schema 覆盖，必须写到这里
        let filtersIncoming = advancedSettings.filtersPatchDict()
        let punctuatorIncoming = punctuatorSettings.generatePatch()
        let luaIncoming = luaSettings.generatePatch()
        deepMerge(base: &patch, with: filtersIncoming)
        deepMerge(base: &patch, with: punctuatorIncoming)
        deepMerge(base: &patch, with: luaIncoming)

        var result = originalSchemaCustomDict
        result["patch"] = patch
        guard let yaml = try? Yams.dump(object: result), !yaml.isEmpty else {
            return "patch: RIME_MANAGER_SERIALIZATION_FAILED\n"
        }
        return yaml
    }
}
