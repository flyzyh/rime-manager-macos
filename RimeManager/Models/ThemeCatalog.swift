import SwiftUI

/// Normalized palette used by the built-in theme gallery.
/// Every string is already in Squirrel's 0xAABBGGRR order.
struct ThemePalette: Hashable, Sendable {
    var background: String
    var border: String
    var shadow: String
    var preeditText: String
    var highlightedPreeditText: String
    var label: String
    var highlightedLabel: String
    var candidateText: String
    var comment: String
    var highlightedCandidateBackground: String
    var highlightedCandidateText: String
    var highlightedLabelColor: String
    var highlightedComment: String
}

/// A curated theme imported from a public GitHub configuration.
struct PresetColorTheme: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let author: String
    let sourceURL: String
    let license: String
    let isDark: Bool
    let palette: ThemePalette

    var customTheme: PresetColorTheme {
        PresetColorTheme(
            id: id + "_custom",
            displayName: displayName + " (Custom)",
            author: author,
            sourceURL: sourceURL,
            license: license,
            isDark: isDark,
            palette: palette
        )
    }
}

/// WCAG contrast helpers used to flag low-quality combinations before applying.
enum ThemeColor {
    static func contrastRatio(_ foreground: String, on background: String) -> Double? {
        guard let foregroundColor = rgba(foreground), let backgroundColor = rgba(background) else {
            return nil
        }
        let foregroundLuminance = luminance(foregroundColor)
        let backgroundLuminance = luminance(backgroundColor)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func rgba(_ rimeHex: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        var value = rimeHex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("0x") || value.hasPrefix("0X") { value = String(value.dropFirst(2)) }
        guard value.count == 6 || value.count == 8, let raw = UInt64(value, radix: 16) else { return nil }
        let red = Double(raw & 0xFF) / 255
        let green = Double((raw >> 8) & 0xFF) / 255
        let blue = Double((raw >> 16) & 0xFF) / 255
        let alpha = value.count == 8 ? Double((raw >> 24) & 0xFF) / 255 : 1
        return (red, green, blue, alpha)
    }

    private static func luminance(_ color: (red: Double, green: Double, blue: Double, alpha: Double)) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }
}

enum ThemeCatalog {
    static let themes: [PresetColorTheme] = [
        PresetColorTheme(
            id: "liquid_glass_light",
            displayName: "Liquid Glass Light",
            author: "Rime Manager / Squirrel",
            sourceURL: "https://github.com/rime/squirrel/blob/master/sources/SquirrelPanel.swift",
            license: "GPL-3.0 (native effect reference)",
            isDark: false,
            palette: ThemePalette(
                background: "0x59FFFFFF", border: "0x59FFFFFF", shadow: "0x4D000000",
                preeditText: "0x1F1D1D", highlightedPreeditText: "0xFFFFFF",
                label: "0x584E48", highlightedLabel: "0xFFFFFF",
                candidateText: "0x1D1917", comment: "0x7A6157",
                highlightedCandidateBackground: "0xFF840A", highlightedCandidateText: "0xFFFFFF",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0xFFFFFF"
            )
        ),
        PresetColorTheme(
            id: "liquid_glass_dark",
            displayName: "Liquid Glass Dark",
            author: "Rime Manager / Squirrel",
            sourceURL: "https://github.com/rime/squirrel/blob/master/sources/SquirrelPanel.swift",
            license: "GPL-3.0 (native effect reference)",
            isDark: true,
            palette: ThemePalette(
                background: "0x591A1514", border: "0x3DFFFFFF", shadow: "0x66000000",
                preeditText: "0xF8F4F2", highlightedPreeditText: "0xFFFFFF",
                label: "0xC0B0A7", highlightedLabel: "0xFFFFFF",
                candidateText: "0xF0EAE8", comment: "0xC2ABA4",
                highlightedCandidateBackground: "0xFF840A", highlightedCandidateText: "0xFFFFFF",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0xFFFFFF"
            )
        ),
        PresetColorTheme(
            id: "catppuccin_latte",
            displayName: "Catppuccin Latte",
            author: "Catppuccin",
            sourceURL: "https://github.com/catppuccin/squirrel/tree/main/theme",
            license: "MIT",
            isDark: false,
            palette: ThemePalette(
                background: "0xE8E0DC", border: "0xEFE9E6", shadow: "0x20000000",
                preeditText: "0x775F5C", highlightedPreeditText: "0xBEB0AC",
                label: "0x856F6C", highlightedLabel: "0xDAD0CC",
                candidateText: "0x694F4C", comment: "0xBEB0AC",
                highlightedCandidateBackground: "0xEF3988", highlightedCandidateText: "0xF5F1EF",
                highlightedLabelColor: "0xDAD0CC", highlightedComment: "0xDAD0CC"
            )
        ),
        PresetColorTheme(
            id: "catppuccin_frappe",
            displayName: "Catppuccin Frappé",
            author: "Catppuccin",
            sourceURL: "https://github.com/catppuccin/squirrel/tree/main/theme",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x342623", border: "0x3C2C29", shadow: "0x40232A34",
                preeditText: "0xE2BFB5", highlightedPreeditText: "0x806862",
                label: "0xCEADA5", highlightedLabel: "0x594541",
                candidateText: "0xF5D0C6", comment: "0x806862",
                highlightedCandidateBackground: "0xE69ECA", highlightedCandidateText: "0x463430",
                highlightedLabelColor: "0x594541", highlightedComment: "0x594541"
            )
        ),
        PresetColorTheme(
            id: "catppuccin_macchiato",
            displayName: "Catppuccin Macchiato",
            author: "Catppuccin",
            sourceURL: "https://github.com/catppuccin/squirrel/tree/main/theme",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x261918", border: "0x30201E", shadow: "0x40181A26",
                preeditText: "0xE0C0B8", highlightedPreeditText: "0x70B558",
                label: "0xCBADA5", highlightedLabel: "0x4F3A36",
                candidateText: "0xF5D3CA", comment: "0x70B558",
                highlightedCandidateBackground: "0xF6A0C6", highlightedCandidateText: "0x3A2724",
                highlightedLabelColor: "0x4F3A36", highlightedComment: "0x4F3A36"
            )
        ),
        PresetColorTheme(
            id: "catppuccin_mocha",
            displayName: "Catppuccin Mocha",
            author: "Catppuccin",
            sourceURL: "https://github.com/catppuccin/squirrel/tree/main/theme",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x1B1111", border: "0x251818", shadow: "0x40111B1E",
                preeditText: "0xDEC2BA", highlightedPreeditText: "0x705B58",
                label: "0xC8ADA6", highlightedLabel: "0x443231",
                candidateText: "0xF4D6CD", comment: "0x705B58",
                highlightedCandidateBackground: "0xF7A6CB", highlightedCandidateText: "0x2E1E1E",
                highlightedLabelColor: "0x443231", highlightedComment: "0x443231"
            )
        ),
        PresetColorTheme(
            id: "dracula_dark",
            displayName: "Dracula Dark",
            author: "Dracula Theme",
            sourceURL: "https://github.com/dracula/rime/blob/master/squirrel.custom.yaml",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x362A28", border: "0x362A28", shadow: "0x40000000",
                preeditText: "0x6CB8FF", highlightedPreeditText: "0x5A4744",
                label: "0xA46272", highlightedLabel: "0xFAFAFA",
                candidateText: "0xF993BD", comment: "0xFDE98B",
                highlightedCandidateBackground: "0xC679FF", highlightedCandidateText: "0x201A28",
                highlightedLabelColor: "0xFAFAFA", highlightedComment: "0x5A4744"
            )
        ),
        PresetColorTheme(
            id: "dracula_light",
            displayName: "Dracula Light",
            author: "Dracula Theme",
            sourceURL: "https://github.com/dracula/rime/blob/master/squirrel.custom.yaml",
            license: "MIT",
            isDark: false,
            palette: ThemePalette(
                background: "0xF2F8F8", border: "0xF2F8F8", shadow: "0x20000000",
                preeditText: "0x362A28", highlightedPreeditText: "0x362A28",
                label: "0xA46272", highlightedLabel: "0xF8F8F2",
                candidateText: "0x362A28", comment: "0x5A4744",
                highlightedCandidateBackground: "0xC679FF", highlightedCandidateText: "0x201A28",
                highlightedLabelColor: "0xF8F8F2", highlightedComment: "0xF8F8F2"
            )
        ),
        PresetColorTheme(
            id: "rose_pine",
            displayName: "Rosé Pine",
            author: "0xffan",
            sourceURL: "https://github.com/0xffan/rose-pine-rime/blob/main/squirrel/rose_pine_color_schemes.yaml",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x2E1D1F", border: "0x241719", shadow: "0x301F1D2E",
                preeditText: "0x866A6E", highlightedPreeditText: "0xD8F4DEE0",
                label: "0xD8866A6E", highlightedLabel: "0xB2F4DEE0",
                candidateText: "0xDAF4DEE0", comment: "0x866A6E",
                highlightedCandidateBackground: "0xD8926FEB", highlightedCandidateText: "0x241719",
                highlightedLabelColor: "0xB2F4DEE0", highlightedComment: "0x866A6E"
            )
        ),
        PresetColorTheme(
            id: "rose_pine_moon",
            displayName: "Rosé Pine Moon",
            author: "0xffan",
            sourceURL: "https://github.com/0xffan/rose-pine-rime/blob/main/squirrel/rose_pine_color_schemes.yaml",
            license: "MIT",
            isDark: true,
            palette: ThemePalette(
                background: "0x3F272A", border: "0x362123", shadow: "0x302A273F",
                preeditText: "0x866A6E", highlightedPreeditText: "0xD8F4DEE0",
                label: "0xD8866A6E", highlightedLabel: "0xB2F4DEE0",
                candidateText: "0xDAF4DEE0", comment: "0x866A6E",
                highlightedCandidateBackground: "0xD8926FEB", highlightedCandidateText: "0x241719",
                highlightedLabelColor: "0xB2F4DEE0", highlightedComment: "0x866A6E"
            )
        ),
        PresetColorTheme(
            id: "rose_pine_dawn",
            displayName: "Rosé Pine Dawn",
            author: "0xffan",
            sourceURL: "https://github.com/0xffan/rose-pine-rime/blob/main/squirrel/rose_pine_color_schemes.yaml",
            license: "MIT",
            isDark: false,
            palette: ThemePalette(
                background: "0xF3FAFF", border: "0xCDCACE", shadow: "0x203FFAF3",
                preeditText: "0xD8795257", highlightedPreeditText: "0x795257",
                label: "0xD8A59398", highlightedLabel: "0xD9A59398",
                candidateText: "0xDA795257", comment: "0xD8A59398",
                highlightedCandidateBackground: "0xE1E9F2", highlightedCandidateText: "0xD87A63B4",
                highlightedLabelColor: "0xD9A59398", highlightedComment: "0xDAA59398"
            )
        ),
        PresetColorTheme(
            id: "macos_light",
            displayName: "macOS Light",
            author: "lonr",
            sourceURL: "https://github.com/lonr/rime-squirrel-macos-color-scheme/blob/master/squirrel.custom.yaml",
            license: "GPL-3.0",
            isDark: false,
            palette: ThemePalette(
                background: "0xF1F2F2", border: "0xF1F2F2", shadow: "0x20000000",
                preeditText: "0x808080", highlightedPreeditText: "0xFFFFFF",
                label: "0x808080", highlightedLabel: "0xFFFFFF",
                candidateText: "0x494949", comment: "0x494949",
                highlightedCandidateBackground: "0xD85A00", highlightedCandidateText: "0xFFFFFF",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0xFFFFFF"
            )
        ),
        PresetColorTheme(
            id: "macos_dark",
            displayName: "macOS Dark",
            author: "lonr",
            sourceURL: "https://github.com/lonr/rime-squirrel-macos-color-scheme/blob/master/squirrel.custom.yaml",
            license: "GPL-3.0",
            isDark: true,
            palette: ThemePalette(
                background: "0x393939", border: "0x393939", shadow: "0x50000000",
                preeditText: "0x7B7B7B", highlightedPreeditText: "0xFFFFFF",
                label: "0x7B7B7B", highlightedLabel: "0xFFFFFF",
                candidateText: "0xEBEBEB", comment: "0xEBEBEB",
                highlightedCandidateBackground: "0xD15900", highlightedCandidateText: "0xFFFFFF",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0xFFFFFF"
            )
        ),
        PresetColorTheme(
            id: "wechat_light",
            displayName: "WeChat Keyboard Light",
            author: "小码哥 / lewangdev",
            sourceURL: "https://gist.github.com/lewangdev/f8ebbba24f464e915fb7d36857fcbbe5",
            license: "Source license not declared",
            isDark: false,
            palette: ThemePalette(
                background: "0xFFFFFF", border: "0xFFFFFF", shadow: "0x18000000",
                preeditText: "0x424242", highlightedPreeditText: "0x999999",
                label: "0x999999", highlightedLabel: "0xFFFFFF",
                candidateText: "0x3C3C3C", comment: "0x999999",
                highlightedCandidateBackground: "0x79AF22", highlightedCandidateText: "0x08120C",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0x999999"
            )
        ),
        PresetColorTheme(
            id: "wechat_dark",
            displayName: "WeChat Keyboard Dark",
            author: "小码哥 / lewangdev",
            sourceURL: "https://gist.github.com/lewangdev/f8ebbba24f464e915fb7d36857fcbbe5",
            license: "Source license not declared",
            isDark: true,
            palette: ThemePalette(
                background: "0x151515", border: "0x292929", shadow: "0x60000000",
                preeditText: "0xBBBBBB", highlightedPreeditText: "0x999999",
                label: "0x999999", highlightedLabel: "0xFFFFFF",
                candidateText: "0xBBBBBB", comment: "0x999999",
                highlightedCandidateBackground: "0x79AF22", highlightedCandidateText: "0x08120C",
                highlightedLabelColor: "0xFFFFFF", highlightedComment: "0xFFFFFF"
            )
        ),
    ]
}

extension ThemePalette {
    func apply(to scheme: EditableColorScheme) {
        scheme.backColor = background
        scheme.borderColor = border
        scheme.shadowColor = shadow
        scheme.textColor = preeditText
        scheme.hilitedTextColor = highlightedPreeditText
        scheme.labelColor = label
        scheme.candidateTextColor = candidateText
        scheme.commentTextColor = comment
        scheme.hilitedCandidateBackColor = highlightedCandidateBackground
        scheme.hilitedCandidateTextColor = highlightedCandidateText
        scheme.hilitedCandidateLabelColor = highlightedLabelColor
        scheme.hilitedCommentTextColor = highlightedComment
    }
}

extension SquirrelConfig {
    /// Installs one curated theme using a field-level scheme and selects its natural slot.
    /// Other schemes, including user-created schemes, remain untouched.
    func apply(theme: PresetColorTheme) {
        let scheme = colorSchemes[theme.id] ?? EditableColorScheme(name: theme.id)
        theme.palette.apply(to: scheme)
        if theme.isLiquidGlass {
            scheme.schemeAlpha = nil
        }
        colorSchemes[theme.id] = scheme

        if theme.isDark {
            colorSchemeDarkName = theme.id
        } else {
            colorSchemeLightName = theme.id
        }

        if theme.isLiquidGlass {
            // Squirrel 26+ uses NSGlassEffectView(.clear) when translucency is enabled.
            // style/alpha directly controls the candidate window's overall transparency.
            translucency = true
            blurEnabled = true
            alpha = 0.45
        }
    }

    /// Copies a curated theme under a new id, so users can iterate without losing the original.
    func applyCopy(of theme: PresetColorTheme) {
        apply(theme: theme.customTheme)
    }
}

extension PresetColorTheme {
    var isLiquidGlass: Bool {
        id.hasPrefix("liquid_glass_")
    }
}
