import SwiftUI

/// Schema management list view with toggle and default selection.
struct SchemaListView: View {
    @EnvironmentObject private var appState: AppState

    private var schemaSettings: SchemaSettings { appState.configManager.schemaSettings }

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            schemaHeader

            if schemaSettings.availableSchemas.isEmpty {
                emptyState
            } else {
                schemaList
            }
        }
        .navigationTitle("nav.schemas".localized)
    }

    // MARK: - Header

    private var schemaHeader: some View {
        HStack {
            Text("schema.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                if let dir = appState.rimeDirectoryURL {
                    schemaSettings.scanSchemas(in: dir)
                }
            }) {
                Label("schema.refresh".localized, systemImage: "arrow.clockwise")
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
            "schema.empty_title".localized,
            systemImage: "list.bullet.rectangle",
            description: Text("schema.empty_desc".localized)
        )
    }

    // MARK: - Schema List

    private var schemaList: some View {
        List {
            ForEach(SchemaSettings.SchemaCategory.allCases, id: \.self) { category in
                let schemas = schemaSettings.availableSchemas.filter { $0.category == category }
                if !schemas.isEmpty {
                    Section(category.rawValue) {
                        ForEach(schemas) { schema in
                            SchemaRow(
                                schema: schema,
                                isEnabled: schemaSettings.enabledSchemaIDs.contains(schema.id),
                                isDefault: schemaSettings.isDefault(schema.id),
                                onToggle: { schemaSettings.toggleSchema(schema.id) },
                                onSetDefault: { schemaSettings.setDefault(schema.id) }
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Schema Row

struct SchemaRow: View {
    let schema: SchemaSettings.SchemaInfo
    let isEnabled: Bool
    let isDefault: Bool
    let onToggle: () -> Void
    let onSetDefault: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Enable toggle
            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .labelsHidden()

            // Schema info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(schema.name)
                        .font(.body)
                        .fontWeight(isDefault ? .semibold : .regular)

                    if isDefault {
                        Text("schema.default_badge".localized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                }

                Text(schema.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Set default button
            if isEnabled && !isDefault {
                Button("schema.set_default".localized) {
                    onSetDefault()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
