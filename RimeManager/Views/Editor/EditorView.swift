import SwiftUI

/// Text editor for Rime configuration files with syntax highlighting support.
struct EditorView: View {
    @EnvironmentObject private var appState: AppState

    @AppStorage("showLineNumbers") private var showLineNumbers = true
    @AppStorage("editorFontSize") private var editorFontSize = 13.0
    @AppStorage("highlightYAMLSyntax") private var highlightYAMLSyntax = true

    @State private var textContent: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            editorToolbar

            // Editor
            if let file = appState.selectedFile {
                editorContent(for: file)
            }
        }
        .onAppear {
            textContent = appState.editingContent
        }
        .onChange(of: appState.selectedFile?.id) { _, _ in
            textContent = appState.editingContent
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 8) {
            if let file = appState.selectedFile {
                // File info
                HStack(spacing: 4) {
                    Image(systemName: file.fileType.sfSymbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(file.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    if let size = file.fileSize {
                        Text("- \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Unsaved indicator
                if appState.hasUnsavedChanges {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 7, height: 7)
                        Text("Edited")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Format selector
                Picker("Format", selection: .constant(file.fileType)) {
                    ForEach(FileType.allCases.filter { $0.isEditable }, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .disabled(true)

                // Actions
                HStack(spacing: 2) {
                    // Toggle line numbers
                    Button {
                        showLineNumbers.toggle()
                    } label: {
                        Image(systemName: showLineNumbers ? "list.number" : "list.bullet")
                    }
                    .help("Toggle line numbers")

                    // Format/Validate
                    Button {
                        validateYAML()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Validate YAML syntax")

                    // Save
                    Button {
                        saveContent()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Save changes (⌘S)")
                    .keyboardShortcut("s", modifiers: .command)

                    // Open in external editor
                    Button {
                        NSWorkspace.shared.open(file.url)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .help("Open in external editor")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Editor content

    @ViewBuilder
    private func editorContent(for file: RimeConfigFile) -> some View {
        if highlightYAMLSyntax && (file.fileType == .schema || file.fileType == .customPatch || file.fileType == .yaml || file.fileType == .dictionary) {
            // Syntax highlighted editor (NSTextView wrapped)
            HighlightedEditorView(
                text: $textContent,
                fontSize: editorFontSize,
                showLineNumbers: showLineNumbers,
                onTextChange: { newValue in
                    appState.fileContentDidChange(newValue)
                }
            )
        } else {
            // Plain text editor
            plainTextEditor
        }
    }

    // MARK: - Plain editor

    private var plainTextEditor: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                if showLineNumbers {
                    lineNumberGutter
                }
                TextEditor(text: $textContent)
                    .font(.custom("SF Mono", size: editorFontSize))
                    .monospaced()
                    .scrollIndicators(.never)
                    .focused($isFocused)
                    .onChange(of: textContent) { _, newValue in
                        appState.fileContentDidChange(newValue)
                    }
            }
        }
    }

    // MARK: - Line number gutter (plain text only)

    private var lineNumberGutter: some View {
        let lines = textContent.components(separatedBy: "\n")

        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.custom("SF Mono", size: editorFontSize - 1))
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 32, alignment: .trailing)
                    .padding(.trailing, 8)
            }
        }
        .padding(.top, 5)
        .background(.background.tertiary)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 0.5)
        }
    }

    // MARK: - Actions

    private func saveContent() {
        appState.editingContent = textContent
        appState.saveCurrentFile()
    }

    private func validateYAML() {
        // Use YAMS to validate
        let service = YAMLParseService()
        let result = service.validate(textContent)

        switch result {
        case .success:
            let alert = NSAlert()
            alert.messageText = "YAML Valid"
            alert.informativeText = "The YAML syntax is valid."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .failure(let error):
            let alert = NSAlert()
            alert.messageText = "YAML Validation Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    let url = URL(fileURLWithPath: "/tmp/test.schema.yaml")
    state.selectedFile = RimeConfigFile(url: url)
    state.editingContent = """
    schema:
      schema_id: rime_mint
      name: 薄荷拼音-全拼输入
      version: "24.11.11"

    switches:
      - name: ascii_mode
        reset: 0
        states: [ 中文, 英文 ]
      - name: emoji_suggestion
        states: [ "😣️", "😁️" ]
        reset: 1
    """
    return EditorView()
        .environmentObject(state)
        .frame(width: 500, height: 400)
}
