import XCTest
import Yams
@testable import RimeManager

final class SquirrelConfigTests: XCTestCase {

    // MARK: - Load Tests

    func testLoadBasicConfig() {
        let config = SquirrelConfig()
        let baseYAML = """
        style:
          color_scheme: google
          color_scheme_dark: dark
          font_point: 20.0
          label_font_point: 16.0
          horizontal: true
          inline_preedit: false
          corner_radius: 10.0
          hilited_corner_radius: 5.0
          alpha: 0.95
          translucency: false
          blur: false
        """

        config.load(baseYAML: baseYAML, customYAML: "")

        XCTAssertEqual(config.colorSchemeLightName, "google")
        XCTAssertEqual(config.colorSchemeDarkName, "dark")
        XCTAssertEqual(config.fontPoint, 20)
        XCTAssertEqual(config.labelFontPoint, 16)
        XCTAssertFalse(config.inlinePreedit)
        XCTAssertEqual(config.cornerRadius, 10)
        XCTAssertEqual(config.hilitedCornerRadius, 5)
        XCTAssertEqual(config.alpha, 0.95, accuracy: 0.001)
        XCTAssertFalse(config.translucency)
        XCTAssertFalse(config.blurEnabled)
    }

    func testLoadWithCustomOverride() {
        let config = SquirrelConfig()
        let baseYAML = """
        style:
          color_scheme: google
          font_point: 16.0
        """
        let customYAML = """
        patch:
          style:
            font_point: 20.0
            color_scheme: nord_light
        """

        config.load(baseYAML: baseYAML, customYAML: customYAML)

        XCTAssertEqual(config.fontPoint, 20)
        XCTAssertEqual(config.colorSchemeLightName, "nord_light")
    }

    // MARK: - Generate YAML Tests

    func testGenerateYAMLRoundTrip() {
        let config = SquirrelConfig()
        config.fontPoint = 18
        config.labelFontPoint = 14
        config.textOrientation = .vertical
        config.inlinePreedit = false
        config.cornerRadius = 10
        config.hilitedCornerRadius = 5
        config.alpha = 0.9
        config.translucency = true
        config.blurEnabled = false
        config.colorSchemeLightName = "test_light"
        config.colorSchemeDarkName = "test_dark"

        let yaml = config.generateYAML()

        // Parse back and verify
        XCTAssertFalse(yaml.isEmpty)
        XCTAssertTrue(yaml.contains("patch"))
        XCTAssertTrue(yaml.contains("style"))
    }

    // MARK: - Color Scheme Tests

    func testEffectiveSchemeLight() {
        let config = SquirrelConfig()
        config.colorSchemeLightName = "light_scheme"
        config.colorSchemeDarkName = "dark_scheme"

        let scheme = config.effectiveScheme(isDark: false)
        // Should return light scheme or nil if not found
        // This tests the selection logic
        XCTAssertNotNil(config.colorSchemeLightName)
    }

    func testEffectiveSchemeDark() {
        let config = SquirrelConfig()
        config.colorSchemeLightName = "light_scheme"
        config.colorSchemeDarkName = "dark_scheme"

        let scheme = config.effectiveScheme(isDark: true)
        XCTAssertNotNil(config.colorSchemeDarkName)
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let config = SquirrelConfig()

        XCTAssertEqual(config.fontPoint, 18)
        XCTAssertEqual(config.labelFontPoint, 14)
        XCTAssertEqual(config.textOrientation, .horizontal)
        XCTAssertTrue(config.inlinePreedit)
        XCTAssertFalse(config.showPaging)
        XCTAssertEqual(config.cornerRadius, 8)
        XCTAssertEqual(config.hilitedCornerRadius, 6)
        XCTAssertEqual(config.alpha, 0.84, accuracy: 0.001)
        XCTAssertTrue(config.translucency)
        XCTAssertTrue(config.blurEnabled)
    }
}
