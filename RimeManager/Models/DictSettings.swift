import SwiftUI
import Yams

/// Manages dictionary import settings for the main schema.
final class DictSettings: ObservableObject {
    @Published var importTables: [DictEntry] = []
    @Published var schemaName: String = ""
    @Published var entryCounts: [String: Int] = [:]

    private var dictFileURL: URL?
    private var originalYAML: String = ""
    private var rimeDirURL: URL?

    func reset() {
        dictFileURL = nil
        originalYAML = ""
        rimeDirURL = nil
        importTables = []
        schemaName = ""
        entryCounts = [:]
    }

    struct DictEntry: Identifiable {
        let id = UUID()
        let name: String
        var enabled: Bool
        let description: String
    }

    /// 统计各词库文件词条数
    func scanEntryCounts(in rimeDir: URL) {
        rimeDirURL = rimeDir
        var counts: [String: Int] = [:]
        let fm = FileManager.default

        for entry in importTables {
            let name = entry.name
            // 路径如 dicts/rime_mint.base → dicts/rime_mint.base.dict.yaml
            let relPath = name.hasSuffix(".dict.yaml") ? name : "\(name).dict.yaml"
            let fileURL = rimeDir.appendingPathComponent(relPath)
            guard fm.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL) else { continue }
            let content = Self.decodedText(data)

            var count = 0
            for line in content.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("---") || t.hasPrefix("...") || t.hasPrefix("name:") || t.hasPrefix("version:") || t.hasPrefix("sort:") || t.hasPrefix("use_preset") || t.hasPrefix("import_tables") { continue }
                if t.contains("\t") || t.contains(" ") { count += 1 }
            }
            counts[name] = count
        }
        entryCounts = counts
    }

    func entryCount(for name: String) -> Int {
        entryCounts[name] ?? 0
    }

    /// Load from rime_mint.dict.yaml
    func load(from url: URL) {
        reset()
        dictFileURL = url
        guard let data = try? Data(contentsOf: url) else { return }
        let content = Self.decodedText(data)
        originalYAML = content

        // dict.yaml 通常含两个文档（元数据 + `...` 之后的词条正文），
        // Yams.load 遇到多文档会直接抛错，必须逐文档解析取第一个
        guard let documents = try? Yams.load_all(yaml: content),
              let dict = documents.compactMap({ $0 as? [String: Any] }).first else { return }
        schemaName = dict["name"] as? String ?? ""

        if let tables = dict["import_tables"] as? [String] {
            importTables = tables.map { name in
                let desc = dictDescription(for: name.trimmingCharacters(in: .whitespaces))
                return DictEntry(name: name.trimmingCharacters(in: .whitespaces), enabled: true, description: desc)
            }
        }
    }

    /// Generate updated YAML with current import_tables.
    /// 采用文本替换只改 import_tables 块：Yams.load 只解析第一个文档，
    /// 直接重解析再 dump 会丢掉 `...` 之后的词条正文和全部注释。
    func generateYAML() -> String {
        let enabled = importTables.filter(\.enabled).map(\.name)
        guard let newBlock = try? Yams.dump(object: ["import_tables": enabled]) else {
            return originalYAML
        }
        let newLines = newBlock.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var lines = originalYAML.components(separatedBy: "\n")

        guard let start = lines.firstIndex(where: { $0.hasPrefix("import_tables:") }) else {
            // 原文件没有 import_tables：插入到词条正文分隔符之前，或追加到末尾
            if let dotIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "..." }) {
                lines.insert(contentsOf: newLines, at: dotIndex)
            } else {
                lines.append(contentsOf: newLines)
            }
            return lines.joined(separator: "\n")
        }

        // 块结束于下一个文档标记 / 顶层键 / 注释行
        var end = lines.count
        for i in lines.indices where i > start {
            let t = lines[i]
            if t.isEmpty { continue }
            let isMarker = t == "---" || t == "..."
            let isTopLevelKey = !t.hasPrefix(" ") && !t.hasPrefix("\t") && !t.hasPrefix("-")
                && !t.hasPrefix("#") && t.contains(":")
            if isMarker || isTopLevelKey || t.hasPrefix("#") {
                end = i
                break
            }
        }
        lines.replaceSubrange(start..<end, with: newLines)
        return lines.joined(separator: "\n")
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

    private static func decodedText(_ data: Data) -> String {
        if let content = String(data: data, encoding: .utf8) { return content }
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        return String(data: data, encoding: gb18030) ?? ""
    }
}
