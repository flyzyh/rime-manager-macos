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

    // MARK: - Generate Patch Tests

    func testGenerateSchemaPatch() {
        let settings = InputSettings()
        settings.asciiMode = true
        settings.emojiSuggestion = false
        settings.candidateCount = 6

        let patch = settings.generateSchemaPatch()

        XCTAssertFalse(patch.isEmpty)
        XCTAssertTrue(patch.contains("patch"))
        XCTAssertTrue(patch.contains("switches"))
        XCTAssertTrue(patch.contains("menu"))
    }

    func testGenerateDefaultCustomPatch() {
        let settings = InputSettings()
        settings.candidateCount = 8
        settings.capsLockSwitch = false
        settings.shiftSwitch = "clear"

        let patch = settings.generateDefaultCustomPatch()

        XCTAssertFalse(patch.isEmpty)
        XCTAssertTrue(patch.contains("patch"))
        XCTAssertTrue(patch.contains("ascii_composer"))
        XCTAssertTrue(patch.contains("menu"))
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
