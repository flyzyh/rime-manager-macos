import XCTest
import Yams
@testable import RimeManager

@MainActor
final class AdvancedSettingsTests: XCTestCase {

    let defaultYAMLWithSwitcher = """
    switcher:
      caption: 〔方案切换〕
      hotkeys:
        - Control+grave
        - Control+Shift+grave
      save_options:
        - full_shape
    """

    let schemaYAMLWithFilters = """
    engine:
      filters:
        - simplifier@emoji_suggestion
        - simplifier@transcription_cc
        - uniquifier
    """

    // MARK: - Switcher Patch Tests

    func testSwitcherPatchUsesFlatKeysAndSkipsUnchanged() {
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: defaultYAMLWithSwitcher, schemaYAML: "")

        // 未修改时不写任何 switcher 键
        XCTAssertTrue(adv.generateDefaultPatch().isEmpty)

        // 修改后只写扁平键，不整体替换 switcher 节点
        adv.switcherHotkeys = ["F4"]
        let patch = adv.generateDefaultPatch()

        XCTAssertNil(patch["switcher"], "不允许整体替换 switcher 节点（会丢失 save_options 等同级配置）")
        XCTAssertEqual(patch["switcher/hotkeys"] as? [String], ["F4"])
        XCTAssertNil(patch["switcher/caption"], "caption 未修改时不应写入")
    }

    func testSwitcherLoadKeepsAllHotkeys() {
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: defaultYAMLWithSwitcher, schemaYAML: "")

        XCTAssertEqual(adv.switcherHotkeys, ["Control+grave", "Control+Shift+grave"])
        XCTAssertEqual(adv.switcherCaption, "〔方案切换〕")
    }

    func testSwitcherNotPinnedWhenDefaultYAMLHasNoSwitcher() {
        // default.yaml 未定义 switcher 时，未修改不得把内置默认固化进 patch
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: "", schemaYAML: "")

        XCTAssertTrue(adv.generateDefaultPatch().isEmpty)
    }

    func testSwitcherLoadReadsCustomPatch() {
        // 已应用的 switcher 补丁必须回显，否则 UI 显示 default.yaml 旧值而实际生效补丁值
        let adv = AdvancedSettings()
        adv.load(
            installationYAML: "",
            defaultYAML: defaultYAMLWithSwitcher,
            schemaYAML: "",
            defaultCustomYAML: "patch:\n  switcher/hotkeys:\n    - F4\n"
        )
        XCTAssertEqual(adv.switcherHotkeys, ["F4"])

        // 基线与显示值同步 → 未修改不写 patch
        XCTAssertTrue(adv.generateDefaultPatch().isEmpty)

        // 修改后写扁平键
        adv.switcherHotkeys = ["Control+space"]
        XCTAssertEqual(adv.generateDefaultPatch()["switcher/hotkeys"] as? [String], ["Control+space"])
    }

    func testSwitcherLoadReadsLegacyNodeFromCustomPatch() {
        let adv = AdvancedSettings()
        adv.load(
            installationYAML: "",
            defaultYAML: defaultYAMLWithSwitcher,
            schemaYAML: "",
            defaultCustomYAML: "patch:\n  switcher:\n    caption: 自定义\n    hotkeys:\n      - F4\n"
        )
        XCTAssertEqual(adv.switcherHotkeys, ["F4"])
        XCTAssertEqual(adv.switcherCaption, "自定义")
    }

    // MARK: - Filters Patch Tests

    func testFiltersPatchNotInDefaultPatch() {
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: defaultYAMLWithSwitcher, schemaYAML: schemaYAMLWithFilters)

        // 关掉一个 simplifier 后，engine/filters 补丁不允许出现在 default.custom patch 中
        // （schema 层定义的列表会整体覆盖 default 层，写在那里不生效）
        adv.toggleSimplifier("emoji_suggestion")

        XCTAssertNil(adv.generateDefaultPatch()["engine/filters"])
    }

    func testFiltersPatchDictReturnsEngineFiltersWhenChanged() {
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: "", schemaYAML: schemaYAMLWithFilters)

        // 未修改 → 空
        XCTAssertTrue(adv.filtersPatchDict().isEmpty)

        // 禁用 emoji_suggestion → 以完整原始列表为基底重建
        adv.toggleSimplifier("emoji_suggestion")
        let patch = adv.filtersPatchDict()
        let filters = patch["engine/filters"] as? [String]

        XCTAssertEqual(filters, ["simplifier@transcription_cc", "uniquifier"])
    }

    // MARK: - Installation YAML Tests

    func testInstallationYAMLPreservesOriginalFields() {
        let installationYAML = """
        installation_id: abc-123
        sync_dir: /Users/test/sync
        install_time: "2024-01-01 00:00:00"
        rime_version: 1.16.0
        """
        let adv = AdvancedSettings()
        adv.load(installationYAML: installationYAML, defaultYAML: "", schemaYAML: "")

        // 未修改 sync_dir → 原值保留
        let output = adv.generateInstallationYAML()
        XCTAssertTrue(output.contains("abc-123"))
        XCTAssertTrue(output.contains("install_time"))
    }

    func testInstallationYAMLRemovesSyncDirWhenCleared() {
        let installationYAML = """
        installation_id: abc-123
        sync_dir: /Users/test/sync
        """
        let adv = AdvancedSettings()
        adv.load(installationYAML: installationYAML, defaultYAML: "", schemaYAML: "")

        adv.syncDir = ""
        let output = adv.generateInstallationYAML()

        XCTAssertFalse(output.contains("sync_dir"), "清空 sync_dir 后应移除该键，而不是残留旧值")
        XCTAssertTrue(output.contains("abc-123"))
    }

    func testInstallationYAMLGeneratesIDWhenMissing() {
        let adv = AdvancedSettings()
        adv.load(installationYAML: "", defaultYAML: "", schemaYAML: "")

        let output = adv.generateInstallationYAML()
        XCTAssertTrue(output.contains("installation_id:"))
        XCTAssertFalse(output.contains("installation_id: \"\""))
    }
}
