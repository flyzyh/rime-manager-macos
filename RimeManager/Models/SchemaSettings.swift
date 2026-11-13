import SwiftUI
import Yams

/// Manages available input schemas and their configuration.
final class SchemaSettings: ObservableObject {
    @Published var availableSchemas: [SchemaInfo] = []
    @Published var enabledSchemaIDs: Set<String> = []
    @Published var defaultSchemaID: String = ""

    private var defaultCustomURL: URL?
    /// 加载时 schema_list 的原始顺序（default.custom.yaml 覆盖 default.yaml），
    /// 回写时保持该顺序，默认方案排第一
    private var originalSchemaOrder: [String] = []

    struct SchemaInfo: Identifiable {
        let id: String       // schema_id
        let name: String     // display name
        let file: String     // filename
        let category: SchemaCategory
    }

    enum SchemaCategory: String, CaseIterable {
        case pinyin = "全拼"
        case doublePinyin = "双拼"
        case wubi = "五笔"
        case stroke = "笔画"
        case english = "英文"
        case other = "其他"

        static func detect(from id: String) -> SchemaCategory {
            let lower = id.lowercased()
            if lower.contains("double") || lower.contains("flypy") || lower.contains("abc") || lower.contains("mspy") || lower.contains("sogou") || lower.contains("ziguang") {
                return .doublePinyin
            }
            if lower.contains("wubi") { return .wubi }
            if lower.contains("stroke") || lower.contains("t9") { return .stroke }
            if lower.contains("melt") || lower.contains("english") { return .english }
            if lower.contains("pinyin") || lower.contains("mint") || lower.contains("terra") { return .pinyin }
            return .other
        }
    }

    /// Scan Rime directory for all .schema.yaml files
    func scanSchemas(in rimeDir: URL) {
        defaultCustomURL = rimeDir.appendingPathComponent("default.custom.yaml")
        availableSchemas = []
        enabledSchemaIDs = []
        defaultSchemaID = ""
        originalSchemaOrder = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rimeDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        var schemas: [SchemaInfo] = []
        for element in enumerator {
            guard let file = element as? URL else { continue }
            let name = file.lastPathComponent
            let relative = file.pathComponents.contains { $0 == "build" || $0 == "sync" || $0 == "backups" || $0.hasPrefix("backup_") }
            guard !relative else { continue }
            guard name.hasSuffix(".schema.yaml") else { continue }
            let content = readFile(file)
            let schemaID = extractSchemaID(from: content) ?? file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".schema", with: "")
            let displayName = extractSchemaName(from: content) ?? schemaID
            let cat = SchemaCategory.detect(from: schemaID)
            schemas.append(SchemaInfo(id: schemaID, name: displayName, file: name, category: cat))
        }

        // Squirrel SharedSupport 中的内置方案也可被 schema_list 引用。
        let sharedSupport = URL(fileURLWithPath: "/Library/Input Methods/Squirrel.app/Contents/SharedSupport")
        if let files = try? FileManager.default.contentsOfDirectory(
            at: sharedSupport,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in files where file.lastPathComponent.hasSuffix(".schema.yaml") {
                let content = readFile(file)
                let schemaID = extractSchemaID(from: content)
                    ?? file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".schema", with: "")
                guard !schemas.contains(where: { $0.id == schemaID }) else { continue }
                let displayName = extractSchemaName(from: content) ?? schemaID
                schemas.append(SchemaInfo(
                    id: schemaID,
                    name: displayName,
                    file: file.lastPathComponent,
                    category: SchemaCategory.detect(from: schemaID)
                ))
            }
        }

        availableSchemas = schemas.sorted { $0.name < $1.name }

        // Load enabled list from default.yaml (base config) AND default.custom.yaml (overrides)
        loadEnabledSchemas(in: rimeDir)
    }

    private func extractSchemaID(from yaml: String) -> String? {
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let schema = dict["schema"] as? [String: Any] else { return nil }
        return schema["schema_id"] as? String
    }

    private func readFile(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        if let content = String(data: data, encoding: .utf8) { return content }
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        return String(data: data, encoding: gb18030) ?? ""
    }

    private func extractSchemaName(from yaml: String) -> String? {
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let schema = dict["schema"] as? [String: Any] else { return nil }
        return schema["name"] as? String
    }

    private func loadEnabledSchemas(in rimeDir: URL) {
        var orderedIDs: [String] = []

        // 1. Read default.yaml (base config) for schema_list
        let defaultYAML = rimeDir.appendingPathComponent("default.yaml")
        if let content = readFile(defaultYAML) as String?,
           let dict = try? Yams.load(yaml: content) as? [String: Any],
           let schemaList = dict["schema_list"] as? [[String: Any]] {
            orderedIDs = schemaList.compactMap { $0["schema"] as? String }
        }

        // 2. Read default.custom.yaml for overrides (completely overrides base)
        if let url = defaultCustomURL,
           let content = readFile(url) as String?,
           let dict = try? Yams.load(yaml: content) as? [String: Any] {
            let root = dict["patch"] as? [String: Any] ?? dict
            if let schemaList = root["schema_list"] as? [[String: Any]] {
                orderedIDs = schemaList.compactMap { $0["schema"] as? String }
            }
        }

        // Apply
        if !orderedIDs.isEmpty {
            enabledSchemaIDs = Set(orderedIDs)
            defaultSchemaID = orderedIDs.first ?? ""
        } else {
            // No schema_list found → all schemas are available
            orderedIDs = availableSchemas.map(\.id)
            enabledSchemaIDs = Set(orderedIDs)
            defaultSchemaID = orderedIDs.first ?? ""
        }
        originalSchemaOrder = orderedIDs
    }

    /// Toggle a schema on/off
    func toggleSchema(_ id: String) {
        objectWillChange.send()
        if enabledSchemaIDs.contains(id) {
            enabledSchemaIDs.remove(id)
        } else {
            enabledSchemaIDs.insert(id)
        }
    }

    func setDefault(_ id: String) {
        objectWillChange.send()
        defaultSchemaID = id
    }

    /// Generate the "schema_list" portion of the patch.
    /// Rime 以 schema_list 的第一项为默认方案，因此默认方案必须排第一，
    /// 其余条目按加载时的原始顺序排列，而不是字母序。
    func schemaListPatch() -> [String: Any] {
        var ordered: [String] = []
        if !defaultSchemaID.isEmpty, enabledSchemaIDs.contains(defaultSchemaID) {
            ordered.append(defaultSchemaID)
        }
        for id in originalSchemaOrder where enabledSchemaIDs.contains(id) && !ordered.contains(id) {
            ordered.append(id)
        }
        // 已启用但不在原始清单中的方案兜底（如扫描后新增的方案）
        for id in enabledSchemaIDs.sorted() where !ordered.contains(id) {
            ordered.append(id)
        }
        return ["schema_list": ordered.map { ["schema": $0] }]
    }

    /// Check if a schema is the default
    func isDefault(_ id: String) -> Bool {
        id == defaultSchemaID || (defaultSchemaID.isEmpty && id == availableSchemas.first?.id)
    }
}
