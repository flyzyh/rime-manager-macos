import SwiftUI
import Yams

/// Lua 扩展开关管理
/// 扫描 schema engine 中的 lua_processor / lua_translator / lua_filter 引用
@MainActor
final class LuaSettings: ObservableObject {
    @Published var luaEntries: [LuaEntry] = []
    @Published var reverseLookups: [String: Bool] = [:]

    private var rawSchemaDict: [String: Any] = [:]
    /// 加载时的完整 engine 列表（含非 lua 项），用于安全重建
    private var originalSections: [String: [String]] = [:]

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

        // 保存完整原始列表
        for section in ["processors", "segmentors", "translators", "filters"] {
            if let list = engine[section] as? [String] {
                originalSections[section] = list
            } else if let list = engine[section] as? [Any] {
                originalSections[section] = list.compactMap { $0 as? String }
            }
        }

        var entries: [LuaEntry] = []
        let sections: [(String, String)] = [
            ("processors", "lua_processor"),
            ("translators", "lua_translator"),
            ("filters", "lua_filter"),
        ]

        for (section, prefix) in sections {
            guard let list = originalSections[section] else { continue }
            for str in list {
                guard str.hasPrefix(prefix) else { continue }
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

        // 反查：仅管理 translators 中的 reverse_lookup_translator@ 条目
        reverseLookups = [:]
        if let translators = originalSections["translators"] {
            for item in translators where item.hasPrefix("reverse_lookup_translator@") {
                let name = item.replacingOccurrences(of: "reverse_lookup_translator@", with: "")
                reverseLookups[name] = true
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

    /// 生成 patch：以完整原始列表为基底重建，仅剔除被禁用的 lua / 反查条目。
    /// 绝不使用部分列表覆盖——那会破坏 script_translator 等核心组件。
    func generatePatch() -> [String: Any] {
        var patch: [String: Any] = [:]

        // 三个可编辑 section
        let luaPrefixBySection: [String: String] = [
            "processors": "lua_processor",
            "translators": "lua_translator",
            "filters": "lua_filter",
        ]

        for (section, prefix) in luaPrefixBySection {
            guard let original = originalSections[section] else { continue }
            let enabledSet = Set(luaEntries.filter { $0.engineSection == section && $0.enabled }.map(\.fullName))

            var rebuilt: [String] = []
            for item in original {
                if item.hasPrefix(prefix) {
                    if enabledSet.contains(item) { rebuilt.append(item) }
                    // 被禁用的 lua 条目剔除
                } else if section == "translators" && item.hasPrefix("reverse_lookup_translator@") {
                    let name = item.replacingOccurrences(of: "reverse_lookup_translator@", with: "")
                    if reverseLookups[name] ?? false { rebuilt.append(item) }
                } else {
                    rebuilt.append(item) // 非 lua 核心组件原样保留
                }
            }

            if rebuilt != original {
                patch["engine/\(section)"] = rebuilt
            }
        }

        return patch
    }
}
