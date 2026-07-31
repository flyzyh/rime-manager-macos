import SwiftUI

/// Right-side preview panel that dynamically shows schema info or color scheme preview.
struct PreviewPanelView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            previewHeader

            // Content
            if let file = appState.selectedFile {
                previewContent(for: file)
            } else {
                noSelectionView
            }
        }
        .frame(minWidth: 180)
    }

    // MARK: - Header

    private var previewHeader: some View {
        HStack {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - No selection

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text("No file selected")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Select a configuration file\nto preview its contents.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview content

    @ViewBuilder
    private func previewContent(for file: RimeConfigFile) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                // File info section
                fileInfoSection(for: file)

                Divider()

                // Type-specific preview
                typeSpecificPreview(for: file)
            }
            .padding(12)
        }
    }

    // MARK: - File info

    private func fileInfoSection(for file: RimeConfigFile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("File Information")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 4) {
                infoRow("Name", file.name)
                infoRow("Type", file.fileType.displayName)
                if let size = file.fileSize {
                    infoRow("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                }
                if let date = file.modificationDate {
                    infoRow("Modified", date.formatted(date: .abbreviated, time: .shortened))
                }
                infoRow("Path", file.url.path)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Type-specific preview

    @ViewBuilder
    private func typeSpecificPreview(for file: RimeConfigFile) -> some View {
        switch file.fileType {
        case .schema:
            if let schema = appState.parsedSchema {
                SchemaPreviewView(schema: schema)
            } else {
                parsingFailedView
            }

        case .customPatch, .yaml:
            // For squirrel.yaml or other yaml files, show color schemes if available
            if !appState.colorSchemes.isEmpty {
                ColorSchemePreviewView(schemes: appState.colorSchemes)
            } else {
                rawYAMLSummaryView(file: file)
            }

        case .dictionary:
            DictPreviewView()

        case .lua:
            luaInfoView

        case .text, .json:
            rawTextInfoView(file: file)

        default:
            EmptyView()
        }
    }

    // MARK: - Parsing failed

    private var parsingFailedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Unable to parse schema")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("The file may have syntax errors or use an unsupported format.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    // MARK: - Raw YAML

    private func rawYAMLSummaryView(file: RimeConfigFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Preview")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(appState.editingContent.prefix(500))
                .font(.custom("SF Mono", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(20)
                .padding(8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Lua info

    private var luaInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lua Script")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Rime supports Lua extensions for custom processors, translators, and filters.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Show script summary
            let lines = appState.editingContent.components(separatedBy: "\n")
            let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            Text("\(nonEmptyLines.count) lines of code")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Detect function definitions
            let functions = lines.filter { $0.contains("function ") }
            if !functions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Functions detected:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(functions.prefix(10), id: \.self) { funcLine in
                        Text(funcLine.trimmingCharacters(in: .whitespaces).prefix(80))
                            .font(.custom("SF Mono", size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Show the script content
            Text(appState.editingContent.prefix(300))
                .font(.custom("SF Mono", size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(15)
                .padding(6)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Raw text

    private func rawTextInfoView(file: RimeConfigFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Content")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let lines = appState.editingContent.components(separatedBy: "\n")
            Text("\(lines.count) lines")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.editingContent.prefix(500))
                .font(.custom("SF Mono", size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(20)
                .padding(6)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    let url = URL(fileURLWithPath: "/tmp/test.schema.yaml")
    state.selectedFile = RimeConfigFile(url: url)
    return PreviewPanelView()
        .environmentObject(state)
        .frame(width: 300, height: 500)
}
