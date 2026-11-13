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
        XCTAssertIdentical(scheme, config.colorSchemes[config.colorSchemeLightName])
    }

    func testEffectiveSchemeDark() {
        let config = SquirrelConfig()
        config.colorSchemeLightName = "light_scheme"
        config.colorSchemeDarkName = "dark_scheme"

        let scheme = config.effectiveScheme(isDark: true)
        XCTAssertNotNil(config.colorSchemeDarkName)
        XCTAssertIdentical(scheme, config.colorSchemes[config.colorSchemeDarkName])
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

    // MARK: - Scheme Override Change Detection

    func testModifiedSchemesDetectStyleOverrideChange() {
        let config = SquirrelConfig()
        let customYAML = """
        patch:
          preset_color_schemes:
            mint_light_blue:
              back_color: 0xF2F2F7
              text_color: 0x3C3C43
              alpha: 0.9
        """
        config.load(baseYAML: "", customYAML: customYAML)

        // 未修改 → 不回写
        XCTAssertTrue(config.modifiedColorSchemesDict().isEmpty)

        // 仅修改方案级 alpha（颜色未动）→ 必须回写，否则修改静默丢失
        config.colorSchemes["mint_light_blue"]?.schemeAlpha = 0.7
        let modified = config.modifiedColorSchemesDict()
        let scheme = modified["mint_light_blue"] as? [String: Any]
        XCTAssertEqual(scheme?["alpha"] as? Double ?? Double((scheme?["alpha"] as? Int) ?? 0), 0.7, accuracy: 0.001)
    }

    // MARK: - Menu Page Size Reset

    func testMenuPageSizeResetToNineRemovesStaleOverride() {
        let config = SquirrelConfig()
        let customYAML = """
        patch:
          menu:
            page_size: 6
        """
        config.load(baseYAML: "", customYAML: customYAML)
        XCTAssertEqual(config.pageSize, 6)

        // 用户把候选数改回 9 → 必须写出 page_size: 9，否则残留的 6 继续生效
        config.pageSize = 9

        let yaml = config.generateYAML()
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let patch = dict["patch"] as? [String: Any],
              let pageSize = patch["menu/page_size"] as? Int else {
            XCTFail("Generated YAML should contain menu/page_size")
            return
        }
        XCTAssertEqual(pageSize, 9)
    }

    func testFlatMenuPageSizeRoundTrip() {
        let config = SquirrelConfig()
        let customYAML = """
        patch:
          menu/page_size: 6
        """
        config.load(baseYAML: "", customYAML: customYAML)
        XCTAssertEqual(config.pageSize, 6, "扁平键 menu/page_size 必须能读回")

        // 基底无 menu 节点 → 生成扁平键，值保持不变
        let yaml = config.generateYAML()
        guard let dict = try? Yams.load(yaml: yaml) as? [String: Any],
              let patch = dict["patch"] as? [String: Any] else {
            XCTFail("Generated YAML should contain patch")
            return
        }
        XCTAssertEqual(patch["menu/page_size"] as? Int, 6)
        XCTAssertNil(patch["menu"])

        // 再加载一次（模拟重启）仍为 6，不被默认值覆盖
        let config2 = SquirrelConfig()
        config2.load(baseYAML: "", customYAML: yaml)
        XCTAssertEqual(config2.pageSize, 6)
    }

    func testLoadResetsPageSizeWhenNewConfigHasNoMenu() {
        // 同一实例二次加载且新目录无任何 menu 配置时，不得残留上一次的值
        let config = SquirrelConfig()
        config.load(baseYAML: "", customYAML: "patch:\n  menu/page_size: 6\n")
        XCTAssertEqual(config.pageSize, 6)

        config.load(baseYAML: "", customYAML: "")
        XCTAssertEqual(config.pageSize, 9, "二次加载无 menu 配置时应复位为默认值")
    }
}
