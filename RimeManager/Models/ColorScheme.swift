import SwiftUI

/// Parsed color scheme from squirrel.custom.yaml or squirrel.yaml.
struct ColorScheme: Identifiable {
    let id = UUID()
    var name: String
    var isDark: Bool = false

    // Colors
    var backColor: Color?
    var hilitedCandidateBackColor: Color?
    var labelColor: Color?
    var hilitedCandidateLabelColor: Color?
    var candidateTextColor: Color?
    var hilitedCandidateTextColor: Color?
    var commentTextColor: Color?
    var hilitedCommentTextColor: Color?
    var textColor: Color?
    var hilitedTextColor: Color?
    var borderColor: Color?
    var shadowColor: Color?

    // Layout
    var alpha: Double?
    var cornerRadius: Double?
    var hilitedCornerRadius: Double?
    var borderHeight: Double?
    var borderWidth: Double?
    var lineSpacing: Double?
    var spacing: Double?
    var shadowSize: Double?
    var fontFace: String?
    var fontPoint: Double?
    var labelFontFace: String?
    var labelFontPoint: Double?
    var commentFontFace: String?
    var commentFontPoint: Double?

    // Translucency
    var translucency: Bool?
    var blur: Bool?

    /// Parse a Rime hex color string.
    /// Squirrel on macOS uses 0xBBGGRR / 0xAABBGGRR (blue in high bits, red in low).
    static func parseHexColor(_ hex: String) -> Color? {
        var cleaned = hex.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("0x") || cleaned.hasPrefix("0X") {
            cleaned = String(cleaned.dropFirst(2))
        }
        let length = cleaned.count
        guard length == 6 || length == 8 else { return nil }

        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }

        // BBGGRR: R=low byte, G=middle, B=high
        let r = Double(int & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double((int >> 16) & 0xFF) / 255.0

        if length == 6 {
            return Color(red: r, green: g, blue: b)
        }
        let a = Double((int >> 24) & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b).opacity(a)
    }

    /// Convert SwiftUI Color to Rime hex (0xAABBGGRR).
    static func colorToRimeHex(_ color: Color) -> String {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.sRGB) ?? ns.usingColorSpace(.genericRGB) else {
            return "0xFF000000"
        }
        let r = max(0, min(255, Int(rgb.redComponent * 255)))
        let g = max(0, min(255, Int(rgb.greenComponent * 255)))
        let b = max(0, min(255, Int(rgb.blueComponent * 255)))
        let a = max(0, min(255, Int(rgb.alphaComponent * 255)))
        if a == 255 {
            return String(format: "0x%02X%02X%02X", b, g, r)
        }
        return String(format: "0x%02X%02X%02X%02X", a, b, g, r)
    }
}

extension ColorScheme {
    /// Sample preview text for rendering.
    static let previewText = "中文 English 123"
    static let previewCandidate = "1. 中文 2. 输入 3. 方案 4. 预览"
}
