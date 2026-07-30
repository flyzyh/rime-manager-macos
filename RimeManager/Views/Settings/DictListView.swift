import SwiftUI

/// Dictionary management list view with enable/disable toggles.
struct DictListView: View {
    @EnvironmentObject private var appState: AppState

    private var dictSettings: DictSettings { appState.configManager.dictSettings }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            dictHeader

            if dictSettings.importTables.isEmpty {
                emptyState
            } else {
                dictList
            }
        }
        .navigationTitle("nav.dicts".localized)
    }

    // MARK: - Header

    private var dictHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("dict.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !dictSettings.schemaName.isEmpty {
                    Text("\(dictSettings.schemaName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Enable all / Disable all
            Menu {
                Button("dict.enable_all".localized) {
                    setAll(true)
                }
                Button("dict.disable_all".localized) {
                    setAll(false)
                }
            } label: {
                Label("dict.batch".localized, systemImage: "checklist")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "dict.empty_title".localized,
            systemImage: "books.vertical",
            description: Text("dict.empty_desc".localized)
        )
    }

    // MARK: - Dict List

    private var dictList: some View {
        List {
            ForEach(Array(dictSettings.importTables.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { dictSettings.importTables[index].enabled },
                        set: { dictSettings.importTables[index].enabled = $0 }
                    ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.body)
                            .strikethrough(!entry.enabled, color: .secondary)

                        Text(entry.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status indicator
                    Image(systemName: entry.enabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(entry.enabled ? Color.green : Color.gray.opacity(0.4))
                        .font(.callout)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func setAll(_ enabled: Bool) {
        for i in dictSettings.importTables.indices {
            dictSettings.importTables[i].enabled = enabled
        }
    }
}
