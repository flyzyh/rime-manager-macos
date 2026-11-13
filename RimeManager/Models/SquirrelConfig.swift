import SwiftUI
import Yams

/// Observable model representing the squirrel (Squirrel) configuration.
/// Provides two-way binding between YAML config and visual controls.
final class SquirrelConfig: ObservableObject {
    // MARK: - Layout

    @Published var textOrientation: TextOrientation = .horizontal
    @Published var candidateListLayout: CandidateLayout = .linear
    @Published var inlinePreedit: Bool = true
    @Published var inlineCandidate: Bool = false
    @Published var showPaging: Bool = false
    @Published var mutualExclusive: Bool = false
    @Published var rememberSize: Bool = true
    @Published var candidateFormat: String = "%c. %@"
    @Published var statusMessageType: StatusMessageType = .mix
    @Published var pageSize: Int = 9

    // MARK: - Appearance

    @Published var translucency: Bool = true
    @Published var blurEnabled: Bool = true
    @Published var alpha: Double = 0.84
    @Published var cornerRadius: Double = 8
    @Published var hilitedCornerRadius: Double = 6
    @Published var borderHeight: Double = 0
    @Published var borderWidth: Double = 0
    @Published var lineSpacing: Double = 5
    @Published var spacing: Double = 10
    @Published var shadowSize: Double = 8

    // MARK: - Typography

    @Published var fontFace: String = "PingFangSC"
    @Published var fontPoint: Double = 18
    @Published var labelFontFace: String = "PingFangSC"
    @Published var labelFontPoint: Double = 14
    @Published var commentFontFace: String = "PingFangSC"
    @Published var commentFontPoint: Double = 13

    // MARK: - Color Scheme Selection

    @Published var colorSchemeLightName: String = "mint_light_blue"
    @Published var colorSchemeDarkName: String = "mint_dark_blue"
    @Published var colorSchemes: [String: EditableColorScheme] = [:]

    // MARK: - Top-level settings

    @Published var showNotificationsWhen: ShowNotificationsWhen = .appropriate
    @Published var appOptions: [AppOptionEntry] = []

    // MARK: - Raw YAML reference

    private var originalCustomDict: [String: Any] = [:]
    /// 加载时各配色方案的颜色与样式覆盖快照，用于判断用户是否修改过（避免回写破坏原始配色）
    private var schemeColorSnapshot: [String: [String: String]] = [:]
    private var schemeOverridesSnapshot: [String: [String: String]] = [:]
    var customFileExists: Bool = false

    func load(from yaml: String) {
        load(baseYAML: yaml, customYAML: "")
    }

    func load(baseYAML: String, customYAML: String) {
        // 先复位，避免二次加载时新目录无 menu 等配置导致残留上一次的值
        pageSize = 9

        // 1. Parse base config
        var baseDict: [String: Any] = [:]
        if !baseYAML.isEmpty {
            baseDict = (try? Yams.load(yaml: baseYAML) as? [String: Any]) ?? [:]
        }

        // 2. Parse custom/patch config
        var customDict: [String: Any] = [:]
        customFileExists = !customYAML.isEmpty
        if customFileExists {
            customDict = (try? Yams.load(yaml: customYAML) as? [String: Any]) ?? [:]
            originalCustomDict = customDict
        }

        // 3. Merge: custom "patch" overrides base "style"
        let baseStyle = baseDict["style"] as? [String: Any] ?? [:]
        let customPatch = customDict["patch"] as? [String: Any] ?? [:]
        let customStyle = Self.patchMap(customPatch, "style")

        // Merge style: custom overrides base
        var mergedStyle = baseStyle
        for (k, v) in customStyle { mergedStyle[k] = v }

        // Color schemes: prefer base schemes (since custom usually has preset_color_schemes: {})
        var mergedSchemes: [String: Any] = [:]

        // From base
        if let baseSchemes = baseDict["preset_color_schemes"] as? [String: Any] {
            for (k, v) in baseSchemes { mergedSchemes[k] = v }
        }
        // Flat keys in base
        for (key, value) in baseDict {
            if key.hasPrefix("preset_color_schemes/") {
                mergedSchemes[String(key.dropFirst("preset_color_schemes/".count))] = value
            }
        }

        // From custom (only if not empty — {} means "don't override")
        if let customSchemes = customPatch["preset_color_schemes"] as? [String: Any],
           !customSchemes.isEmpty {
            mergedSchemes = Self.deepMerged(mergedSchemes, customSchemes)
        }
        for (key, value) in customPatch {
            if key.hasPrefix("preset_color_schemes/") {
                let path = String(key.dropFirst("preset_color_schemes/".count))
                var incoming: [String: Any] = [:]
                Self.setValue(&incoming, path: path, value: value)
                mergedSchemes = Self.deepMerged(mergedSchemes, incoming)
            }
        }

        // Apply merged settings
        applyStyle(mergedStyle)
        applyColorSchemes(mergedSchemes)

        // 快照各方案的当前颜色与样式覆盖值
        schemeColorSnapshot = [:]
        schemeOverridesSnapshot = [:]
        for (name, scheme) in colorSchemes {
            schemeColorSnapshot[name] = scheme.hexDict()
            schemeOverridesSnapshot[name] = scheme.overridesSnapshot()
        }

        // Menu (page size)：patch 有 "menu" 节点与 "menu/page_size" 扁平键两种形态，
        // 生成侧按基底情况二选一写入，读取侧必须同时兼容，否则扁平键形态
        // 在重启后读不回来，再次应用时会被默认值覆盖
        if let menu = customPatch["menu"] as? [String: Any] {
            pageSize = menu["page_size"] as? Int ?? 9
        } else if let flat = customPatch["menu/page_size"] as? Int {
            pageSize = flat
        } else if let menu = baseDict["menu"] as? [String: Any] {
            pageSize = menu["page_size"] as? Int ?? 9
        }

        // Top-level: show_notifications_when (inside patch)
        let notifRaw = customPatch["show_notifications_when"] as? String
            ?? baseDict["show_notifications_when"] as? String
        showNotificationsWhen = ShowNotificationsWhen(rawValue: notifRaw ?? "") ?? .appropriate

        // Top-level: app_options
        let customAppOptions = Self.patchMap(customPatch, "app_options")
        let appOpts = customAppOptions.isEmpty ? baseDict["app_options"] as? [String: Any] : customAppOptions
        appOptions = Self.parseAppOptions(appOpts)
    }

    private func applyStyle(_ style: [String: Any]) {
        textOrientation = parseOrientation(style["text_orientation"])
        candidateListLayout = parseLayout(style["candidate_list_layout"])
        inlinePreedit = style["inline_preedit"] as? Bool ?? true
        inlineCandidate = style["inline_candidate"] as? Bool ?? false
        showPaging = style["show_paging"] as? Bool ?? false
        mutualExclusive = style["mutual_exclusive"] as? Bool ?? false
        rememberSize = style["remember_size"] as? Bool ?? true
        candidateFormat = style["candidate_format"] as? String ?? "%c. %@"
        statusMessageType = parseStatusType(style["status_message_type"])
        translucency = style["translucency"] as? Bool ?? true
        blurEnabled = style["blur"] as? Bool ?? true
        alpha = doubleVal(style["alpha"]) ?? 0.84
        cornerRadius = doubleVal(style["corner_radius"]) ?? 8
        hilitedCornerRadius = doubleVal(style["hilited_corner_radius"]) ?? 6
        borderHeight = doubleVal(style["border_height"]) ?? 0
        borderWidth = doubleVal(style["border_width"]) ?? 0
        lineSpacing = doubleVal(style["line_spacing"]) ?? 5
        spacing = doubleVal(style["spacing"]) ?? 10
        shadowSize = doubleVal(style["shadow_size"]) ?? 8
        fontFace = style["font_face"] as? String ?? "PingFangSC"
        fontPoint = doubleVal(style["font_point"]) ?? 18
        labelFontFace = style["label_font_face"] as? String ?? "PingFangSC"
        labelFontPoint = doubleVal(style["label_font_point"]) ?? 14
        commentFontFace = style["comment_font_face"] as? String ?? "PingFangSC"
        commentFontPoint = doubleVal(style["comment_font_point"]) ?? 13
        colorSchemeLightName = style["color_scheme"] as? String ?? ""
        colorSchemeDarkName = style["color_scheme_dark"] as? String ?? ""
    }

    /// Safely extract a Double from a YAML value (handles both Int and Double).
    private func doubleVal(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }

    private func applyColorSchemes(_ schemes: [String: Any]) {
        colorSchemes = [:]
        for (name, value) in schemes {
            if let schemeDict = value as? [String: Any] {
                colorSchemes[name] = EditableColorScheme(name: name, dict: schemeDict)
            }
        }
    }

    // MARK: - Generate YAML

    func generateYAML() -> String {
        // Build style block from current settings
        let styleBlock: [String: Any] = [
            "color_scheme": colorSchemeLightName,
            "color_scheme_dark": colorSchemeDarkName,
            "text_orientation": textOrientation.yamlValue,
            "candidate_list_layout": candidateListLayout.yamlValue,
            "inline_preedit": inlinePreedit,
            "inline_candidate": inlineCandidate,
            "show_paging": showPaging,
            "mutual_exclusive": mutualExclusive,
            "remember_size": rememberSize,
            "candidate_format": candidateFormat,
            "status_message_type": statusMessageType.yamlValue,
            "translucency": translucency,
            "blur": blurEnabled,
            "alpha": alpha,
            "corner_radius": Int(cornerRadius),
            "hilited_corner_radius": Int(hilitedCornerRadius),
            "border_height": Int(borderHeight),
            "border_width": Int(borderWidth),
            "line_spacing": Int(lineSpacing),
            "spacing": Int(spacing),
            "shadow_size": Int(shadowSize),
            "font_face": fontFace,
            "font_point": Int(fontPoint),
            "label_font_face": labelFontFace,
            "label_font_point": Int(labelFontPoint),
            "comment_font_face": commentFontFace,
            "comment_font_point": Int(commentFontPoint),
        ]

        // Preserve original custom YAML structure, but flatten managed nodes into
        // field-level slash paths. A nested `style`, `preset_color_schemes`, or
        // `app_options` patch replaces the whole node in Rime and drops unmanaged siblings.
        var result: [String: Any]
        if customFileExists, var patch = originalCustomDict["patch"] as? [String: Any] {
            Self.flattenManagedSquirrelPatch(&patch)
            result = ["patch": patch]
        } else {
            result = ["patch": [String: Any]()]
        }
        var patch = (result["patch"] as? [String: Any]) ?? [:]
        for (key, value) in styleBlock { patch["style/\(key)"] = value }
        for (key, value) in modifiedColorSchemeLeafDict() { patch[key] = value }
        for (key, value) in appOptionLeafDict() { patch[key] = value }
        patch["menu/page_size"] = pageSize
        patch["show_notifications_when"] = showNotificationsWhen.rawValue
        result = ["patch": patch]

        guard let yaml = try? Yams.dump(object: result), !yaml.isEmpty else {
            return "# Rime Manager: YAML serialization failed; original file was not safe to rebuild.\n"
        }
        return yaml
    }

    /// Returns modified schemes as patch-path leaves, e.g. `preset_color_schemes/aqua/back_color`.
    private func modifiedColorSchemeLeafDict() -> [String: Any] {
        var result: [String: Any] = [:]
        for (schemeName, scheme) in colorSchemes {
            let colorsUnchanged = schemeColorSnapshot[schemeName] == scheme.hexDict()
            let overridesUnchanged = schemeOverridesSnapshot[schemeName] == scheme.overridesSnapshot()
            guard !colorsUnchanged || !overridesUnchanged else { continue }
            for (field, value) in scheme.toDict() {
                result["preset_color_schemes/\(schemeName)/\(field)"] = value
            }
        }
        return result
    }

    /// App options as leaves, preserving unmanaged bundles and fields in the base config.
    private func appOptionLeafDict() -> [String: Any] {
        var result: [String: Any] = [:]
        var merged = Self.defaultAppOptions
        for (bundleID, options) in appOptionsDict() { merged[bundleID] = options }
        for (bundleID, value) in merged {
            guard let options = value as? [String: Any] else {
                result["app_options/\(bundleID)"] = value
                continue
            }
            for (field, value) in options {
                result["app_options/\(bundleID)/\(field)"] = value
            }
        }
        return result
    }

    // MARK: - Effective colors for preview

    /// Default browser app_options to fix Enter key and web editor compatibility.
    nonisolated(unsafe) static let defaultAppOptions: [String: Any] = [
        "com.apple.Safari": ["no_inline": false],
        "com.google.Chrome": ["no_inline": false],
        "com.microsoft.edgemac": ["no_inline": false],
    ]

    static func parseAppOptions(_ dict: [String: Any]?) -> [AppOptionEntry] {
        guard let dict = dict else { return [] }
        return dict.compactMap { bundleID, value in
            guard let opts = value as? [String: Any] else { return nil }
            let unknown = opts.filter { !["no_inline", "ascii_mode", "vim_mode"].contains($0.key) }
            return AppOptionEntry(
                bundleID: bundleID,
                noInline: opts["no_inline"] as? Bool,
                asciiMode: opts["ascii_mode"] as? Bool,
                vimMode: opts["vim_mode"] as? Bool,
                unknownOptions: unknown
            )
        }
        .sorted { $0.bundleID < $1.bundleID }
    }

    func appOptionsDict() -> [String: Any] {
        var result: [String: Any] = [:]
        for entry in appOptions {
            var opts: [String: Any] = [:]
            if let v = entry.noInline { opts["no_inline"] = v }
            if let v = entry.asciiMode { opts["ascii_mode"] = v }
            if let v = entry.vimMode { opts["vim_mode"] = v }
            for (key, value) in entry.unknownOptions { opts[key] = value }
            if !opts.isEmpty { result[entry.bundleID] = opts }
        }
        return result
    }

    /// Returns a dict of color schemes that have been modified (for writing to patch).
    func modifiedColorSchemesDict() -> [String: Any] {
        var result: [String: Any] = [:]
        for (name, scheme) in colorSchemes {
            // 与加载时的快照比较：颜色与样式覆盖（alpha/圆角/间距等）任一被改过都需回写，
            // 否则方案级的样式修改会静默丢失
            let colorsUnchanged = schemeColorSnapshot[name] == scheme.hexDict()
            let overridesUnchanged = schemeOverridesSnapshot[name] == scheme.overridesSnapshot()
            if colorsUnchanged && overridesUnchanged {
                continue // 未修改，跳过
            }
            result[name] = scheme.toDict()
        }
        return result
    }

    var effectiveLightScheme: EditableColorScheme? {
        colorSchemes[colorSchemeLightName]
    }

    var effectiveDarkScheme: EditableColorScheme? {
        colorSchemes[colorSchemeDarkName]
    }

    func effectiveScheme(isDark: Bool) -> EditableColorScheme? {
        isDark ? effectiveDarkScheme : effectiveLightScheme
    }

    // MARK: - Parsing helpers

    private func parseOrientation(_ value: Any?) -> TextOrientation {
        guard let str = value as? String else { return .horizontal }
        return TextOrientation(rawValue: str) ?? .horizontal
    }

    private func parseLayout(_ value: Any?) -> CandidateLayout {
        guard let str = value as? String else { return .linear }
        return CandidateLayout(rawValue: str) ?? .linear
    }

    private func parseStatusType(_ value: Any?) -> StatusMessageType {
        guard let str = value as? String else { return .mix }
        return StatusMessageType(rawValue: str) ?? .mix
    }

    // MARK: - Patch path helpers

    private static func patchMap(_ patch: [String: Any], _ root: String) -> [String: Any] {
        var result = patch[root] as? [String: Any] ?? [:]
        let prefix = root + "/"
        for (key, value) in patch where key.hasPrefix(prefix) {
            let path = String(key.dropFirst(prefix.count))
            setValue(&result, path: path, value: value)
        }
        return result
    }

    private static func setValue(_ dict: inout [String: Any], path: String, value: Any) {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return }
        if parts.count == 1 {
            dict[parts[0]] = value
            return
        }
        var child = dict[parts[0]] as? [String: Any] ?? [:]
        setValue(&child, path: parts.dropFirst().joined(separator: "/"), value: value)
        dict[parts[0]] = child
    }

    private static func deepMerged(_ base: [String: Any], _ new: [String: Any]) -> [String: Any] {
        var result = base
        for (key, newValue) in new {
            if let baseDict = result[key] as? [String: Any], let newDict = newValue as? [String: Any] {
                result[key] = deepMerged(baseDict, newDict)
            } else {
                result[key] = newValue
            }
        }
        return result
    }

    /// Convert old nested managed nodes to slash-path leaves without losing unknown fields.
    private static func flattenManagedSquirrelPatch(_ patch: inout [String: Any]) {
        let style = patchMap(patch, "style")
        patch.removeValue(forKey: "style")
        for (key, value) in style { patch["style/\(key)"] = value }

        let schemes = patchMap(patch, "preset_color_schemes")
        patch.removeValue(forKey: "preset_color_schemes")
        for (scheme, fields) in schemes {
            guard let fields = fields as? [String: Any] else {
                patch["preset_color_schemes/\(scheme)"] = fields
                continue
            }
            for (field, value) in fields {
                patch["preset_color_schemes/\(scheme)/\(field)"] = value
            }
        }

        let apps = patchMap(patch, "app_options")
        patch.removeValue(forKey: "app_options")
        for (bundle, value) in apps {
            guard let fields = value as? [String: Any] else {
                patch["app_options/\(bundle)"] = value
                continue
            }
            for (field, fieldValue) in fields {
                patch["app_options/\(bundle)/\(field)"] = fieldValue
            }
        }

        patch.removeValue(forKey: "menu")
        patch["menu/page_size"] = patch["menu/page_size"] ?? 9
    }
}

// MARK: - Enums

enum TextOrientation: String, CaseIterable {
    case horizontal = "horizontal"
    case vertical = "vertical"

    var yamlValue: String { rawValue }
    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal (横排)"
        case .vertical: return "Vertical (竖排)"
        }
    }
}

enum CandidateLayout: String, CaseIterable {
    case linear = "linear"
    case stacked = "stacked"
    case tabled = "tabled"

    var yamlValue: String { rawValue }
    var displayName: String {
        switch self {
        case .linear: return "Linear (线性)"
        case .stacked: return "Stacked (堆叠)"
        case .tabled: return "Tabled (表格)"
        }
    }
}

enum StatusMessageType: String, CaseIterable {
    case mix = "mix"
    case long = "long"
    case short = "short"
    case none = "none"

    var yamlValue: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Editable Color Scheme

final class EditableColorScheme: ObservableObject, Identifiable {
    let id = UUID()
    let name: String

    // MARK: - Colors

    @Published var backColor: String = "0xF2F2F7"
    @Published var hilitedCandidateBackColor: String = "0xFFFF840A"
    @Published var labelColor: String = "0x8E8E93"
    @Published var hilitedCandidateLabelColor: String = "0xFFFFFF"
    @Published var candidateTextColor: String = "0x3C3C43"
    @Published var hilitedCandidateTextColor: String = "0xFFFFFF"
    @Published var commentTextColor: String = "0x8E8E93"
    @Published var hilitedCommentTextColor: String = "0xFFFFFF"
    @Published var textColor: String = "0xFF840A"
    @Published var hilitedTextColor: String = "0xFF840A"
    @Published var borderColor: String = "0x7C7C8040"
    @Published var shadowColor: String = "0x20000000"

    // MARK: - Scheme-level style overrides (optional, override global style)

    @Published var schemeAlpha: Double?
    @Published var schemeTranslucency: Bool?
    @Published var schemeMutualExclusive: Bool?
    @Published var schemeShadowSize: Double?
    @Published var schemeCornerRadius: Double?
    @Published var schemeHilitedCornerRadius: Double?
    @Published var schemeLineSpacing: Double?
    @Published var schemeSpacing: Double?
    @Published var schemeBorderHeight: Double?
    @Published var schemeBorderWidth: Double?
    /// Fields added by users or future Squirrel versions must not be dropped.
    private var unknownFields: [String: Any] = [:]
    private static let knownSchemeKeys: Set<String> = [
        "back_color", "hilited_candidate_back_color", "label_color",
        "hilited_candidate_label_color", "candidate_text_color",
        "hilited_candidate_text_color", "comment_text_color",
        "hilited_comment_text_color", "text_color", "hilited_text_color",
        "border_color", "shadow_color", "alpha", "translucency",
        "mutual_exclusive", "shadow_size", "corner_radius",
        "hilited_corner_radius", "line_spacing", "spacing", "border_height",
        "border_width"
    ]

    init(name: String) {
        self.name = name
    }

    init(name: String, dict: [String: Any]) {
        self.name = name
        backColor = stringValue(dict["back_color"]) ?? "0xF2F2F7"
        hilitedCandidateBackColor = stringValue(dict["hilited_candidate_back_color"]) ?? "0xFFFF840A"
        labelColor = stringValue(dict["label_color"]) ?? "0x8E8E93"
        hilitedCandidateLabelColor = stringValue(dict["hilited_candidate_label_color"]) ?? "0xFFFFFF"
        candidateTextColor = stringValue(dict["candidate_text_color"]) ?? "0x3C3C43"
        hilitedCandidateTextColor = stringValue(dict["hilited_candidate_text_color"]) ?? "0xFFFFFF"
        commentTextColor = stringValue(dict["comment_text_color"]) ?? "0x8E8E93"
        hilitedCommentTextColor = stringValue(dict["hilited_comment_text_color"]) ?? "0xFFFFFF"
        textColor = stringValue(dict["text_color"]) ?? "0xFF840A"
        hilitedTextColor = stringValue(dict["hilited_text_color"]) ?? "0xFF840A"
        borderColor = stringValue(dict["border_color"]) ?? "0x7C7C8040"
        shadowColor = stringValue(dict["shadow_color"]) ?? "0x20000000"

        // Parse scheme-level style overrides
        schemeAlpha = doubleVal(dict["alpha"])
        schemeTranslucency = dict["translucency"] as? Bool
        schemeMutualExclusive = dict["mutual_exclusive"] as? Bool
        schemeShadowSize = doubleVal(dict["shadow_size"])
        schemeCornerRadius = doubleVal(dict["corner_radius"])
        schemeHilitedCornerRadius = doubleVal(dict["hilited_corner_radius"])
        schemeLineSpacing = doubleVal(dict["line_spacing"])
        schemeSpacing = doubleVal(dict["spacing"])
        schemeBorderHeight = doubleVal(dict["border_height"])
        schemeBorderWidth = doubleVal(dict["border_width"])
        unknownFields = dict.filter { !Self.knownSchemeKeys.contains($0.key) }
    }

    /// Safely extract a Double from a YAML value (handles both Int and Double).
    private func doubleVal(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }

    /// 仅返回 12 个颜色字段的 hex 快照，用于变更检测
    func hexDict() -> [String: String] {
        [
            "back_color": backColor,
            "hilited_candidate_back_color": hilitedCandidateBackColor,
            "label_color": labelColor,
            "hilited_candidate_label_color": hilitedCandidateLabelColor,
            "candidate_text_color": candidateTextColor,
            "hilited_candidate_text_color": hilitedCandidateTextColor,
            "comment_text_color": commentTextColor,
            "hilited_comment_text_color": hilitedCommentTextColor,
            "text_color": textColor,
            "hilited_text_color": hilitedTextColor,
            "border_color": borderColor,
            "shadow_color": shadowColor,
        ]
    }

    /// 方案级样式覆盖（alpha/圆角/间距等）的字符串快照，用于变更检测
    func overridesSnapshot() -> [String: String] {
        var d: [String: String] = [:]
        if let v = schemeAlpha { d["alpha"] = "\(v)" }
        if let v = schemeTranslucency { d["translucency"] = "\(v)" }
        if let v = schemeMutualExclusive { d["mutual_exclusive"] = "\(v)" }
        if let v = schemeShadowSize { d["shadow_size"] = "\(v)" }
        if let v = schemeCornerRadius { d["corner_radius"] = "\(v)" }
        if let v = schemeHilitedCornerRadius { d["hilited_corner_radius"] = "\(v)" }
        if let v = schemeLineSpacing { d["line_spacing"] = "\(v)" }
        if let v = schemeSpacing { d["spacing"] = "\(v)" }
        if let v = schemeBorderHeight { d["border_height"] = "\(v)" }
        if let v = schemeBorderWidth { d["border_width"] = "\(v)" }
        return d
    }

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "back_color": backColor,
            "hilited_candidate_back_color": hilitedCandidateBackColor,
            "label_color": labelColor,
            "hilited_candidate_label_color": hilitedCandidateLabelColor,
            "candidate_text_color": candidateTextColor,
            "hilited_candidate_text_color": hilitedCandidateTextColor,
            "comment_text_color": commentTextColor,
            "hilited_comment_text_color": hilitedCommentTextColor,
            "text_color": textColor,
            "hilited_text_color": hilitedTextColor,
            "border_color": borderColor,
            "shadow_color": shadowColor,
        ]
        // Include scheme-level style overrides
        if let v = schemeAlpha { dict["alpha"] = v }
        if let v = schemeTranslucency { dict["translucency"] = v }
        if let v = schemeMutualExclusive { dict["mutual_exclusive"] = v }
        if let v = schemeShadowSize { dict["shadow_size"] = Int(v) }
        if let v = schemeCornerRadius { dict["corner_radius"] = Int(v) }
        if let v = schemeHilitedCornerRadius { dict["hilited_corner_radius"] = Int(v) }
        if let v = schemeLineSpacing { dict["line_spacing"] = Int(v) }
        if let v = schemeSpacing { dict["spacing"] = Int(v) }
        if let v = schemeBorderHeight { dict["border_height"] = Int(v) }
        if let v = schemeBorderWidth { dict["border_width"] = Int(v) }
        dict.merge(unknownFields) { _, new in new }
        return dict
    }

    /// Whether this scheme has any style-level overrides (beyond colors).
    var hasStyleOverrides: Bool {
        schemeAlpha != nil || schemeTranslucency != nil || schemeMutualExclusive != nil
            || schemeShadowSize != nil || schemeCornerRadius != nil
            || schemeHilitedCornerRadius != nil || schemeLineSpacing != nil
            || schemeSpacing != nil || schemeBorderHeight != nil || schemeBorderWidth != nil
    }

    var parsedBackColor: Color { ColorScheme.parseHexColor(backColor) ?? .white }
    var parsedHilitedBack: Color { ColorScheme.parseHexColor(hilitedCandidateBackColor) ?? .orange }
    var parsedLabelColor: Color { ColorScheme.parseHexColor(labelColor) ?? .secondary }
    var parsedHilitedLabel: Color { ColorScheme.parseHexColor(hilitedCandidateLabelColor) ?? .white }
    var parsedCandidateText: Color { ColorScheme.parseHexColor(candidateTextColor) ?? .primary }
    var parsedHilitedCandidateText: Color { ColorScheme.parseHexColor(hilitedCandidateTextColor) ?? .white }
    var parsedCommentText: Color { ColorScheme.parseHexColor(commentTextColor) ?? .secondary }
    var parsedHilitedComment: Color { ColorScheme.parseHexColor(hilitedCommentTextColor) ?? .white }
    var parsedTextColor: Color { ColorScheme.parseHexColor(textColor) ?? .primary }
    var parsedHilitedText: Color { ColorScheme.parseHexColor(hilitedTextColor) ?? .orange }
    var parsedBorderColor: Color { ColorScheme.parseHexColor(borderColor) ?? .secondary.opacity(0.2) }
    var parsedShadowColor: Color { ColorScheme.parseHexColor(shadowColor) ?? .black.opacity(0.2) }

    private func stringValue(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let i = value as? Int {
            // If value fits in 6 hex digits, use 6-digit format (opaque)
            // Otherwise use 8-digit (with alpha)
            if i <= 0xFFFFFF {
                return String(format: "0x%06X", i)
            } else {
                return String(format: "0x%08X", i)
            }
        }
        return nil
    }
}

// MARK: - Notification Setting

enum ShowNotificationsWhen: String, CaseIterable {
    case always = "always"
    case never = "never"
    case appropriate = "appropriate"

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .never: return "Never"
        case .appropriate: return "Appropriate"
        }
    }
}

// MARK: - App Option Entry

struct AppOptionEntry: Identifiable {
    let id = UUID()
    var bundleID: String
    var noInline: Bool?
    var asciiMode: Bool?
    var vimMode: Bool?
    var unknownOptions: [String: Any] = [:]

    init(
        bundleID: String,
        noInline: Bool? = nil,
        asciiMode: Bool? = nil,
        vimMode: Bool? = nil,
        unknownOptions: [String: Any] = [:]
    ) {
        self.bundleID = bundleID
        self.noInline = noInline
        self.asciiMode = asciiMode
        self.vimMode = vimMode
        self.unknownOptions = unknownOptions
    }
}
