import SwiftUI
import Yams

/// 标点符号映射管理（punctuator half_shape / full_shape）
@MainActor
final class PunctuatorSettings: ObservableObject {
    @Published var halfShape: [PunctEntry] = []
    @Published var fullShape: [PunctEntry] = []

    private var rawSchemaDict: [String: Any] = [:]

    struct PunctEntry: Identifiable {
        let id = UUID()
        var key: String                    // 输入键，如 "."
        var commit: String                 // 首选输出，如 "。"
        var candidates: [String]           // 候选列表
        var isPair: Bool                   // 是否成对括号
        var pairOpen: String = ""
        var pairClose: String = ""

        var displayValue: String {
            if isPair { return "\(pairOpen) \(pairClose)" }
            if !candidates.isEmpty { return candidates.joined(separator: " / ") }
            return commit
        }
    }

    // MARK: - Load

    func load(schemaYAML: String) {
        guard let dict = try? Yams.load(yaml: schemaYAML) as? [String: Any],
              let punct = dict["punctuator"] as? [String: Any] else { return }
        rawSchemaDict = dict

        halfShape = parseMap(punct["half_shape"])
        fullShape = parseMap(punct["full_shape"])
    }

    private func parseMap(_ value: Any?) -> [PunctEntry] {
        guard let map = value as? [String: Any] else { return [] }
        return map.map { key, val in
            var entry = PunctEntry(key: key, commit: "", candidates: [], isPair: false)
            if let s = val as? String {
                entry.commit = s
            } else if let arr = val as? [String] {
                entry.commit = arr.first ?? ""
                entry.candidates = arr
            } else if let d = val as? [String: Any] {
                if let c = d["commit"] as? String { entry.commit = c }
                if let pair = d["pair"] as? [String], pair.count >= 2 {
                    entry.isPair = true
                    entry.pairOpen = pair[0]
                    entry.pairClose = pair[1]
                }
            }
            return entry
        }.sorted { $0.key < $1.key }
    }

    // MARK: - CRUD

    func addEntry(to target: inout [PunctEntry], key: String, commit: String) {
        guard !key.isEmpty else { return }
        target.append(PunctEntry(key: key, commit: commit, candidates: [], isPair: false))
        target.sort { $0.key < $1.key }
    }

    func removeEntry(from target: inout [PunctEntry], id: UUID) {
        target.removeAll { $0.id == id }
    }

    // MARK: - Generate

    /// 生成 patch 到 rime_mint.custom.yaml
    func generatePatch() -> [String: Any] {
        func mapDict(_ entries: [PunctEntry]) -> [String: Any] {
            var map: [String: Any] = [:]
            for e in entries {
                if e.isPair {
                    map[e.key] = ["pair": [e.pairOpen, e.pairClose]]
                } else if e.candidates.count > 1 {
                    map[e.key] = e.candidates
                } else {
                    map[e.key] = e.commit
                }
            }
            return map
        }

        var punctPatch: [String: Any] = [:]
        let half = mapDict(halfShape)
        let full = mapDict(fullShape)
        // 空映射不写入，避免用空字典覆盖 schema 原有定义
        if !half.isEmpty { punctPatch["half_shape"] = half }
        if !full.isEmpty { punctPatch["full_shape"] = full }

        return punctPatch.isEmpty ? [:] : ["punctuator": punctPatch]
    }
}
