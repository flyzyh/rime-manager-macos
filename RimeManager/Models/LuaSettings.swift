import SwiftUI
import Yams

/// Lua 扩展开关管理
/// 扫描 schema engine 中的 lua_processor / lua_translator / lua_filter 引用
@MainActor
final class LuaSettings: ObservableObject {
    @Published var luaEntries: [LuaEntry] = []
    @Published var reverseLookups: [String: Bool] = [:]

    private var rawSchemaDict: [String: Any] = [:]

    struct LuaEntry: Identifiable {
        let id = UUID()
        var fullName: String     // lua_processor@*kp_number_processor
        var type: String         // processor / translator / filter
        var scriptName: String   // kp_number_processor
        var enabled: Bool
        var description: String
        var engineSection: String // processors / translators / filters
    }

    // MARK: - 已知 Lua 脚本说明

    static let descriptions: [String: String] = [
        "kp_number_processor": "小键盘数字映射到主键盘",
        "select_character": "候选词单字选择",
        "codeLengthLimit_processor": "限制输入码长度，防卡顿",
        "unicode_translator": "Unicode 编码输入候选",
        "shijian": "时间/日期/星期/节日输入",
        "number_translator": "金额大小写转换",
        "chineseLunarCalendar_translator": "农历公历转换",
        "mint_calculator_translator": "计算器",
        "force_gc": "垃圾回收，降低内存占用",
        "corrector_filter": "错音错字提示",
        "super_preedit": "输入码显示全拼+声调",
        "autocap_filter": "英文自动大写",
        "reduce_english_filter": "降低英文单词候选优先级",
    ]

    // MARK: - Load

    func load(schemaYAML: String) {
        guard let dict = try? Yams.load(yaml: schemaYAML) as? [String: Any],
              let engine = dict["engine"] as? [String: Any] else { return }
        rawSchemaDict = dict

        var entries: [LuaEntry] = []
        let sections: [(String, String)] = [
            ("processors", "lua_processor"),
            ("translators", "lua_translator"),
            ("filters", "lua_filter"),
        ]

        for (section, prefix) in sections {
            guard let list = engine[section] as? [Any] else { continue }
            for item in list {
                guard let str = item as? String, str.hasPrefix(prefix) else { continue }
                let scriptName = str.replacingOccurrences(of: "\(prefix)@*", with: "")
                entries.append(LuaEntry(
                    fullName: str,
                    type: prefix.replacingOccurrences(of: "lua_", with: ""),
                    scriptName: scriptName,
                    enabled: true,
                    description: Self.descriptions[scriptName] ?? "",
                    engineSection: section
                ))
            }
        }

        // 扫描反查
        if let reverse = dict["reverse_lookup"] as? [String: Any] {
            for (key, _) in reverse {
                reverseLookups[key] = true
            }
        }
        if let engineList = engine["translators"] as? [String] {
            for item in engineList {
                if item.hasPrefix("reverse_lookup_translator@") {
                    let name = item.replacingOccurrences(of: "reverse_lookup_translator@", with: "")
                    reverseLookups[name] = true
                }
            }
        }

        luaEntries = entries
    }

    // MARK: - Toggle

    func toggle(_ id: UUID) {
        guard let idx = luaEntries.firstIndex(where: { $0.id == id }) else { return }
        luaEntries[idx].enabled.toggle()
    }

    func toggleReverseLookup(_ name: String) {
        reverseLookups[name, default: false].toggle()
    }

    // MARK: - Generate

    /// 生成 patch：engine 段仅保留启用的 lua 引用 + 反查开关
    func generatePatch() -> [String: Any] {
        var patch: [String: Any] = [:]

        // engine: 按 section 分组重建 lua 引用（保留非 lua 项由 patch 追加机制处理）
        var enginePatch: [String: Any] = [:]
        for section in ["processors", "translators", "filters"] {
            let enabled = luaEntries.filter { $0.engineSection == section && $0.enabled }
                .map(\.fullName)
            if !enabled.isEmpty {
                enginePatch[section] = enabled
            }
        }
        if !enginePatch.isEmpty { patch["engine"] = enginePatch }

        // reverse lookup translators
        let enabledReverse = reverseLookups.filter { $0.value }.map { "reverse_lookup_translator@\($0.key)" }
        if !enabledReverse.isEmpty {
            var translators = (enginePatch["translators"] as? [String]) ?? []
            translators.append(contentsOf: enabledReverse)
            enginePatch["translators"] = translators
            patch["engine"] = enginePatch
        }

        return patch
    }
}
