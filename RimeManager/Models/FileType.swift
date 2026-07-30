import Foundation

/// Supported file types in Rime configuration directory.
enum FileType: String, CaseIterable, Codable {
    case schema         // .schema.yaml — input method schema definition
    case customPatch    // .custom.yaml — user patch/override
    case dictionary     // .dict.yaml — dictionary definition
    case lua            // .lua — Lua extension script
    case yaml           // any other .yaml / .yml
    case text           // .txt — plain text data (opencc, etc.)
    case json           // .json — OpenCC data files
    case directory      // subdirectory
    case unknown        // unrecognized

    var displayName: String {
        switch self {
        case .schema:       return "Schema"
        case .customPatch:  return "Custom Patch"
        case .dictionary:   return "Dictionary"
        case .lua:          return "Lua Script"
        case .yaml:         return "YAML"
        case .text:         return "Text"
        case .json:         return "JSON"
        case .directory:    return "Folder"
        case .unknown:      return "Unknown"
        }
    }

    var sfSymbol: String {
        switch self {
        case .schema:       return "gearshape.2"
        case .customPatch:  return "bandage"
        case .dictionary:   return "book.pages"
        case .lua:          return "chevron.left.forwardslash.chevron.right"
        case .yaml:         return "doc.text"
        case .text:         return "doc.plaintext"
        case .json:         return "curlybraces"
        case .directory:    return "folder"
        case .unknown:      return "doc.questionmark"
        }
    }

    /// Detect file type from filename.
    static func detect(from filename: String, isDirectory: Bool = false) -> FileType {
        if isDirectory { return .directory }
        let lower = filename.lowercased()

        if lower.hasSuffix(".schema.yaml") || lower.hasSuffix(".schema.yml") {
            return .schema
        }
        if lower.hasSuffix(".custom.yaml") || lower.hasSuffix(".custom.yml") {
            return .customPatch
        }
        if lower.hasSuffix(".dict.yaml") || lower.hasSuffix(".dict.yml") {
            return .dictionary
        }
        if lower.hasSuffix(".lua") {
            return .lua
        }
        if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
            // Check if it's a root-level config like default.yaml, squirrel.yaml
            if ["default", "squirrel", "weasel", "ibus_rime", "installation", "user"].contains(where: { name in
                lower == "\(name).yaml" || lower == "\(name).yml"
            }) {
                return .yaml
            }
            return .customPatch
        }
        if lower.hasSuffix(".txt") {
            return .text
        }
        if lower.hasSuffix(".json") {
            return .json
        }
        return .unknown
    }

    /// Check if this type supports text editing.
    var isEditable: Bool {
        switch self {
        case .directory, .unknown: return false
        default: return true
        }
    }
}
