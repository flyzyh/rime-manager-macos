import SwiftUI

/// Structured preview of a parsed Rime schema.
struct SchemaPreviewView: View {
    let schema: RimeSchema

    @State private var expandedSections: Set<String> = ["metadata", "switches", "engine"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metadata section
            schemaSection(
                id: "metadata",
                title: "Schema Info",
                icon: "info.circle",
                color: .blue
            ) {
                schemaMetadataContent
            }

            // Switches section
            if !schema.switches.isEmpty {
                schemaSection(
                    id: "switches",
                    title: "Switches",
                    icon: "switch.2",
                    color: .orange
                ) {
                    switchesContent
                }
            }

            // Engine section
            if !schema.processors.isEmpty || !schema.translators.isEmpty {
                schemaSection(
                    id: "engine",
                    title: "Engine",
                    icon: "engine.combustion",
                    color: .green
                ) {
                    engineContent
                }
            }

            // Speller section
            if schema.alphabet != nil || schema.maxCodeLength != nil {
                schemaSection(
                    id: "speller",
                    title: "Speller",
                    icon: "character.book.closed",
                    color: .purple
                ) {
                    spellerContent
                }
            }

            // Translator section
            if schema.dictionaryName != nil {
                schemaSection(
                    id: "translator",
                    title: "Translator",
                    icon: "arrow.triangle.branch",
                    color: .teal
                ) {
                    translatorContent
                }
            }

            // Key bindings
            if !schema.keyBindings.isEmpty {
                schemaSection(
                    id: "bindings",
                    title: "Key Bindings",
                    icon: "keyboard",
                    color: .indigo
                ) {
                    keyBindingsContent
                }
            }

            // Recognizer patterns
            if !schema.recognizerPatterns.isEmpty {
                schemaSection(
                    id: "recognizer",
                    title: "Recognizer Patterns",
                    icon: "magnifyingglass",
                    color: .pink
                ) {
                    recognizerContent
                }
            }

            // ASCII Composer
            if schema.goodOldCapsLock != nil || !schema.switchKey.isEmpty {
                schemaSection(
                    id: "ascii",
                    title: "ASCII Composer",
                    icon: "textformat.abc",
                    color: .mint
                ) {
                    asciiComposerContent
                }
            }

            // Style
            if schema.colorScheme != nil || schema.fontFace != nil {
                schemaSection(
                    id: "style",
                    title: "Style",
                    icon: "paintpalette",
                    color: .pink
                ) {
                    styleContent
                }
            }

            // Patch info
            if schema.isPatchFile {
                schemaSection(
                    id: "patch",
                    title: "Patch Info",
                    icon: "bandage",
                    color: .blue
                ) {
                    patchContent
                }
            }
        }
    }

    // MARK: - Schema section wrapper

    @ViewBuilder
    private func schemaSection<Content: View>(
        id: String,
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: binding(for: id)) {
            content()
                .padding(.leading, 8)
                .padding(.bottom, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(id)
                } else {
                    expandedSections.remove(id)
                }
            }
        )
    }

    // MARK: - Metadata content

    private var schemaMetadataContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = schema.name {
                metaRow("Name", name)
            }
            if let id = schema.schemaID {
                metaRow("Schema ID", id)
            }
            if let version = schema.version {
                metaRow("Version", version)
            }
            if let author = schema.author, !author.isEmpty {
                metaRow("Author", author.joined(separator: ", "))
            }
            if let deps = schema.dependencies, !deps.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    metaRow("Dependencies", "")
                    ForEach(deps, id: \.self) { dep in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text(dep.trimmingCharacters(in: .whitespaces))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 12)
                    }
                }
            }
            if let desc = schema.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Description:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Switches content

    private var switchesContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(schema.switches, id: \.id) { sw in
                HStack(spacing: 6) {
                    Circle()
                        .fill(sw.reset == 0 ? .green : .secondary)
                        .frame(width: 6, height: 6)

                    Text(sw.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    // State pills
                    ForEach(Array(sw.states.enumerated()), id: \.offset) { index, state in
                        StatePillView(
                            text: state.trimmingCharacters(in: .whitespaces),
                            isActive: index == sw.reset
                        )
                    }
                }
                .padding(.vertical, 2)

                if sw.name != schema.switches.last?.name {
                    Divider()
                }
            }
        }
    }

    // MARK: - Engine content

    private var engineContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            engineListSection("Processors", schema.processors, color: .blue)
            engineListSection("Segmentors", schema.segmentors, color: .green)
            engineListSection("Translators", schema.translators, color: .orange)
            engineListSection("Filters", schema.filters, color: .purple)
        }
    }

    @ViewBuilder
    private func engineListSection(_ title: String, _ items: [String], color: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                    Text("\(title) (\(items.count))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 4) {
                        Text("\(index + 1).")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, alignment: .trailing)
                        Text(item.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 10))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 12)
                }
            }
        }
    }

    // MARK: - Speller content

    private var spellerContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let alphabet = schema.alphabet {
                metaRow("Alphabet", alphabet)
            }
            if let initials = schema.initials {
                metaRow("Initials", initials)
            }
            if let finals = schema.finals {
                metaRow("Finals", finals)
            }
            if let maxLen = schema.maxCodeLength {
                metaRow("Max Code Length", "\(maxLen)")
            }
            if let autoSelect = schema.autoSelect {
                metaRow("Auto Select", autoSelect ? "Yes" : "No")
            }
            if let delimiter = schema.delimiter {
                metaRow("Delimiter", "'\(delimiter)'")
            }
        }
    }

    // MARK: - Translator content

    private var translatorContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let dict = schema.dictionaryName {
                metaRow("Dictionary", dict)
            }
            if let completion = schema.enableCompletion {
                metaRow("Completion", completion ? "Enabled" : "Disabled")
            }
            if let sentence = schema.enableSentence {
                metaRow("Sentence", sentence ? "Enabled" : "Disabled")
            }
            if let userDict = schema.enableUserDict {
                metaRow("User Dictionary", userDict ? "Enabled" : "Disabled")
            }
        }
    }

    // MARK: - Key bindings

    private var keyBindingsContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(schema.keyBindings.enumerated()), id: \.offset) { index, binding in
                HStack(spacing: 4) {
                    Text("\(index + 1).")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, alignment: .trailing)
                    Text(bindingDescription(binding))
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func bindingDescription(_ binding: [String: Any]) -> String {
        var parts: [String] = []
        if let when = binding["when"] as? String { parts.append("when:\(when)") }
        if let accept = binding["accept"] as? String { parts.append("accept:\(accept)") }
        if let send = binding["send"] as? String { parts.append("send:\(send)") }
        if let toggle = binding["toggle"] as? String { parts.append("toggle:\(toggle)") }
        return parts.isEmpty ? "\(binding)" : parts.joined(separator: ", ")
    }

    // MARK: - Recognizer patterns

    private var recognizerContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(schema.recognizerPatterns.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 10, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("→")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(value)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - ASCII Composer

    private var asciiComposerContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let capsLock = schema.goodOldCapsLock {
                metaRow("Caps Lock", capsLock ? "Good old style" : "Standard")
            }
            if !schema.switchKey.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switch Keys:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(schema.switchKey.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        HStack(spacing: 6) {
                            Text(key)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(width: 80, alignment: .leading)
                            Text("→")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(value)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
    }

    // MARK: - Style

    private var styleContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cs = schema.colorScheme {
                metaRow("Light Scheme", cs)
            }
            if let csDark = schema.colorSchemeDark {
                metaRow("Dark Scheme", csDark)
            }
            if let msgType = schema.statusMessageType {
                metaRow("Status Msg", msgType)
            }
            if let fmt = schema.candidateFormat {
                metaRow("Cand Format", fmt)
            }
            if let orient = schema.textOrientation {
                metaRow("Orientation", orient)
            }
            if let inline = schema.inlinePreedit {
                metaRow("Inline Preedit", inline ? "Yes" : "No")
            }
            if let inlineCand = schema.inlineCandidate {
                metaRow("Inline Candidate", inlineCand ? "Yes" : "No")
            }
            if let translucency = schema.translucency {
                metaRow("Translucency", translucency ? "Yes" : "No")
            }
            if let blur = schema.blurEnabled {
                metaRow("Blur", blur ? "Yes" : "No")
            }
            if let radius = schema.cornerRadius {
                metaRow("Corner Radius", "\(Int(radius))")
            }
            if let face = schema.fontFace {
                metaRow("Font", "\(face) \(Int(schema.fontPoint ?? 16))pt")
            }
            if let labelFace = schema.labelFontFace {
                metaRow("Label Font", "\(labelFace) \(Int(schema.labelFontPoint ?? 12))pt")
            }
        }
    }

    // MARK: - Patch

    private var patchContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This is a custom patch file that overrides the following keys:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(schema.patchKeys, id: \.self) { key in
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.leading, 8)
            }
        }
    }

    // MARK: - Helpers

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - State Pill

private struct StatePillView: View {
    let text: String
    let isActive: Bool

    private var bgColor: Color {
        if isActive {
            return .accentColor
        } else {
            return Color(nsColor: .quaternaryLabelColor)
        }
    }

    private var fgColor: Color {
        if isActive {
            return .white
        } else {
            return .secondary
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(fgColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(bgColor)
            )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SchemaPreviewView(schema: RimeSchema(
            schemaID: "rime_mint",
            name: "薄荷拼音-全拼输入",
            version: "24.11.11",
            author: ["mintimate"],
            description: "Mintimate的薄荷拼音方案",
            switches: [
                SchemaSwitch(name: "ascii_mode", reset: 0, states: ["中文", "英文"]),
                SchemaSwitch(name: "emoji_suggestion", reset: 1, states: ["😣️", "😁️"]),
                SchemaSwitch(name: "transcription", reset: 0, states: ["简体", "繁体"]),
            ],
            processors: ["ascii_composer", "recognizer", "key_binder", "speller", "punctuator", "selector", "navigator"],
            segmentors: ["ascii_segmentor", "matcher", "abc_segmentor", "punct_segmentor", "fallback_segmentor"],
            translators: ["punct_translator", "script_translator", "table_translator@melt_eng"],
            filters: ["simplifier@emoji_suggestion", "simplifier@transcription_cc", "uniquifier"]
        ))
        .padding()
    }
    .frame(width: 300, height: 600)
}
