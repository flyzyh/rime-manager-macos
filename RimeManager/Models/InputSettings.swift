import SwiftUI
import Yams

/// Observable model for Rime input method settings (from schema YAML).
/// Provides visual control bindings that map to schema YAML.
final class InputSettings: ObservableObject {
    @Published var asciiMode: Bool = false
    @Published var emojiSuggestion: Bool = true
    @Published var fullShape: Bool = false
    @Published var toneDisplay: Bool = false
    @Published var transcription: Bool = false
    @Published var asciiPunct: Bool = false

    @Published var pageSize: Int = 9
    @Published var candidateCount: Int = 9
    @Published var showPaging: Bool = false

    @Published var capsLockSwitch: Bool = true
    @Published var shiftSwitch: String = "commit_code"
    @Published var returnDirectCommit: Bool = false

    @Published var enableEncoder: Bool = true
    @Published var enableSentence: Bool = true
    @Published var enableUserDict: Bool = true
    @Published var encodeCommitHistory: Bool = true

    @Published var schemaName: String = ""
    @Published var schemaVersion: String = ""
    @Published var schemaID: String = ""

    private var rawSchemaDict: [String: Any] = [:]
    private var rawDefaultCustomDict: [String: Any] = [:]
    private var rawSchemaCustomDict: [String: Any] = [:]
    private var effectiveSwitches: [[String: Any]] = []

    func load(schemaYAML: String, defaultCustomYAML: String, schemaCustomYAML: String = "") {
        asciiMode = false
        emojiSuggestion = true
        fullShape = false
        toneDisplay = false
        transcription = false
        asciiPunct = false
        pageSize = 9
        candidateCount = 9
        capsLockSwitch = true
        shiftSwitch = "commit_code"
        returnDirectCommit = false
        enableEncoder = true
        enableSentence = true
        enableUserDict = true
        encodeCommitHistory = true
        schemaName = ""
        schemaVersion = ""
        schemaID = ""
        rawSchemaDict = [:]
        rawDefaultCustomDict = [:]
        rawSchemaCustomDict = [:]
        effectiveSwitches = []

        if let dict = try? Yams.load(yaml: schemaYAML) as? [String: Any] {
            rawSchemaDict = dict
            if let schema = dict["schema"] as? [String: Any] {
                schemaName = schema["name"] as? String ?? ""
                schemaVersion = schema["version"] as? String ?? ""
                schemaID = schema["schema_id"] as? String ?? ""
            }
            if let switches = dict["switches"] as? [[String: Any]] {
                effectiveSwitches = switches
            }
            if let menu = dict["menu"] as? [String: Any] {
                pageSize = menu["page_size"] as? Int ?? 9
            }
            candidateCount = pageSize
        }

        let defaultDict = (try? Yams.load(yaml: defaultCustomYAML) as? [String: Any]) ?? [:]
        rawDefaultCustomDict = defaultDict
        if let patch = defaultDict["patch"] as? [String: Any] {
            readDefaultPatch(patch)
        }

        let schemaDict = (try? Yams.load(yaml: schemaCustomYAML) as? [String: Any]) ?? [:]
        rawSchemaCustomDict = schemaDict
        if let patch = schemaDict["patch"] as? [String: Any] {
            readSchemaCustomPatch(patch)
        }
        readSwitchStates()
    }

    private func readDefaultPatch(_ root: [String: Any]) {
        let menuPageSize = (root["menu"] as? [String: Any])?["page_size"] as? Int
            ?? root["menu/page_size"] as? Int
        if let menuPageSize {
            pageSize = menuPageSize
            candidateCount = menuPageSize
        }

        if let caps = root["ascii_composer/good_old_caps_lock"] as? Bool {
            capsLockSwitch = caps
        } else if let caps = (root["ascii_composer"] as? [String: Any])?["good_old_caps_lock"] as? Bool {
            capsLockSwitch = caps
        }
        if let shift = (root["ascii_composer/switch_key"] as? [String: Any])?["Shift_L"] as? String {
            shiftSwitch = shift
        } else if let shift = ((root["ascii_composer"] as? [String: Any])?["switch_key"] as? [String: Any])?["Shift_L"] as? String {
            shiftSwitch = shift
        }

        let bindings = (root["key_binder/bindings"] as? [[String: Any]])
            ?? (root["key_binder/bindings/+"] as? [[String: Any]])
            ?? ((root["key_binder"] as? [String: Any])?["bindings"] as? [[String: Any]])
            ?? ((root["key_binder"] as? [String: Any])?["bindings/+"] as? [[String: Any]])
            ?? []
        if bindings.contains(where: { $0["accept"] as? String == "Return" && $0["send"] as? String == "Return" }) {
            returnDirectCommit = true
        }
    }

    private func readSchemaCustomPatch(_ root: [String: Any]) {
        if let page = (root["menu"] as? [String: Any])?["page_size"] as? Int ?? root["menu/page_size"] as? Int {
            pageSize = page
            candidateCount = page
        }

        if let customSwitches = root["switches"] as? [[String: Any]] {
            effectiveSwitches = customSwitches
        } else {
            for (key, value) in root where key.hasPrefix("switches/@") && key.hasSuffix("/reset") {
                let parts = key.split(separator: "/")
                if parts.count == 3, let index = Int(parts[1].dropFirst()), index < effectiveSwitches.count {
                    effectiveSwitches[index]["reset"] = value
                }
            }
        }

        let customTranslator = (root["translator"] as? [String: Any]) ?? [:]
        if let value = customTranslator["enable_encoder"] ?? root["translator/enable_encoder"] {
            enableEncoder = value as? Bool ?? enableEncoder
        }
        if let value = customTranslator["enable_sentence"] ?? root["translator/enable_sentence"] {
            enableSentence = value as? Bool ?? enableSentence
        }
        if let value = customTranslator["enable_user_dict"] ?? root["translator/enable_user_dict"] {
            enableUserDict = value as? Bool ?? enableUserDict
        }
        if let value = customTranslator["encode_commit_history"] ?? root["translator/encode_commit_history"] {
            encodeCommitHistory = value as? Bool ?? encodeCommitHistory
        }
    }

    private func readSwitchStates() {
        for sw in effectiveSwitches {
            guard let name = sw["name"] as? String else { continue }
            let reset = sw["reset"] as? Int ?? 0
            switch name {
            case "ascii_mode": asciiMode = reset != 0
            case "emoji_suggestion": emojiSuggestion = reset != 0
            case "full_shape": fullShape = reset != 0
            case "tone_display": toneDisplay = reset != 0
            case "transcription": transcription = reset != 0
            case "ascii_punct": asciiPunct = reset != 0
            default: break
            }
        }
    }

    static let managedSwitchNames: Set<String> = [
        "ascii_mode", "emoji_suggestion", "full_shape",
        "tone_display", "transcription", "ascii_punct",
    ]

    private var currentResets: [String: Int] {
        [
            "ascii_mode": asciiMode ? 1 : 0,
            "emoji_suggestion": emojiSuggestion ? 1 : 0,
            "full_shape": fullShape ? 1 : 0,
            "tone_display": toneDisplay ? 1 : 0,
            "transcription": transcription ? 1 : 0,
            "ascii_punct": asciiPunct ? 1 : 0,
        ]
    }

    /// switches patch 到 schema custom 层；已有完整列表时保持完整列表，否则只写 reset。
    func switchesPatchDict() -> [String: Any] {
        guard !effectiveSwitches.isEmpty else { return [:] }
        let resets = currentResets
        var changed = false
        for sw in effectiveSwitches {
            guard let name = sw["name"] as? String, Self.managedSwitchNames.contains(name) else { continue }
            if (sw["reset"] as? Int ?? 0) != resets[name] { changed = true; break }
        }
        guard changed else { return [:] }

        let originalPatch = rawSchemaCustomDict["patch"] as? [String: Any] ?? [:]
        if originalPatch["switches"] != nil {
            let rebuilt = effectiveSwitches.map { sw -> [String: Any] in
                guard let name = sw["name"] as? String,
                      Self.managedSwitchNames.contains(name),
                      (sw["reset"] as? Int ?? 0) != resets[name] else { return sw }
                var updated = sw
                updated["reset"] = resets[name]
                return updated
            }
            return ["switches": rebuilt]
        }

        var patch: [String: Any] = [:]
        for (index, sw) in effectiveSwitches.enumerated() {
            guard let name = sw["name"] as? String,
                  Self.managedSwitchNames.contains(name),
                  (sw["reset"] as? Int ?? 0) != resets[name] else { continue }
            patch["switches/@\(index)/reset"] = resets[name]
        }
        return patch
    }

    /// schema custom 补丁内容（不含 patch 包装）。
    func schemaCustomPatchDict() -> [String: Any] {
        var patch: [String: Any] = [
            "menu/page_size": candidateCount,
            "translator/enable_encoder": enableEncoder,
            "translator/enable_sentence": enableSentence,
            "translator/enable_user_dict": enableUserDict,
            "translator/encode_commit_history": encodeCommitHistory,
        ]
        patch.merge(switchesPatchDict()) { _, new in new }
        return patch
    }

    /// default.custom.yaml 补丁内容（不含 patch 包装）。
    func defaultCustomPatchDict() -> [String: Any] {
        var patch: [String: Any] = [
            "menu/page_size": candidateCount,
            "ascii_composer/good_old_caps_lock": capsLockSwitch,
            "ascii_composer/switch_key/Shift_L": shiftSwitch,
        ]

        let originalPatch = rawDefaultCustomDict["patch"] as? [String: Any] ?? [:]
        let hasFullBindings = originalPatch["key_binder/bindings"] != nil || originalPatch["key_binder"] != nil
        if returnDirectCommit, !hasFullBindings, originalPatch["key_binder/bindings/+"] == nil {
            patch["key_binder/bindings/+"] = Self.returnKeyFixBindings
        }
        return patch
    }

    /// Web 编辑器中 Return 键直接上屏的兼容绑定。
    nonisolated(unsafe) static let returnKeyFixBindings: [[String: Any]] = [
        ["when": "composing", "accept": "Return", "send": "Return"]
    ]

    func generateDefaultCustomPatch() -> String {
        do {
            return try Yams.dump(object: ["patch": defaultCustomPatchDict()])
        } catch {
            return "# Rime Manager: YAML serialization failed; original file was not safe to rebuild.\n"
        }
    }
}
