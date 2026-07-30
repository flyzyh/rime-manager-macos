import Foundation

/// Parsed Rime input method schema model.
struct RimeSchema: Identifiable {
    let id = UUID()

    // MARK: - Schema metadata

    var schemaID: String?
    var name: String?
    var version: String?
    var author: [String]?
    var description: String?
    var dependencies: [String]?

    // MARK: - Switches

    var switches: [SchemaSwitch] = []

    // MARK: - Engine

    var processors: [String] = []
    var segmentors: [String] = []
    var translators: [String] = []
    var filters: [String] = []

    // MARK: - Recognizer

    var recognizerPatterns: [String: String] = [:]

    // MARK: - Speller

    var alphabet: String?
    var initials: String?
    var finals: String?
    var maxCodeLength: Int?
    var autoSelect: Bool?
    var delimiter: String?
    var autoSelectPattern: String?
    var useSpace: Bool?

    // MARK: - Translator

    var dictionaryName: String?
    var enableCompletion: Bool?
    var enableSentence: Bool?
    var enableUserDict: Bool?
    var enableEncoder: Bool?
    var encodeCommitHistory: Bool?
    var maxPhraseLength: Int?
    var initialQuality: Double?
    var prism: String?

    // MARK: - Punctuator

    var punctuatorFullShape: [String: String] = [:]
    var punctuatorHalfShape: [String: String] = [:]
    var punctuatorUseSpace: Bool?
    var fullShapeTrigger: String?

    // MARK: - Key binder

    var keyBindings: [[String: Any]] = []
    var importPresetBindings: [String]?

    // MARK: - Menu

    var pageSize: Int?
    var alternativeSelectKeys: String?
    var pageDownKeys: String?
    var pageUpKeys: String?

    // MARK: - Reverse lookup

    var reverseLookupDict: String?
    var reverseLookupPrefix: String?
    var reverseLookupSuffix: String?
    var reverseLookupTips: String?

    // MARK: - ASCII composer

    var goodOldCapsLock: Bool?
    var switchKey: [String: String] = [:]

    // MARK: - Style (squirrel-specific)

    var colorScheme: String?
    var colorSchemeDark: String?
    var statusMessageType: String?
    var candidateFormat: String?
    var textOrientation: String?
    var inlinePreedit: Bool?
    var inlineCandidate: Bool?
    var translucency: Bool?
    var blurEnabled: Bool?
    var cornerRadius: Double?
    var fontFace: String?
    var fontPoint: Double?
    var labelFontFace: String?
    var labelFontPoint: Double?

    // MARK: - Patch info (for .custom.yaml)

    var isPatchFile: Bool = false
    var patchKeys: [String] = []
}

// MARK: - Schema Switch

struct SchemaSwitch: Identifiable {
    let id = UUID()
    var name: String
    var reset: Int = 0
    var states: [String] = []

    var currentState: String {
        guard reset >= 0, reset < states.count else { return "" }
        return states[reset]
    }
}
