import SwiftUI
import Yams

/// 同步与高级设置管理
/// 包含：installation.yaml 同步、用户词库、OpenCC 简繁链、方案切换快捷键、应用级配置
@MainActor
final class AdvancedSettings: ObservableObject {
    // MARK: - Sync (installation.yaml)

    @Published var installationID: String = ""
    @Published var syncDir: String = ""
    @Published var distributionName: String = ""

    // MARK: - Switcher (方案切换快捷键)

    @Published var switcherHotkeys: [String] = ["Control+grave"]
    @Published var switcherCaption: String = "〔方案切换〕"

    // MARK: - OpenCC 简繁转换链

    @Published var enabledSimplifiers: [String: Bool] = [:]
    static let openccChains: [String: String] = [
        "t2s": "繁体→简体",
        "s2t": "简体→繁体",
        "t2hk": "繁体→香港",
        "t2tw": "繁体→台湾",
        "s2hk": "简体→香港",
        "s2tw": "简体→台湾",
        "emoji_suggestion": "Emoji 建议",
        "transcription_cc": "简繁自动切换",
    ]

    // MARK: - 用户词库

    @Published var userdbSize: String = ""
    @Published var userdbCount: Int = 0

    private var rawDefaultDict: [String: Any] = [:]
    /// 加载时的完整 filters 列表，用于安全重建（避免覆盖掉 lua_filter 等条目）
    private var originalFilters: [String] = []
    /// 加载时的完整 installation.yaml，回写时保留 Rime 自身的字段
    private var originalInstallationDict: [String: Any] = [:]
    private var originalInstallationYAML = ""
    /// 加载时的 switcher 基线（default.yaml 未定义时为内置默认），用于判断用户是否修改
    private var baselineSwitcherHotkeys: [String] = ["Control+grave"]
    private var baselineSwitcherCaption: String = "〔方案切换〕"

    // MARK: - Load

    func load(
        installationYAML: String,
        defaultYAML: String,
        schemaYAML: String,
        defaultCustomYAML: String = "",
        schemaCustomYAML: String = ""
    ) {
        // 先复位，避免二次加载残留上一次状态
        installationID = ""
        syncDir = ""
        distributionName = ""
        switcherHotkeys = ["Control+grave"]
        switcherCaption = "〔方案切换〕"
        baselineSwitcherHotkeys = switcherHotkeys
        baselineSwitcherCaption = switcherCaption
        enabledSimplifiers = [:]
        rawDefaultDict = [:]
        originalFilters = []
        originalInstallationDict = [:]
        originalInstallationYAML = installationYAML

        // installation.yaml
        if let d = try? Yams.load(yaml: installationYAML) as? [String: Any] {
            originalInstallationDict = d
            installationID = d["installation_id"] as? String ?? ""
            syncDir = d["sync_dir"] as? String ?? ""
            distributionName = d["distribution_name"] as? String ?? ""
        }

        // switcher + simplifiers from default.yaml
        if let d = try? Yams.load(yaml: defaultYAML) as? [String: Any] {
            rawDefaultDict = d
            if let sw = d["switcher"] as? [String: Any] {
                switcherHotkeys = sw["hotkeys"] as? [String] ?? ["Control+grave"]
                switcherCaption = sw["caption"] as? String ?? "〔方案切换〕"
            }
        }

        // default.custom.yaml 中的 switcher 补丁覆盖显示值（扁平键优先，兼容旧整体节点），
        // 否则应用后重启会回显 default.yaml 的旧值，而实际生效的是补丁值
        if let customDict = try? Yams.load(yaml: defaultCustomYAML) as? [String: Any],
           let root = customDict["patch"] as? [String: Any] {
            if let hotkeys = root["switcher/hotkeys"] as? [String] {
                switcherHotkeys = hotkeys
            } else if let node = root["switcher"] as? [String: Any],
                      let hotkeys = node["hotkeys"] as? [String] {
                switcherHotkeys = hotkeys
            }
            if let caption = root["switcher/caption"] as? String {
                switcherCaption = caption
            } else if let node = root["switcher"] as? [String: Any],
                      let caption = node["caption"] as? String {
                switcherCaption = caption
            }
        }
        // 记录 UI 基线：用户未修改时不写 patch，避免把当前生效值固化进 custom 文件
        baselineSwitcherHotkeys = switcherHotkeys
        baselineSwitcherCaption = switcherCaption

        // simplifiers from schema：记录完整 filters 列表
        enabledSimplifiers = [:]
        if let d = try? Yams.load(yaml: schemaYAML) as? [String: Any],
           let engine = d["engine"] as? [String: Any],
           let rawFilters = engine["filters"] as? [String] ?? (engine["filters"] as? [Any])?.compactMap({ $0 as? String }) {
            originalFilters = rawFilters
            for f in rawFilters {
                if f.hasPrefix("simplifier@") {
                    let name = f.replacingOccurrences(of: "simplifier@", with: "")
                    enabledSimplifiers[name] = true
                }
            }
        }

        // Apply the currently effective schema custom patch (including `+`/`@n`) before showing UI.
        let engineSections = RimePatchNormalizer.effectiveEngineSections(
            schemaYAML: schemaYAML,
            patchYAML: schemaCustomYAML
        )
        if let filters = engineSections["filters"] {
            originalFilters = filters
        }
        // patch 追加的 simplifier 也要出现在 UI 中，避免用户无法关闭新增链路。
        let simplifiedNames = Set(originalFilters.compactMap { $0.hasPrefix("simplifier@") ? String($0.dropFirst("simplifier@".count)) : nil })
        enabledSimplifiers = Dictionary(uniqueKeysWithValues: simplifiedNames.map { ($0, false) })
        for name in simplifiedNames {
            enabledSimplifiers[name] = originalFilters.contains("simplifier@\(name)")
        }
    }

    func toggleSimplifier(_ name: String) {
        enabledSimplifiers[name, default: false].toggle()
    }

    // MARK: - Generate

    func generateInstallationYAML() -> String {
        // 保留原始字段（distribution_code_name / install_time / rime_version / update_time 等），仅更新用户可编辑项
        var dict = originalInstallationDict
        if dict.isEmpty {
            // 无原文件时创建最小合法配置
            dict = [
                "distribution_code_name": "Squirrel",
                "distribution_name": "鼠鬚管",
                "distribution_version": "1.1.2",
                "installation_id": installationID.isEmpty ? UUID().uuidString.lowercased() : installationID,
                "rime_version": "1.16.0",
                "install_time": Date().formatted(.iso8601),
                "update_time": Date().formatted(.iso8601),
            ]
        }
        if !installationID.isEmpty { dict["installation_id"] = installationID }
        // 清空 sync_dir 时移除该键，允许用户撤销同步目录设置
        if syncDir.isEmpty {
            dict.removeValue(forKey: "sync_dir")
        } else {
            // Rime 不展开 shell 波浪号；保存时写入绝对路径。
            let path = (syncDir as NSString).expandingTildeInPath
            dict["sync_dir"] = path
        }
        guard let yaml = try? Yams.dump(object: dict), !yaml.isEmpty else {
            return originalInstallationYAML
        }
        return yaml
    }

    /// 生成 default.custom.yaml 的补丁（switcher 部分）。
    /// 仅写入用户修改过的扁平键（switcher/hotkeys、switcher/caption），
    /// 绝不整体替换 switcher 节点——那会丢失 default.yaml 中的
    /// save_options 等同级配置。
    func generateDefaultPatch() -> [String: Any] {
        var patch: [String: Any] = [:]

        // 与加载时的 UI 基线比较：用户未改则不写
        if switcherHotkeys != baselineSwitcherHotkeys {
            patch["switcher/hotkeys"] = switcherHotkeys
        }
        if switcherCaption != baselineSwitcherCaption {
            patch["switcher/caption"] = switcherCaption
        }
        return patch
    }

    /// 生成 engine/filters 补丁。
    /// engine 在 schema 层定义，Rime 合并时 schema 的列表会整体覆盖
    /// default 层，因此该补丁必须写入 rime_mint.custom.yaml（schema 层），
    /// 放到 default.custom.yaml 不生效。
    /// 以完整原始列表为基底重建，绝不部分覆盖。
    func filtersPatchDict() -> [String: Any] {
        guard !originalFilters.isEmpty else { return [:] }

        let enabledSet = Set(enabledSimplifiers.filter { $0.value }.map { "simplifier@\($0.key)" })
        var rebuilt: [String] = []
        for f in originalFilters {
            if f.hasPrefix("simplifier@") {
                if enabledSet.contains(f) { rebuilt.append(f) }
            } else {
                rebuilt.append(f)
            }
        }
        if rebuilt == originalFilters {
            return [:]
        }
        return ["engine/filters": rebuilt]
    }

    // MARK: - 用户词库

    func scanUserDB(in rimeDir: URL) {
        let fm = FileManager.default
        let userdbDirs = (try? fm.contentsOfDirectory(at: rimeDir, includingPropertiesForKeys: nil)) ?? []
            .filter { $0.lastPathComponent.hasSuffix(".userdb") }

        var totalBytes: Int64 = 0
        var fileCount = 0
        for dir in userdbDirs {
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for f in files {
                    if let size = (try? f.resourceValues(forKeys: [.fileSizeKey]))?.fileSize as? Int64 {
                        totalBytes += size
                        fileCount += 1
                    }
                }
            }
        }
        userdbCount = fileCount
        userdbSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// 清空所有用户词库
    func clearUserDB(in rimeDir: URL) -> Int {
        let fm = FileManager.default
        let userdbDirs = (try? fm.contentsOfDirectory(at: rimeDir, includingPropertiesForKeys: nil)) ?? []
            .filter { $0.lastPathComponent.hasSuffix(".userdb") }
        for dir in userdbDirs {
            try? fm.removeItem(at: dir)
        }
        return userdbDirs.count
    }
}
