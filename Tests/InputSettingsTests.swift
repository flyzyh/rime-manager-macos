import XCTest
import Yams
@testable import RimeManager

final class InputSettingsTests: XCTestCase {

    // MARK: - Schema Parsing Tests

    func testLoadSchemaBasic() {
        let settings = InputSettings()
        let schemaYAML = """
        schema:
          schema_id: rime_mint
          name: 薄荷拼音
          version: "24.11"

        switches:
          - name: ascii_mode
            reset: 0
            states: [中文, English]
          - name: emoji_suggestion
            reset: 1
            states: ["😣", "😁"]
          - name: full_shape
            reset: 0
            states: [半角, 全角]

        menu:
          page_size: 7
        """

        settings.load(schemaYAML: schemaYAML, defaultCustomYAML: "")

        XCTAssertEqual(settings.schemaID, "rime_mint")
        XCTAssertEqual(settings.schemaName, "薄荷拼音")
        XCTAssertEqual(settings.schemaVersion, "24.11")
        XCTAssertFalse(settings.asciiMode)
        XCTAssertTrue(settings.emojiSuggestion)
        XCTAssertFalse(settings.fullShape)
        XCTAssertEqual(settings.pageSize, 7)
        XCTAssertEqual(settings.candidateCount, 7)
    }

    func testLoadWithDefaultCustom() {
        let settings = InputSettings()
        let schemaYAML = """
        schema:
          schema_id: test
          name: Test
        menu:
          page_size: 5
        """
        let defaultCustomYAML = """
        patch:
          menu:
            page_size: 9
          ascii_composer:
            good_old_caps_lock: false
            switch_key:
              Shift_L: commit_text
        """

        settings.load(schemaYAML: schemaYAML, defaultCustomYAML: defaultCustomYAML)

        XCTAssertEqual(settings.candidateCount, 9)
        XCTAssertFalse(settings.capsLockSwitch)
        XCTAssertEqual(settings.shiftSwitch, "commit_text")
    }

    // MARK: - Switches Patch Tests

    func testSwitchesPatchEmptyWhenNoSchemaSwitches() {
        let settings = InputSettings()
        settings.asciiMode = true

        XCTAssertTrue(settings.switchesPatchDict().isEmpty)
    }

    func testSwitchesPatchEmptyWhenUnchanged() {
        let settings = InputSettings()
        settings.load(schemaYAML: testSchemaYAML, defaultCustomYAML: "")

        XCTAssertTrue(settings.switchesPatchDict().isEmpty)
    }

    func testSwitchesPatchUpdatesResetAndPreservesUnmanaged() {
        let settings = InputSettings()
        settings.load(schemaYAML: testSchemaYAML, defaultCustomYAML: "")

        // 修改受管开关
        settings.emojiSuggestion = false
        settings.asciiMode = true

        let patch = settings.switchesPatchDict()
        XCTAssertEqual(patch["switches/@1/reset"] as? Int, 0)
        XCTAssertEqual(patch["switches/@0/reset"] as? Int, 1)
        XCTAssertEqual(patch.count, 2, "item reset patch 不需要重写未受管条目")
    }

    // MARK: - Default Custom Patch Tests

    func testGenerateSchemaPatch() {
        let settings = InputSettings()
        settings.candidateCount = 6

        let patch = settings.generateDefaultCustomPatch()

        XCTAssertFalse(patch.isEmpty)
        XCTAssertTrue(patch.contains("patch"))
        XCTAssertTrue(patch.contains("ascii_composer"))
        XCTAssertTrue(patch.contains("menu"))
    }

    func testReturnKeyFixNotDuplicatedWhenAlreadyPresent() {
        let settings = InputSettings()
        let defaultCustomYAML = """
        patch:
          key_binder/bindings/+:
            - {when: composing, accept: Return, send: Return}
            - {when: composing, accept: KP_Enter, send: Return}
        """
        settings.load(schemaYAML: testSchemaYAML, defaultCustomYAML: defaultCustomYAML)

        // 基底已包含追加键时不再重复写入
        XCTAssertNil(settings.defaultCustomPatchDict()["key_binder/bindings/+"])
    }

    func testReturnKeyFixSkippedWhenFullBindingsPresent() {
        let settings = InputSettings()
        let defaultCustomYAML = """
        patch:
          key_binder/bindings:
            - {when: composing, accept: Return, send: Return}
        """
        settings.load(schemaYAML: testSchemaYAML, defaultCustomYAML: defaultCustomYAML)

        // 基底为全量键形态（编辑绑定后的产物）时同样不得补写追加键，
        // 否则同一 patch 内 "key_binder/bindings" 与 "key_binder/bindings/+" 冲突
        XCTAssertNil(settings.defaultCustomPatchDict()["key_binder/bindings/+"])
    }

    var testSchemaYAML: String {
        """
        schema:
          schema_id: test
          name: Test

        switches:
          - name: ascii_mode
            reset: 0
            states: [中文, English]
          - name: emoji_suggestion
            reset: 1
            states: ["😣", "😁"]
          - name: unmanaged_switch
            reset: 0
            states: [off, on]

        menu:
          page_size: 7
        """
    }

    // MARK: - Switch Parsing

    func testAllSwitchesParsed() {
        let settings = InputSettings()
        let schemaYAML = """
        schema:
          schema_id: test
        switches:
          - name: ascii_mode
            reset: 1
          - name: emoji_suggestion
            reset: 0
          - name: full_shape
            reset: 1
          - name: tone_display
            reset: 1
          - name: transcription
            reset: 1
          - name: ascii_punct
            reset: 1
        """

        settings.load(schemaYAML: schemaYAML, defaultCustomYAML: "")

        XCTAssertTrue(settings.asciiMode)
        XCTAssertFalse(settings.emojiSuggestion)
        XCTAssertTrue(settings.fullShape)
        XCTAssertTrue(settings.toneDisplay)
        XCTAssertTrue(settings.transcription)
        XCTAssertTrue(settings.asciiPunct)
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let settings = InputSettings()

        XCTAssertFalse(settings.asciiMode)
        XCTAssertTrue(settings.emojiSuggestion)
        XCTAssertFalse(settings.fullShape)
        XCTAssertFalse(settings.toneDisplay)
        XCTAssertFalse(settings.transcription)
        XCTAssertFalse(settings.asciiPunct)
        XCTAssertEqual(settings.pageSize, 9)
        XCTAssertEqual(settings.candidateCount, 9)
        XCTAssertTrue(settings.capsLockSwitch)
        XCTAssertEqual(settings.shiftSwitch, "commit_code")
    }
}
