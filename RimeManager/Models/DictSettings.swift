import SwiftUI
import Yams

/// Manages dictionary import settings for the main schema.
final class DictSettings: ObservableObject {
    @Published var importTables: [DictEntry] = []
    @Published var schemaName: String = ""

    private var dictFileURL: URL?
    private var originalYAML: String = ""

    struct DictEntry: Identifiable {
        let id = UUID()
        let name: String
        var enabled: Bool
        let description: String
    }

    /// Load from rime_mint.dict.yaml
    func load(from url: URL) {
        dictFileURL = url
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        originalYAML = content

        guard let dict = try? Yams.load(yaml: content) as? [String: Any] else { return }
        schemaName = dict["name"] as? String ?? ""

        if let tables = dict["import_tables"] as? [String] {
            importTables = tables.map { name in
                let desc = dictDescription(for: name.trimmingCharacters(in: .whitespaces))
                return DictEntry(name: name.trimmingCharacters(in: .whitespaces), enabled: true, description: desc)
            }
        }
    }

    /// Generate updated YAML with current import_tables
    func generateYAML() -> String {
        guard var dict = try? Yams.load(yaml: originalYAML) as? [String: Any] else {
            return originalYAML
        }

        let enabled = importTables.filter(\.enabled).map(\.name)
        dict["import_tables"] = enabled

        return (try? Yams.dump(object: dict)) ?? originalYAML
    }

    private func dictDescription(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("chars") { return "单字词库" }
        if lower.contains("base") { return "基础词库" }
        if lower.contains("ext") { return "扩展词库" }
        if lower.contains("correlation") { return "关联词库" }
        if lower.contains("compatible") { return "兼容词库" }
        if lower.contains("custom") { return "自定义词库" }
        if lower.contains("kaomoji") { return "颜文字" }
        if lower.contains("emoji") { return "Emoji" }
        if lower.contains("ice.others") { return "雾凇纠错词库" }
        if lower.contains("ice.cn_en") { return "雾凇中英混合" }
        if lower.contains("ice.en") { return "雾凇英文词库" }
        if lower.contains("wubi") { return "五笔词库" }
        if lower.contains("melt") { return "英文词库" }
        return "词库"
    }
}
