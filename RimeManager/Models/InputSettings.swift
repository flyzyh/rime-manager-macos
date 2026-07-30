import SwiftUI
import Yams

/// Observable model for Rime input method settings (from schema YAML).
/// Provides visual control bindings that map to schema YAML.
final class InputSettings: ObservableObject {
    // MARK: - Switches

    @Published var asciiMode: Bool = false           // Chinese (false) / English (true)
    @Published var emojiSuggestion: Bool = true
    @Published var fullShape: Bool = false           // Half (false) / Full (true)
    @Published var toneDisplay: Bool = false
    @Published var transcription: Bool = false       // Simplified (false) / Traditional (true)
    @Published var asciiPunct: Bool = false          // Chinese punct (false) / Western punct (true)

    // MARK: - Menu / Display

    @Published var pageSize: Int = 9
    @Published var candidateCount: Int = 9
    @Published var showPaging: Bool = false

    // MARK: - Caps Lock

    @Published var capsLockSwitch: Bool = true        // Good old caps lock behavior
    @Published var shiftSwitch: String = "commit_code" // Shift key behavior

    // MARK: - Schema info (read-only)

    @Published var schemaName: String = ""
    @Published var schemaVersion: String = ""
    @Published var schemaID: String = ""

    // MARK: - Raw references for writing back

    private var rawSchemaDict: [String: Any] = [:]
    private var rawDefaultCustomDict: [String: Any] = [:]
    private var hasDefaultCustom: Bool = false

    // MARK: - Load from schema + default.custom

    func load(schemaYAML: String, defaultCustomYAML: String) {
        if let dict = try? Yams.load(yaml: schemaYAML) as? [String: Any] {
            rawSchemaDict = dict

            if let schema = dict["schema"] as? [String: Any] {
                schemaName = schema["name"] as? String ?? ""
                schemaVersion = schema["version"] as? String ?? ""
                schemaID = schema["schema_id"] as? String ?? ""
            }

            // Parse switches
            if let switches = dict["switches"] as? [[String: Any]] {
                for sw in switches {
                    guard let name = sw["name"] as? String else { continue }
                    let reset = sw["reset"] as? Int ?? 0
                    switch name {
                    case "ascii_mode": asciiMode = (reset != 0)
                    case "emoji_suggestion": emojiSuggestion = (reset != 0)
                    case "full_shape": fullShape = (reset != 0)
                    case "tone_display": toneDisplay = (reset != 0)
                    case "transcription": transcription = (reset != 0)
                    case "ascii_punct": asciiPunct = (reset != 0)
                    default: break
                    }
                }
            }

            // Menu
            if let menu = dict["menu"] as? [String: Any] {
                pageSize = menu["page_size"] as? Int ?? 9
            }
            candidateCount = pageSize
        }

        // Parse default.custom.yaml
        if let customDict = try? Yams.load(yaml: defaultCustomYAML) as? [String: Any] {
            rawDefaultCustomDict = customDict
            hasDefaultCustom = true

            let root = customDict["patch"] as? [String: Any] ?? customDict

            if let menu = root["menu"] as? [String: Any] {
                let ps = menu["page_size"] as? Int
                if ps != nil { pageSize = ps!; candidateCount = ps! }
            }

            if let ascii = root["ascii_composer"] as? [String: Any] {
                capsLockSwitch = ascii["good_old_caps_lock"] as? Bool ?? true
                if let switchKey = ascii["switch_key"] as? [String: String] {
                    shiftSwitch = switchKey["Shift_L"] ?? "commit_code"
                }
            }
        }
    }

    // MARK: - Generate schema YAML patch

    func generateSchemaPatch() -> String {
        // Build switches with updated reset values
        let switches: [[String: Any]] = [
            switchEntry("ascii_mode", reset: asciiMode ? 1 : 0),
            switchEntry("emoji_suggestion", reset: emojiSuggestion ? 1 : 0),
            switchEntry("full_shape", reset: fullShape ? 1 : 0),
            switchEntry("tone_display", reset: toneDisplay ? 1 : 0),
            switchEntry("transcription", reset: transcription ? 1 : 0),
            switchEntry("ascii_punct", reset: asciiPunct ? 1 : 0),
        ]

        let patch: [String: Any] = [
            "switches": switches,
            "menu": ["page_size": candidateCount],
        ]

        do {
            return try Yams.dump(object: ["patch": patch])
        } catch {
            return ""
        }
    }

    /// Generate default.custom.yaml content
    func generateDefaultCustomPatch() -> String {
        var patch: [String: Any] = [
            "menu": ["page_size": candidateCount],
            "ascii_composer": [
                "good_old_caps_lock": capsLockSwitch,
                "switch_key": [
                    "Caps_Lock": "clear",
                    "Shift_L": shiftSwitch,
                    "Shift_R": shiftSwitch,
                    "Control_L": "noop",
                    "Control_R": "noop",
                ]
            ],
            // Ensure Return key works correctly in web editors
            "key_binder/bindings/+": [
                ["when": "composing", "accept": "Return", "send": "Return"],
                ["when": "composing", "accept": "KP_Enter", "send": "Return"],
            ]
        ]

        // Preserve additional key_binder if it existed
        if let existingPatch = rawDefaultCustomDict["patch"] as? [String: Any],
           let binder = existingPatch["key_binder"] {
            var mutable = patch
            mutable["key_binder"] = binder
            patch = mutable
        }

        do {
            return try Yams.dump(object: ["patch": patch])
        } catch {
            return ""
        }
    }

    private func switchEntry(_ name: String, reset: Int) -> [String: Any] {
        // Preserve original states if available
        let originalSwitches = (rawSchemaDict["switches"] as? [[String: Any]]) ?? []
        let original = originalSwitches.first { ($0["name"] as? String) == name }
        let states = original?["states"] as? [String] ?? []
        return ["name": name, "reset": reset, "states": states]
    }
}
