import SwiftUI

/// Preview for dictionary definition files (.dict.yaml).
struct DictPreviewView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dictionary Info")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Parse the dictionary metadata
            if let meta = parseCurrentContent() {
                dictionaryMetadataContent(meta)
            } else {
                parsingFailedView
            }

            Divider()

            // Dictionary statistics
            dictionaryStats
        }
    }

    // MARK: - Metadata

    private func dictionaryMetadataContent(_ meta: DictMetadata) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let name = meta.name {
                dictInfoRow("Name", name)
            }
            if let version = meta.version {
                dictInfoRow("Version", version)
            }
            if let sort = meta.sort {
                dictInfoRow("Sort Order", sort)
            }
            if let usePreset = meta.usePresetVocabulary {
                dictInfoRow("Preset Vocab", usePreset ? "Yes" : "No")
            }

            if let tables = meta.importTables, !tables.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Imported Tables (\(tables.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(tables, id: \.self) { table in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text(table.trimmingCharacters(in: .whitespaces))
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
    }

    // MARK: - Statistics

    private var dictionaryStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let content = appState.editingContent
            let lines = content.components(separatedBy: "\n")
            let entries = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty
                    && !trimmed.hasPrefix("#")
                    && !trimmed.hasPrefix("---")
                    && !trimmed.hasPrefix("...")
                    && trimmed.contains("\t")
            }

            VStack(alignment: .leading, spacing: 4) {
                dictInfoRow("Total Lines", "\(lines.count)")
                dictInfoRow("Entries", "\(entries.count)")
                dictInfoRow("File Size",
                    ByteCountFormatter.string(
                        fromByteCount: Int64(content.utf8.count),
                        countStyle: .file
                    )
                )
            }

            // Sample entries
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sample Entries")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)

                    ForEach(entries.prefix(5), id: \.self) { entry in
                        Text(entry.trimmingCharacters(in: .whitespaces).prefix(60))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Parsing failed

    private var parsingFailedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.pages")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Unable to parse dictionary metadata")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func parseCurrentContent() -> DictMetadata? {
        let analyzer = SchemaAnalyzer()
        return analyzer.parseDictionaryMetadata(from: appState.editingContent)
    }

    private func dictInfoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    state.editingContent = """
    ---
    name: rime_mint
    version: "2025.07.06"
    sort: by_weight
    use_preset_vocabulary: false
    import_tables:
      - dicts/custom_simple
      - dicts/rime_mint.chars
      - dicts/rime_mint.base
      - dicts/rime_mint.ext
    ...
    中国	zhong guo
    中文	zhong wen
    """
    return DictPreviewView()
        .environmentObject(state)
        .padding()
        .frame(width: 280, height: 400)
}
