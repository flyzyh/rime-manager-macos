import Foundation
import Yams

/// Analyzes Rime schema YAML content and extracts structured information.
final class SchemaAnalyzer {

    private let yamlService = YAMLParseService()

    // MARK: - Schema parsing

    /// Parse a complete schema from YAML content string.
    func parse(content: String) -> RimeSchema? {
        guard let dict = try? yamlService.parse(content) else { return nil }

        var schema = RimeSchema()

        // -- schema section --
        if let schemaSection = dict["schema"] as? [String: Any] {
            schema.schemaID = schemaSection["schema_id"] as? String
            schema.name = schemaSection["name"] as? String
            schema.version = schemaSection["version"] as? String
            schema.description = schemaSection["description"] as? String
            schema.dependencies = schemaSection["dependencies"] as? [String]

            if let author = schemaSection["author"] {
                if let authors = author as? [String] {
                    schema.author = authors
                } else if let single = author as? String {
                    schema.author = [single]
                }
            }
        }

        // -- switches --
        if let switches = dict["switches"] as? [[String: Any]] {
            schema.switches = switches.compactMap { sw -> SchemaSwitch? in
                guard let name = sw["name"] as? String else { return nil }
                let reset = sw["reset"] as? Int ?? 0
                let states = sw["states"] as? [String] ?? []
                return SchemaSwitch(name: name, reset: reset, states: states)
            }
        }

        // -- engine --
        if let engine = dict["engine"] as? [String: Any] {
            schema.processors = extractStringList(engine["processors"])
            schema.segmentors = extractStringList(engine["segmentors"])
            schema.translators = extractStringList(engine["translators"])
            schema.filters = extractStringList(engine["filters"])
        }

        // -- recognizer --
        if let recognizer = dict["recognizer"] as? [String: Any],
           let patterns = recognizer["patterns"] as? [String: String] {
            schema.recognizerPatterns = patterns
        }

        // -- speller --
        if let speller = dict["speller"] as? [String: Any] {
            schema.alphabet = speller["alphabet"] as? String
            schema.initials = speller["initials"] as? String
            schema.finals = speller["finals"] as? String
            schema.maxCodeLength = speller["max_code_length"] as? Int
            schema.autoSelect = speller["auto_select"] as? Bool
            schema.delimiter = speller["delimiter"] as? String
            schema.autoSelectPattern = speller["auto_select_pattern"] as? String
            schema.useSpace = speller["use_space"] as? Bool
        }

        // -- translator --
        if let translator = dict["translator"] as? [String: Any] {
            schema.dictionaryName = translator["dictionary"] as? String
            schema.enableCompletion = translator["enable_completion"] as? Bool
            schema.enableSentence = translator["enable_sentence"] as? Bool
            schema.enableUserDict = translator["enable_user_dict"] as? Bool
            schema.enableEncoder = translator["enable_encoder"] as? Bool
            schema.encodeCommitHistory = translator["encode_commit_history"] as? Bool
            schema.maxPhraseLength = translator["max_phrase_length"] as? Int
            schema.initialQuality = translator["initial_quality"] as? Double
            schema.prism = translator["prism"] as? String
        }

        // -- punctuator --
        if let punctuator = dict["punctuator"] as? [String: Any] {
            schema.punctuatorFullShape = (punctuator["full_shape"] as? [String: String]) ?? [:]
            schema.punctuatorHalfShape = (punctuator["half_shape"] as? [String: String]) ?? [:]
            schema.useSpace = schema.useSpace ?? (punctuator["use_space"] as? Bool)
            schema.fullShapeTrigger = punctuator["full_shape_trigger"] as? String
        }

        // -- key_binder --
        if let binder = dict["key_binder"] as? [String: Any] {
            if let bindings = binder["bindings"] as? [[String: Any]] {
                schema.keyBindings = bindings
            }
            schema.importPresetBindings = binder["import_preset"] as? [String]
        }

        // -- menu --
        if let menu = dict["menu"] as? [String: Any] {
            schema.pageSize = menu["page_size"] as? Int
            schema.alternativeSelectKeys = menu["alternative_select_keys"] as? String
            schema.pageDownKeys = menu["page_down"] as? String
            schema.pageUpKeys = menu["page_up"] as? String
        }

        // -- reverse_lookup --
        if let reverse = dict["reverse_lookup"] as? [String: Any] {
            schema.reverseLookupDict = reverse["dictionary"] as? String
            schema.reverseLookupPrefix = reverse["prefix"] as? String
            schema.reverseLookupSuffix = reverse["suffix"] as? String
            schema.reverseLookupTips = reverse["tips"] as? String
        }

        // -- ascii_composer --
        if let ascii = dict["ascii_composer"] as? [String: Any] {
            schema.goodOldCapsLock = ascii["good_old_caps_lock"] as? Bool
            schema.switchKey = (ascii["switch_key"] as? [String: String]) ?? [:]
        }

        // -- style --
        if let style = dict["style"] as? [String: Any] {
            schema.colorScheme = style["color_scheme"] as? String
            schema.colorSchemeDark = style["color_scheme_dark"] as? String
            schema.statusMessageType = style["status_message_type"] as? String
            schema.candidateFormat = style["candidate_format"] as? String
            schema.textOrientation = style["text_orientation"] as? String
            schema.inlinePreedit = style["inline_preedit"] as? Bool
            schema.inlineCandidate = style["inline_candidate"] as? Bool
            schema.translucency = style["translucency"] as? Bool
            schema.blurEnabled = style["blur"] as? Bool
            schema.cornerRadius = style["corner_radius"] as? Double
            schema.fontFace = style["font_face"] as? String
            schema.fontPoint = style["font_point"] as? Double
            schema.labelFontFace = style["label_font_face"] as? String
            schema.labelFontPoint = style["label_font_point"] as? Double
        }

        // -- patch detection --
        if let patch = dict["patch"] as? [String: Any] {
            schema.isPatchFile = true
            schema.patchKeys = Array(patch.keys).sorted()
        }

        return schema
    }

    // MARK: - Color scheme extraction (from squirrel files)

    /// Extract color schemes from a squirrel configuration YAML.
    func extractColorSchemes(from content: String) -> [ColorScheme] {
        guard let dict = try? yamlService.parse(content) else { return [] }

        var schemes: [ColorScheme] = []

        // Check preset_color_schemes
        if let presets = dict["preset_color_schemes"] as? [String: Any] {
            for (name, value) in presets {
                if let schemeDict = value as? [String: Any] {
                    let scheme = parseColorScheme(name: name, dict: schemeDict)
                    schemes.append(scheme)
                }
            }
        }

        // Also check the style section for the active scheme names
        if let style = dict["style"] as? [String: Any] {
            // light scheme
            if let lightName = style["color_scheme"] as? String,
               let lightDict = dict["preset_color_schemes"] as? [String: Any],
               let schemeDict = lightDict[lightName] as? [String: Any] {
                // Already added above
            }

            // dark scheme
            if let darkName = style["color_scheme_dark"] as? String,
               let darkDict = dict["preset_color_schemes"] as? [String: Any],
               let schemeDict = darkDict[darkName] as? [String: Any] {
                // Already added above
            }
        }

        return schemes
    }

    /// Parse an individual color scheme from its dictionary.
    func parseColorScheme(name: String, dict: [String: Any]) -> ColorScheme {
        var scheme = ColorScheme(name: name)
        scheme.isDark = name.lowercased().contains("dark")

        scheme.backColor = parseColor(dict["back_color"])
        scheme.hilitedCandidateBackColor = parseColor(dict["hilited_candidate_back_color"])
        scheme.labelColor = parseColor(dict["label_color"])
        scheme.hilitedCandidateLabelColor = parseColor(dict["hilited_candidate_label_color"])
        scheme.candidateTextColor = parseColor(dict["candidate_text_color"])
        scheme.hilitedCandidateTextColor = parseColor(dict["hilited_candidate_text_color"])
        scheme.commentTextColor = parseColor(dict["comment_text_color"])
        scheme.hilitedCommentTextColor = parseColor(dict["hilited_comment_text_color"])
        scheme.textColor = parseColor(dict["text_color"])
        scheme.hilitedTextColor = parseColor(dict["hilited_text_color"])
        scheme.borderColor = parseColor(dict["border_color"])
        scheme.shadowColor = parseColor(dict["shadow_color"])

        scheme.alpha = dict["alpha"] as? Double
        scheme.cornerRadius = dict["corner_radius"] as? Double
        scheme.hilitedCornerRadius = dict["hilited_corner_radius"] as? Double
        scheme.borderHeight = dict["border_height"] as? Double
        scheme.borderWidth = dict["border_width"] as? Double
        scheme.lineSpacing = dict["line_spacing"] as? Double
        scheme.spacing = dict["spacing"] as? Double
        scheme.shadowSize = dict["shadow_size"] as? Double
        scheme.fontFace = dict["font_face"] as? String
        scheme.fontPoint = dict["font_point"] as? Double
        scheme.labelFontFace = dict["label_font_face"] as? String
        scheme.labelFontPoint = dict["label_font_point"] as? Double
        scheme.commentFontFace = dict["comment_font_face"] as? String
        scheme.commentFontPoint = dict["comment_font_point"] as? Double

        scheme.translucency = dict["translucency"] as? Bool
        scheme.blur = dict["blur"] as? Bool

        return scheme
    }

    // MARK: - Dictionary analysis

    /// Extract dictionary metadata from a .dict.yaml file.
    func parseDictionaryMetadata(from content: String) -> DictMetadata? {
        guard let dict = try? yamlService.parse(content) else { return nil }

        var meta = DictMetadata()
        meta.name = dict["name"] as? String
        meta.version = dict["version"] as? String
        meta.sort = dict["sort"] as? String
        meta.usePresetVocabulary = dict["use_preset_vocabulary"] as? Bool
        meta.importTables = dict["import_tables"] as? [String]
        return meta
    }

    // MARK: - Helpers

    private func extractStringList(_ value: Any?) -> [String] {
        guard let list = value as? [Any] else { return [] }
        return list.compactMap { item in
            if let str = item as? String { return str }
            if let dict = item as? [String: Any], let key = dict.keys.first {
                // Handle "lua_processor@*proc_name" style entries
                return key
            }
            return nil
        }
    }

    private func parseColor(_ value: Any?) -> Color? {
        if let hex = value as? String {
            return ColorScheme.parseHexColor(hex)
        }
        if let int = value as? Int {
            let hex = String(format: "%08X", int)
            return ColorScheme.parseHexColor(hex)
        }
        return nil
    }
}

// MARK: - Dictionary Metadata

struct DictMetadata {
    var name: String?
    var version: String?
    var sort: String?
    var usePresetVocabulary: Bool?
    var importTables: [String]?
}

import SwiftUI
