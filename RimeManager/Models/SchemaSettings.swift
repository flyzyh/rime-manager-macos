import SwiftUI
import Yams

/// Manages available input schemas and their configuration.
final class SchemaSettings: ObservableObject {
    @Published var availableSchemas: [SchemaInfo] = []
    @Published var enabledSchemaIDs: Set<String> = []
    @Published var defaultSchemaID: String = ""

    private var defaultCustomURL: URL?

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

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: rimeDir, includingPropertiesForKeys: nil) else { return }

        var schemas: [SchemaInfo] = []
        for file in files {
            let name = file.lastPathComponent
            guard name.hasSuffix(".schema.yaml") else { continue }
            let content = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let schemaID = extractSchemaID(from: content) ?? file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".schema", with: "")
            let displayName = extractSchemaName(from: content) ?? schemaID
            let cat = SchemaCategory.detect(from: schemaID)
            schemas.append(SchemaInfo(id: schemaID, name: displayName, file: name, category: cat))
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

    private func extractSchemaName(from yaml: String) -> String? {
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let schema = dict["schema"] as? [String: Any] else { return nil }
        return schema["name"] as? String
    }

    private func loadEnabledSchemas(in rimeDir: URL) {
        var enabledIDs: Set<String> = []
        var defaultID: String = ""

        // 1. Read default.yaml (base config) for schema_list
        let defaultYAML = rimeDir.appendingPathComponent("default.yaml")
        if let content = try? String(contentsOf: defaultYAML, encoding: .utf8),
           let dict = try? Yams.load(yaml: content) as? [String: Any],
           let schemaList = dict["schema_list"] as? [[String: Any]] {
            let ids = schemaList.compactMap { $0["schema"] as? String }
            enabledIDs = Set(ids)
            defaultID = ids.first ?? ""
        }

        // 2. Read default.custom.yaml for overrides
        if let url = defaultCustomURL,
           let content = try? String(contentsOf: url, encoding: .utf8),
           let dict = try? Yams.load(yaml: content) as? [String: Any] {
            let root = dict["patch"] as? [String: Any] ?? dict
            if let schemaList = root["schema_list"] as? [[String: Any]] {
                let ids = schemaList.compactMap { $0["schema"] as? String }
                // Custom overrides base completely
                enabledIDs = Set(ids)
                defaultID = ids.first ?? defaultID
            }
        }

        // Apply
        if !enabledIDs.isEmpty {
            enabledSchemaIDs = enabledIDs
            defaultSchemaID = defaultID
        } else {
            // No schema_list found → all schemas are available
            enabledSchemaIDs = Set(availableSchemas.map(\.id))
            defaultSchemaID = availableSchemas.first?.id ?? ""
        }
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
    /// Returns a dict with just the schema_list key to be merged into the full patch.
    func schemaListPatch() -> [String: Any] {
        let list = enabledSchemaIDs.sorted().map { ["schema": $0] }
        return ["schema_list": list]
    }

    /// Check if a schema is the default
    func isDefault(_ id: String) -> Bool {
        id == defaultSchemaID || (defaultSchemaID.isEmpty && id == availableSchemas.first?.id)
    }
}
