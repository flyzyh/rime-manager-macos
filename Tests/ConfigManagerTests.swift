import XCTest
import Yams
@testable import RimeManager

/// ConfigManager 加载→生成→应用 的封闭集成测试（真实临时目录，不触碰 ~/Library/Rime）
@MainActor
final class ConfigManagerTests: XCTestCase {

    nonisolated(unsafe) var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigManagerTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private let schemaYAML = """
    schema:
      schema_id: rime_mint
      name: 薄荷拼音

    switches:
      - name: ascii_mode
        reset: 0
        states: [中文, English]
      - name: emoji_suggestion
        reset: 1
        states: [off, on]
      - name: unmanaged_switch
        reset: 0
        states: [x, y]

    engine:
      filters:
        - simplifier@emoji_suggestion
        - simplifier@transcription_cc
        - uniquifier
    translator:
      dictionary: mint
      enable_user_dict: true
    """

    private func write(_ content: String, to fileName: String) throws {
        try content.write(to: tempDir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func readPatch(_ fileName: String) throws -> [String: Any] {
        let content = try String(contentsOf: tempDir.appendingPathComponent(fileName), encoding: .utf8)
        let dict = try XCTUnwrap(try Yams.load(yaml: content) as? [String: Any], "\(fileName) 应为合法 YAML")
        return try XCTUnwrap(dict["patch"] as? [String: Any], "\(fileName) 应含 patch")
    }

    private func loadAndApply() throws -> ConfigManager {
        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        try cm.applyAllConfigChanges(in: tempDir)
        return cm
    }

    // MARK: - 保留用户手工补丁

    func testApplyPreservesUnknownKeysInDefaultCustom() throws {
        try """
        patch:
          custom_manual_key: hello
          nested:
            keep_me: true
        """.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)

        _ = try loadAndApply()

        let patch = try readPatch("default.custom.yaml")
        XCTAssertEqual(patch["custom_manual_key"] as? String, "hello", "手工补丁键不得被抹掉")
        XCTAssertEqual((patch["nested"] as? [String: Any])?["keep_me"] as? Bool, true)
    }

    func testInvalidCustomYAMLBlocksDestructiveApply() throws {
        let original = """
        patch:
          custom_manual_key: keep-me
          broken: [unclosed
        """
        try original.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        XCTAssertThrowsError(try cm.applyAllConfigChanges(in: tempDir))
        XCTAssertEqual(try String(contentsOf: tempDir.appendingPathComponent("default.custom.yaml"), encoding: .utf8), original)
    }

    func testCustomTranslatorOverridesSchema() throws {
        try write(schemaYAML, to: "rime_mint.schema.yaml")
        try """
        patch:
          translator/enable_user_dict: false
        """.write(to: tempDir.appendingPathComponent("rime_mint.custom.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        XCTAssertFalse(cm.inputSettings.enableUserDict)
    }

    func testLuaStateReadsExistingEnginePatch() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test

        engine:
          processors:
            - lua_processor@*mint_calculator_translator
            - spacer
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)
        try """
        patch:
          engine/processors:
            - spacer
        """.write(to: tempDir.appendingPathComponent("rime_mint.custom.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        let entry = try XCTUnwrap(cm.luaSettings.luaEntries.first { $0.scriptName == "mint_calculator_translator" })
        XCTAssertFalse(entry.enabled, "schema 中存在但 patch 已移除的 Lua 应显示为禁用且可恢复")
    }

    func testApplyPreservesUnknownAppOptionAndColorSchemeFields() throws {
        try """
        preset_color_schemes:
          custom:
            back_color: 0xFFFFFF
            custom_property: keep-me

        app_options:
          com.example.unknown:
            no_inline: false
            custom_option: keep-me
        """.write(to: tempDir.appendingPathComponent("squirrel.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.squirrelConfig.colorSchemes["custom"]?.schemeAlpha = 0.5
        try cm.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("squirrel.custom.yaml")
        let options = try XCTUnwrap(patch["app_options/com.example.unknown/custom_option"] as? String)
        XCTAssertEqual(options, "keep-me")
        let scheme = try XCTUnwrap(patch["preset_color_schemes/custom/custom_property"] as? String)
        XCTAssertEqual(scheme, "keep-me")
        XCTAssertEqual(patch["preset_color_schemes/custom/alpha"] as? Double, 0.5)
    }

    func testApplyAvoidsConflictingPatchPaths() throws {
        try write(schemaYAML, to: "rime_mint.schema.yaml")
        try """
        patch:
          menu/page_size: 7
          translator:
            dictionary: custom
            keep_me: true
          engine:
            filters:
              - simplifier@emoji_suggestion
          punctuator/half_shape:
            ".": "。"
        """.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)
        try """
        patch:
          menu/page_size: 7
          punctuator/half_shape:
            ".": "。"
        """.write(to: tempDir.appendingPathComponent("rime_mint.custom.yaml"), atomically: true, encoding: .utf8)

        _ = try loadAndApply()
        let defaultPatch = try readPatch("default.custom.yaml")
        XCTAssertEqual(defaultPatch["menu/page_size"] as? Int, 7)
        XCTAssertEqual(defaultPatch["translator/dictionary"] as? String, "custom")
        XCTAssertEqual(defaultPatch["translator/keep_me"] as? Bool, true)

        let schemaPatch = try readPatch("rime_mint.custom.yaml")
        XCTAssertFalse(schemaPatch["engine"] != nil && schemaPatch["engine/filters"] != nil)
        XCTAssertFalse(schemaPatch["punctuator"] != nil && schemaPatch["punctuator/half_shape"] != nil)
    }

    // MARK: - switcher 旧格式迁移

    func testSwitcherLegacyNodeMigratedToFlatKeys() throws {
        try """
        patch:
          switcher:
            caption: 〔方案切换〕
            hotkeys:
              - Control+grave
              - Control+Shift+grave
        """.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)

        _ = try loadAndApply()

        let patch = try readPatch("default.custom.yaml")
        XCTAssertNil(patch["switcher"], "旧整体节点应被迁移为扁平键")
        XCTAssertEqual(patch["switcher/hotkeys"] as? [String], ["Control+grave", "Control+Shift+grave"])
        XCTAssertNotNil(patch["switcher/caption"])
    }

    // MARK: - key_binder 保留与防重复

    func testApplyPreservesKeyBinderAppendKeyInBase() throws {
        try """
        patch:
          key_binder/bindings/+:
            - {when: composing, accept: Return, send: Return}
            - {when: composing, accept: KP_Enter, send: Return}
        """.write(to: tempDir.appendingPathComponent("default.custom.yaml"), atomically: true, encoding: .utf8)

        _ = try loadAndApply()

        let patch = try readPatch("default.custom.yaml")
        let appended = try XCTUnwrap(patch["key_binder/bindings/+"] as? [[String: Any]])
        XCTAssertEqual(appended.count, 2, "基底追加键应原样保留")
        XCTAssertNil(patch["key_binder/bindings"], "未编辑绑定时不写全量键")
    }

    func testApplyAddsReturnFixOnceAndDoesNotDuplicate() throws {
        try write(schemaYAML, to: "rime_mint.schema.yaml")

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.inputSettings.returnDirectCommit = true
        try cm.applyAllConfigChanges(in: tempDir)

        // 二次应用（模拟重启后再应用）：不得重复追加 Return 修复
        let cm2 = ConfigManager()
        cm2.loadAllConfigs(in: tempDir)
        try cm2.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("default.custom.yaml")
        let appended = try XCTUnwrap(patch["key_binder/bindings/+"] as? [[String: Any]])
        XCTAssertEqual(appended.count, 1, "重复应用不得重复追加 Return 修复")
    }

    // MARK: - schema 层补丁（switches / engine/filters）

    func testSwitchesAndFiltersWrittenAtSchemaLevel() throws {
        try write(schemaYAML, to: "rime_mint.schema.yaml")

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.inputSettings.emojiSuggestion = false
        cm.advancedSettings.toggleSimplifier("emoji_suggestion")
        try cm.applyAllConfigChanges(in: tempDir)

        let defaultPatch = try readPatch("default.custom.yaml")
        XCTAssertNil(defaultPatch["switches"], "switches 不应写入 default 层")
        XCTAssertNil(defaultPatch["engine/filters"], "engine/filters 不应写入 default 层")

        let schemaPatch = try readPatch("rime_mint.custom.yaml")
        XCTAssertEqual(schemaPatch["switches/@1/reset"] as? Int, 0, "未修改完整列表时只 patch item reset")

        let filters = try XCTUnwrap(
            (schemaPatch["engine"] as? [String: Any])?["filters"] as? [String]
                ?? schemaPatch["engine/filters"] as? [String]
        )
        XCTAssertFalse(filters.contains("simplifier@emoji_suggestion"))
        XCTAssertTrue(filters.contains("simplifier@transcription_cc"))
        XCTAssertTrue(filters.contains("uniquifier"))
    }

    func testUnchangedSwitchesAndFiltersNotWritten() throws {
        try write(schemaYAML, to: "rime_mint.schema.yaml")

        _ = try loadAndApply()

        let schemaPatch = try readPatch("rime_mint.custom.yaml")
        XCTAssertNil(schemaPatch["switches"], "无修改时不写 switches")
        XCTAssertNil(schemaPatch["engine/filters"], "无修改时不写 engine/filters")
    }
}
