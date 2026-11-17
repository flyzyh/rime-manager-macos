import XCTest
import Yams
@testable import RimeManager

final class ThemeCatalogTests: XCTestCase {
    private let catalog = ThemeCatalog.themes

    func testCatalogContainsCuratedGitHubThemes() {
        XCTAssertEqual(catalog.count, 15)
        XCTAssertEqual(Set(catalog.map(\.id)).count, 15)

        let expected = [
            "catppuccin_latte", "catppuccin_frappe", "catppuccin_macchiato",
            "catppuccin_mocha", "dracula_dark", "dracula_light",
            "rose_pine", "rose_pine_moon", "rose_pine_dawn",
            "macos_light", "macos_dark", "wechat_light", "wechat_dark",
            "liquid_glass_light", "liquid_glass_dark",
        ]
        XCTAssertEqual(Set(catalog.map(\.id)), Set(expected))
        XCTAssertEqual(catalog.filter { !$0.isDark }.count, 6)
        XCTAssertEqual(catalog.filter(\.isDark).count, 9)
    }

    func testCatalogThemesHaveProvenanceAndColors() {
        for theme in catalog {
            XCTAssertFalse(theme.displayName.isEmpty)
            XCTAssertFalse(theme.author.isEmpty)
            XCTAssertFalse(theme.license.isEmpty)
            XCTAssertNotNil(URL(string: theme.sourceURL))
            XCTAssertTrue(theme.sourceURL.hasPrefix("https://github.com/") || theme.sourceURL.hasPrefix("https://gist.github.com/"))
            for color in [
                theme.palette.background,
                theme.palette.candidateText,
                theme.palette.highlightedCandidateBackground,
                theme.palette.highlightedCandidateText,
            ] {
                XCTAssertNotNil(ColorScheme.parseHexColor(color), "\(theme.id): \(color)")
            }
        }
    }

    func testCoreThemePairsRemainReadable() throws {
        for theme in catalog {
            let candidateRatio = try XCTUnwrap(
                ThemeColor.contrastRatio(theme.palette.candidateText, on: theme.palette.background)
            )
            let highlightedRatio = try XCTUnwrap(
                ThemeColor.contrastRatio(
                    theme.palette.highlightedCandidateText,
                    on: theme.palette.highlightedCandidateBackground
                )
            )
            XCTAssertGreaterThanOrEqual(candidateRatio, 3.0, theme.id)
            XCTAssertGreaterThanOrEqual(highlightedRatio, 3.0, theme.id)
        }
    }

    func testLiquidGlassThemesEnableNativeSquirrelGlass() throws {
        for id in ["liquid_glass_light", "liquid_glass_dark"] {
            let theme = try XCTUnwrap(catalog.first { $0.id == id })
            XCTAssertTrue(theme.isLiquidGlass)
            XCTAssertNotNil(ColorScheme.parseHexColor(theme.palette.background))

            let config = SquirrelConfig()
            config.translucency = false
            config.blurEnabled = false
            config.alpha = 0.90

            config.apply(theme: theme)

            XCTAssertTrue(config.translucency)
            XCTAssertTrue(config.blurEnabled)
            XCTAssertEqual(config.alpha, 0.45, accuracy: 0.001)
            if theme.isDark {
                XCTAssertEqual(config.colorSchemeDarkName, theme.id)
            } else {
                XCTAssertEqual(config.colorSchemeLightName, theme.id)
            }
        }
    }

    func testLiquidGlassThemeUsesFieldLevelStylePatches() throws {
        let custom = """
        patch:
          style:
            font_face: UserFont
            user_style_value: keep-me
        """
        let config = SquirrelConfig()
        config.load(baseYAML: "", customYAML: custom)
        let theme = try XCTUnwrap(catalog.first { $0.id == "liquid_glass_dark" })

        config.apply(theme: theme)
        let yaml = config.generateYAML()
        let generated = try XCTUnwrap(Yams.load(yaml: yaml) as? [String: Any])
        let patch = try XCTUnwrap(generated["patch"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(patch["style/font_face"] as? String), "UserFont")
        XCTAssertEqual(try XCTUnwrap(patch["style/user_style_value"] as? String), "keep-me")
        XCTAssertEqual(try XCTUnwrap(patch["style/translucency"] as? Bool), true)
        XCTAssertEqual(try XCTUnwrap(patch["style/alpha"] as? Double), 0.45)

        XCTAssertTrue(yaml.contains("preset_color_schemes/liquid_glass_dark/back_color"))
        XCTAssertFalse(yaml.contains("style:\n"))
        XCTAssertFalse(yaml.contains("preset_color_schemes:\n"))
    }

    func testApplyThemeAddsFieldLevelSchemeAndSelectsCorrectSlot() throws {
        let config = SquirrelConfig()
        let theme = try XCTUnwrap(catalog.first { $0.id == "catppuccin_mocha" })

        config.apply(theme: theme)

        XCTAssertEqual(config.colorSchemeDarkName, "catppuccin_mocha")
        XCTAssertEqual(config.colorSchemeLightName, config.colorSchemeLightName)
        let scheme = try XCTUnwrap(config.colorSchemes["catppuccin_mocha"])
        XCTAssertEqual(scheme.backColor, theme.palette.background)
        XCTAssertEqual(scheme.candidateTextColor, theme.palette.candidateText)
        XCTAssertEqual(scheme.hilitedCandidateBackColor, theme.palette.highlightedCandidateBackground)
        XCTAssertEqual(scheme.hilitedCandidateTextColor, theme.palette.highlightedCandidateText)

        let yaml = config.generateYAML()
        XCTAssertTrue(yaml.contains("preset_color_schemes/catppuccin_mocha/back_color"))
        XCTAssertTrue(yaml.contains("style/color_scheme_dark"))
        XCTAssertFalse(yaml.contains("preset_color_schemes:\n"))
    }

    func testApplyThemeDoesNotReplaceUnrelatedSchemes() throws {
        let base = """
        style:
          color_scheme: user_light
          color_scheme_dark: user_dark
        preset_color_schemes:
          user_light:
            back_color: 0xFFFFFF
            candidate_text_color: 0x111111
          user_dark:
            back_color: 0x111111
            candidate_text_color: 0xEEEEEE
        """
        let config = SquirrelConfig()
        config.load(baseYAML: base, customYAML: "")
        let userDark = try XCTUnwrap(config.colorSchemes["user_dark"])
        let originalBack = userDark.backColor
        let theme = try XCTUnwrap(catalog.first { $0.id == "macos_light" })

        config.apply(theme: theme)

        XCTAssertEqual(config.colorSchemeLightName, "macos_light")
        XCTAssertEqual(config.colorSchemeDarkName, "user_dark")
        XCTAssertEqual(try XCTUnwrap(config.colorSchemes["user_dark"]).backColor, originalBack)
        XCTAssertEqual(config.colorSchemes.count, 3)
    }

    func testApplyThemePreservesUnknownFieldsWhenUpdatingExistingScheme() throws {
        let custom = """
        patch:
          preset_color_schemes:
            catppuccin_mocha:
              back_color: 0x123456
              color_space: display_p3
              surrounding_extra_expansion: 0
        """
        let config = SquirrelConfig()
        config.load(baseYAML: "", customYAML: custom)
        let theme = try XCTUnwrap(catalog.first { $0.id == "catppuccin_mocha" })

        config.apply(theme: theme)

        let scheme = try XCTUnwrap(config.colorSchemes["catppuccin_mocha"])
        XCTAssertEqual(scheme.backColor, theme.palette.background)
        XCTAssertTrue(scheme.toDict().keys.contains("color_space"))
        XCTAssertTrue(scheme.toDict().keys.contains("surrounding_extra_expansion"))
    }
}
