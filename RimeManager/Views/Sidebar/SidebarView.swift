import SwiftUI

/// Sidebar that displays the Rime configuration directory as a hierarchical file tree.
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            // File list
            if appState.rimeDirectoryURL == nil {
                emptyRimeState
            } else if appState.configFiles.isEmpty {
                emptyFilesState
            } else {
                fileList
            }
        }
        .frame(minWidth: 220)
        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 350)
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack {
            Label("Files", systemImage: "folder")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                Button(action: { appState.selectRimeDirectory() }) {
                    Label("Open Directory...", systemImage: "folder.badge.plus")
                }
                Button(action: { appState.reloadFiles() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Divider()
                Button(action: { appState.deployRime() }) {
                    Label("Deploy Rime", systemImage: "arrow.triangle.2.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Empty states

    private var emptyRimeState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text("No Rime directory selected")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Open Directory...") {
                appState.selectRimeDirectory()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFilesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text("No config files found")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("The directory appears to be empty\nor doesn't contain Rime config files.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File list

    private var fileList: some View {
        List(selection: $appState.selectedFile) {
            ForEach(appState.configFiles, id: \.id) { file in
                FileTreeRow(file: file, level: 0)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - File Tree Row

struct FileTreeRow: View {
    let file: RimeConfigFile
    let level: Int

    var body: some View {
        if file.isDirectory, let children = file.children, !children.isEmpty {
            DisclosureGroup {
                ForEach(children, id: \.id) { child in
                    FileTreeRow(file: child, level: level + 1)
                }
            } label: {
                fileRowLabel
            }
        } else {
            fileRowLabel
                .padding(.leading, CGFloat(level) * 16)
        }
    }

    private var fileRowLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: file.fileType.sfSymbol)
                .font(.callout)
                .foregroundStyle(fileColor)
                .frame(width: 18)

            Text(file.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Badge for file type
            if !file.isDirectory && file.fileType != .unknown {
                Text(file.fileType.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.vertical, 1)
        .contextMenu {
            if !file.isDirectory {
                Button("Open in External Editor") {
                    NSWorkspace.shared.open(file.url)
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                }
                Divider()
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.url.path, forType: .string)
                }
            }
        }
        .tag(file)
    }

    private var fileColor: Color {
        switch file.fileType {
        case .schema:       return .orange
        case .customPatch:  return .blue
        case .dictionary:   return .green
        case .lua:          return .purple
        case .yaml:         return .indigo
        case .text:         return .secondary
        case .json:         return .teal
        case .directory:    return .accentColor
        case .unknown:      return .secondary
        }
    }
}

// MARK: - Preview

// Preview removed - view will be integrated into FileEditorView
