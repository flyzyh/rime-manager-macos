import SwiftUI

/// 标点符号映射编辑器
struct PunctuatorEditorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection: PunctSection = .half
    @State private var newKey = ""
    @State private var newCommit = ""

    enum PunctSection: String, CaseIterable {
        case half = "半角"
        case full = "全角"

        var title: String {
            switch self {
            case .half: return "punct.half".localized
            case .full: return "punct.full".localized
            }
        }
    }

    private var punct: PunctuatorSettings { appState.configManager.punctuatorSettings }

    private var currentEntries: [PunctuatorSettings.PunctEntry] {
        selectedSection == .half ? punct.halfShape : punct.fullShape
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header + section picker
            HStack {
                Picker("", selection: $selectedSection) {
                    ForEach(PunctSection.allCases, id: \.self) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)

                Spacer()

                Text("punct.hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Add row
            HStack(spacing: 8) {
                TextField("punct.key_placeholder".localized, text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                TextField("punct.value_placeholder".localized, text: $newCommit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button(action: addEntry) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newKey.isEmpty || newCommit.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // List
            List {
                ForEach(currentEntries) { entry in
                    HStack(spacing: 12) {
                        Text(entry.key)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                            .frame(width: 60, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        TextField("", text: binding(for: entry, in: currentEntries))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)

                        if entry.isPair {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("punct.delete".localized, role: .destructive) {
                            removeEntry(entry)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { currentEntries[$0].id }
                    for id in ids { removeByID(id) }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .navigationTitle("nav.punct".localized)
    }

    // MARK: - Bindings

    private func binding(for entry: PunctuatorSettings.PunctEntry, in list: [PunctuatorSettings.PunctEntry]) -> Binding<String> {
        Binding(
            get: { entry.commit },
            set: { newValue in
                if selectedSection == .half {
                    if let idx = punct.halfShape.firstIndex(where: { $0.id == entry.id }) {
                        punct.halfShape[idx].commit = newValue
                    }
                } else {
                    if let idx = punct.fullShape.firstIndex(where: { $0.id == entry.id }) {
                        punct.fullShape[idx].commit = newValue
                    }
                }
            }
        )
    }

    private func addEntry() {
        if selectedSection == .half {
            punct.addEntry(to: &punct.halfShape, key: newKey, commit: newCommit)
        } else {
            punct.addEntry(to: &punct.fullShape, key: newKey, commit: newCommit)
        }
        newKey = ""
        newCommit = ""
    }

    private func removeEntry(_ entry: PunctuatorSettings.PunctEntry) {
        removeByID(entry.id)
    }

    private func removeByID(_ id: UUID) {
        if selectedSection == .half {
            punct.removeEntry(from: &punct.halfShape, id: id)
        } else {
            punct.removeEntry(from: &punct.fullShape, id: id)
        }
    }
}
