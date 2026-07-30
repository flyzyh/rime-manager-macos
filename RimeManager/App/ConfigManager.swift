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

    // MARK: - Services

    private let fileService: FileManaging
    private let pathService: PathDetecting
    private var cancellables = Set<AnyCancellable>()

    init(fileService: FileManaging = FileManagerService(),
         pathService: PathDetecting = RimePathService()) {
        self.fileService = fileService
        self.pathService = pathService

        // Forward child object changes
        squirrelConfig.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        inputSettings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        dictSettings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        schemaSettings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
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
        }

        // Scan schemas
        schemaSettings.scanSchemas(in: url)
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

        // 2. Save default.custom.yaml (merge input + schema patches)
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

        let result: [String: Any] = patch.isEmpty ? [:] : ["patch": patch]
        return (try? Yams.dump(object: result)) ?? ""
    }
}
