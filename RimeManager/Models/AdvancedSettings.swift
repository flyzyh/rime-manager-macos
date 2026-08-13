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

    // MARK: - Load

    func load(installationYAML: String, defaultYAML: String, schemaYAML: String) {
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

        // simplifiers from schema：记录完整 filters 列表
        enabledSimplifiers = [:]
        if let d = try? Yams.load(yaml: schemaYAML) as? [String: Any],
           let engine = d["engine"] as? [String: Any],
           let filters = engine["filters"] as? [String] {
            originalFilters = filters
            for f in filters {
                if f.hasPrefix("simplifier@") {
                    let name = f.replacingOccurrences(of: "simplifier@", with: "")
                    enabledSimplifiers[name] = true
                }
            }
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
                "installation_id": installationID,
                "rime_version": "1.16.0",
                "install_time": Date().formatted(.iso8601),
                "update_time": Date().formatted(.iso8601),
            ]
        }
        dict["installation_id"] = installationID
        if !syncDir.isEmpty { dict["sync_dir"] = syncDir }
        return (try? Yams.dump(object: dict)) ?? ""
    }

    func generateDefaultPatch() -> [String: Any] {
        var patch: [String: Any] = [:]
        patch["switcher"] = ["hotkeys": switcherHotkeys, "caption": switcherCaption]

        // simplifier 开关：以完整原始列表为基底重建，绝不部分覆盖
        if !originalFilters.isEmpty {
            let enabledSet = Set(enabledSimplifiers.filter { $0.value }.map { "simplifier@\($0.key)" })
            var rebuilt: [String] = []
            for f in originalFilters {
                if f.hasPrefix("simplifier@") {
                    if enabledSet.contains(f) { rebuilt.append(f) }
                } else {
                    rebuilt.append(f)
                }
            }
            if rebuilt != originalFilters {
                patch["engine/filters"] = rebuilt
            }
        }
        return patch
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
