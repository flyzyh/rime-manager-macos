import XCTest
import Yams
@testable import RimeManager

/// 回归测试：Rime patch 必须使用不覆盖同级配置的字段级路径。
@MainActor
final class ConfigSemanticsRegressionTests: XCTestCase {
    nonisolated(unsafe) var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigSemanticsTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func write(_ yaml: String, to name: String) throws {
        try yaml.write(to: tempDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func readPatch(_ name: String) throws -> [String: Any] {
        let yaml = try String(contentsOf: tempDir.appendingPathComponent(name), encoding: .utf8)
        let root = try XCTUnwrap(Yams.load(yaml: yaml) as? [String: Any])
        return try XCTUnwrap(root["patch"] as? [String: Any])
    }

    func testCustomPhraseUsesTextCodeWeightOrder() {
        let settings = PhraseSettings()
        settings.load(from: "你好\tnihao\t2")

        XCTAssertEqual(settings.phrases.first?.text, "你好")
        XCTAssertEqual(settings.phrases.first?.code, "nihao")
        XCTAssertEqual(settings.generateContent(), "你好\tnihao\t2\n")
    }

    func testCustomPhraseReportsWhenSchemaDoesNotLoadIt() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        translator:
          dictionary: rime_mint
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        XCTAssertFalse(cm.phraseSettings.schemaSupportsCustomPhrase)
    }

    func testCustomPhraseReportsWhenSchemaLoadsIt() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        engine:
          translators:
            - table_translator@custom_phrase
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        XCTAssertTrue(cm.phraseSettings.schemaSupportsCustomPhrase)
    }

    func testExplicitCustomPhraseInstallUsesAppendPatch() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        translator:
          dictionary: rime_mint
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.phraseSettings.installIntoCurrentSchema()
        try cm.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("rime_mint.custom.yaml")
        let appended = try XCTUnwrap(patch["engine/translators/+"] as? [String])
        XCTAssertEqual(appended, ["table_translator@custom_phrase"])
        XCTAssertEqual(patch["custom_phrase/user_dict"] as? String, "custom_phrase")

        let cm2 = ConfigManager()
        cm2.loadAllConfigs(in: tempDir)
        XCTAssertTrue(cm2.phraseSettings.schemaSupportsCustomPhrase)
    }

    func testEngineAppendPatchesAreReadableAndDoNotConflictOnRewrite() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        engine:
          processors:
            - base_processor
            - lua_processor@*existing
          filters:
            - uniquifier
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)
        try """
        patch:
          engine/processors/+:
            - lua_processor@*added
          engine/filters/+:
            - simplifier@emoji_suggestion
        """.write(to: tempDir.appendingPathComponent("rime_mint.custom.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        let added = try XCTUnwrap(
            cm.luaSettings.luaEntries.first { $0.scriptName == "added" },
            "entries=\(cm.luaSettings.luaEntries.map(\.fullName))"
        )
        XCTAssertTrue(added.enabled)
        XCTAssertTrue(cm.advancedSettings.enabledSimplifiers["emoji_suggestion"] == true)

        cm.luaSettings.toggle(cm.luaSettings.luaEntries.first { $0.scriptName == "added" }!.id)
        cm.advancedSettings.toggleSimplifier("emoji_suggestion")
        try cm.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("rime_mint.custom.yaml")
        XCTAssertNil(patch["engine/processors/+"], "旧 + 形态必须归一化为全量 section，避免路径冲突")
        XCTAssertNil(patch["engine/filters/+"])
        let processors = try XCTUnwrap(patch["engine/processors"] as? [String])
        XCTAssertFalse(processors.contains("lua_processor@*added"))
        XCTAssertTrue(processors.contains("base_processor"))
        let filters = try XCTUnwrap(patch["engine/filters"] as? [String])
        XCTAssertFalse(filters.contains("simplifier@emoji_suggestion"))
        XCTAssertTrue(filters.contains("uniquifier"))
    }

    func testTranslatorTogglesAreWrittenToSchemaCustomLayer() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        translator:
          dictionary: rime_mint
          enable_user_dict: true
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.inputSettings.enableEncoder = false
        cm.inputSettings.enableSentence = false
        cm.inputSettings.enableUserDict = false
        cm.inputSettings.encodeCommitHistory = false
        try cm.applyAllConfigChanges(in: tempDir)

        let defaultPatch = try readPatch("default.custom.yaml")
        XCTAssertNil(defaultPatch["translator"])
        XCTAssertNil(defaultPatch["translator/enable_encoder"])
        let schemaPatch = try readPatch("rime_mint.custom.yaml")
        XCTAssertEqual(schemaPatch["translator/enable_encoder"] as? Bool, false)
        XCTAssertEqual(schemaPatch["translator/enable_sentence"] as? Bool, false)
        XCTAssertEqual(schemaPatch["translator/enable_user_dict"] as? Bool, false)
        XCTAssertEqual(schemaPatch["translator/encode_commit_history"] as? Bool, false)
    }

    func testSquirrelStyleUsesFieldLevelPatch() throws {
        try """
        style:
          color_scheme: base_light
          color_space: srgb
          line_length: 0
          font_point: 16
        """.write(to: tempDir.appendingPathComponent("squirrel.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.squirrelConfig.fontPoint = 19
        try cm.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("squirrel.custom.yaml")
        XCTAssertNil(patch["style"], "style 节点会替换 base 中未建模字段，不能整体写入")
        XCTAssertEqual(patch["style/font_point"] as? Int, 19)
        XCTAssertNotNil(patch["style/color_scheme"])
    }

    func testModifiedColorSchemeUsesLeafPatchAndPreservesOtherSchemes() throws {
        try """
        preset_color_schemes:
          light:
            name: Light
            back_color: 0xFFFFFF
          dark:
            name: Dark
            back_color: 0x000000
        """.write(to: tempDir.appendingPathComponent("squirrel.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        cm.squirrelConfig.colorSchemes["light"]?.backColor = "0x111111"
        try cm.applyAllConfigChanges(in: tempDir)

        let patch = try readPatch("squirrel.custom.yaml")
        XCTAssertNil(patch["preset_color_schemes"], "配色根节点会替换所有方案，不能整体写入")
        XCTAssertEqual(patch["preset_color_schemes/light/back_color"] as? String, "0x111111")
        XCTAssertNil(patch["preset_color_schemes/dark/back_color"])
    }

    func testPunctuatorUsesSectionLevelPatch() {
        let settings = PunctuatorSettings()
        settings.halfShape = [PunctuatorSettings.PunctEntry(
            key: ".",
            commit: "。",
            candidates: [],
            isPair: false
        )]
        let patch = settings.generatePatch()

        XCTAssertNil(patch["punctuator"], "punctuator 节点会替换 import_preset 等同级字段")
        let half = try? XCTUnwrap(patch["punctuator/half_shape"] as? [String: Any])
        XCTAssertEqual(half?["."] as? String, "。")
    }

    func testMultiDocumentDictionaryPassesGeneratedYAMLValidation() throws {
        try """
        schema:
          schema_id: rime_mint
          name: test
        translator:
          dictionary: mint
        """.write(to: tempDir.appendingPathComponent("rime_mint.schema.yaml"), atomically: true, encoding: .utf8)
        try """
        name: mint
        version: "1"
        import_tables:
          - table_a
        ...
        table_a\ta\t1
        """.write(to: tempDir.appendingPathComponent("mint.dict.yaml"), atomically: true, encoding: .utf8)
        try """
        patch:
          translator/dictionary: mint
        """.write(to: tempDir.appendingPathComponent("rime_mint.custom.yaml"), atomically: true, encoding: .utf8)

        let cm = ConfigManager()
        cm.loadAllConfigs(in: tempDir)
        try cm.applyAllConfigChanges(in: tempDir)
        XCTAssertTrue(try String(contentsOf: tempDir.appendingPathComponent("mint.dict.yaml"), encoding: .utf8)
            .contains("table_a\ta\t1"))
    }
}
