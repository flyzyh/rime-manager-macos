import SwiftUI
import AppKit

// MARK: - Token types

enum YAMLTokenType {
    case comment      // # comment
    case key          // key:
    case string       // "string" or 'string'
    case number       // 123, 3.14
    case boolean      // true, false, yes, no
    case null         // null, ~
    case anchor       // &anchor
    case alias        // *alias
    case tag          // !tag
    case blockScalar  // | or > literal/folded
    case listMarker   // - item
    case directive    // %YAML, %TAG
    case documentSep  // --- or ...
    case plain        // plain scalar values
}

// MARK: - Highlight rule

struct HighlightRule {
    let pattern: String
    let type: YAMLTokenType
}

// MARK: - Syntax Highlighter

final class YAMLSyntaxHighlighter {
    private let rules: [HighlightRule] = [
        // Comments (must be first to override other patterns)
        HighlightRule(pattern: "^\\s*#.*$", type: .comment),
        HighlightRule(pattern: "\\s#.*$", type: .comment),

        // Document separators
        HighlightRule(pattern: "^---\\s*$", type: .documentSep),
        HighlightRule(pattern: "^\\.\\.\\.\\s*$", type: .documentSep),

        // Directives
        HighlightRule(pattern: "^%[A-Za-z]+", type: .directive),

        // Anchors and aliases
        HighlightRule(pattern: "&[a-zA-Z_][a-zA-Z0-9_]*", type: .anchor),
        HighlightRule(pattern: "\\*[a-zA-Z_][a-zA-Z0-9_]*", type: .alias),

        // Tags
        HighlightRule(pattern: "![a-zA-Z_][a-zA-Z0-9_]*", type: .tag),

        // Double-quoted strings
        HighlightRule(pattern: "\"[^\"]*\"", type: .string),

        // Single-quoted strings
        HighlightRule(pattern: "'[^']*'", type: .string),

        // Booleans
        HighlightRule(pattern: "\\b(true|false|yes|no|on|off)\\b", type: .boolean),

        // Null
        HighlightRule(pattern: "\\b(null|~)\\b", type: .null),

        // Numbers
        HighlightRule(pattern: "\\b[0-9]+\\.?[0-9]*\\b", type: .number),

        // List markers
        HighlightRule(pattern: "^\\s*-\\s", type: .listMarker),

        // Keys (line with colon after non-quoted text)
        HighlightRule(pattern: "^\\s*[a-zA-Z_][a-zA-Z0-9_]*\\s*:", type: .key),
    ]

    /// Color definitions for light and dark mode.
    let lightColors: [YAMLTokenType: NSColor] = [
        .comment:     NSColor(red: 0.35, green: 0.45, blue: 0.35, alpha: 1),  // green-gray
        .key:         NSColor(red: 0.06, green: 0.35, blue: 0.70, alpha: 1),  // blue
        .string:      NSColor(red: 0.75, green: 0.20, blue: 0.10, alpha: 1),  // red
        .number:      NSColor(red: 0.10, green: 0.25, blue: 0.55, alpha: 1),  // dark blue
        .boolean:     NSColor(red: 0.55, green: 0.20, blue: 0.55, alpha: 1),  // purple
        .null:        NSColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),  // gray
        .anchor:      NSColor(red: 0.80, green: 0.55, blue: 0.05, alpha: 1),  // orange
        .alias:       NSColor(red: 0.80, green: 0.55, blue: 0.05, alpha: 1),  // orange
        .tag:         NSColor(red: 0.25, green: 0.55, blue: 0.55, alpha: 1),  // teal
        .blockScalar: NSColor(red: 0.06, green: 0.35, blue: 0.70, alpha: 1),  // blue
        .listMarker:  NSColor(red: 0.06, green: 0.35, blue: 0.70, alpha: 1),  // blue
        .directive:   NSColor(red: 0.45, green: 0.25, blue: 0.55, alpha: 1),  // purple
        .documentSep: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1),  // gray
        .plain:       NSColor.labelColor,
    ]

    let darkColors: [YAMLTokenType: NSColor] = [
        .comment:     NSColor(red: 0.43, green: 0.55, blue: 0.43, alpha: 1),
        .key:         NSColor(red: 0.40, green: 0.70, blue: 0.95, alpha: 1),
        .string:      NSColor(red: 0.95, green: 0.50, blue: 0.40, alpha: 1),
        .number:      NSColor(red: 0.65, green: 0.75, blue: 0.90, alpha: 1),
        .boolean:     NSColor(red: 0.80, green: 0.55, blue: 0.80, alpha: 1),
        .null:        NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1),
        .anchor:      NSColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1),
        .alias:       NSColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1),
        .tag:         NSColor(red: 0.45, green: 0.75, blue: 0.75, alpha: 1),
        .blockScalar: NSColor(red: 0.40, green: 0.70, blue: 0.95, alpha: 1),
        .listMarker:  NSColor(red: 0.40, green: 0.70, blue: 0.95, alpha: 1),
        .directive:   NSColor(red: 0.70, green: 0.50, blue: 0.75, alpha: 1),
        .documentSep: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1),
        .plain:       NSColor.labelColor,
    ]

    func colors(for appearance: NSAppearance) -> [YAMLTokenType: NSColor] {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? darkColors : lightColors
    }

    /// Tokenize a line and return ranges with their types.
    func tokenizeLine(_ line: String) -> [(NSRange, YAMLTokenType)] {
        var results: [(NSRange, YAMLTokenType)] = []
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else {
                continue
            }

            let matches = regex.matches(in: line, options: [], range: fullRange)
            for match in matches {
                let range = match.range
                // Check overlap with existing results
                let overlaps = results.contains { existing in
                    let intersection = NSIntersectionRange(range, existing.0)
                    return intersection.length > 0
                }
                if !overlaps {
                    results.append((range, rule.type))
                }
            }
        }

        return results.sorted { $0.0.location < $1.0.location }
    }
}
