import SwiftUI

/// File editor view integrating file tree sidebar, code editor, and preview panel.
/// Reuses existing SidebarView, EditorView, and PreviewPanelView components.
struct FileEditorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPreview = true

    var body: some View {
        HSplitView {
            // Left: File tree
            SidebarView()
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 350)

            // Center: Editor
            editorPane
                .frame(minWidth: 300)

            // Right: Preview (toggleable)
            if showPreview {
                PreviewPanelView()
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 450)
            }
        }
        .navigationTitle("nav.files".localized)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showPreview) {
                    Label("files.toggle_preview".localized, systemImage: "eye")
                }
                .toggleStyle(.button)
            }
        }
    }

    // MARK: - Editor Pane

    @ViewBuilder
    private var editorPane: some View {
        if appState.selectedFile != nil {
            EditorView()
        } else {
            noFileSelected
        }
    }

    private var noFileSelected: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)

            Text("files.no_selection".localized)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("files.no_selection_desc".localized)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
