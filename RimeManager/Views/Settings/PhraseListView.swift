import SwiftUI

/// 自定义短语管理视图
struct PhraseListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newCode = ""
    @State private var newText = ""
    @State private var newWeight = "1"
    @State private var searchText = ""

    private var phraseSettings: PhraseSettings { appState.configManager.phraseSettings }

    private var filteredPhrases: [PhraseSettings.Phrase] {
        if searchText.isEmpty { return phraseSettings.phrases }
        return phraseSettings.phrases.filter {
            $0.code.localizedCaseInsensitiveContains(searchText)
            || $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            addRow

            if phraseSettings.phrases.isEmpty {
                ContentUnavailableView(
                    "phrase.empty_title".localized,
                    systemImage: "text.badge.plus",
                    description: Text("phrase.empty_desc".localized)
                )
            } else {
                phraseList
            }
        }
        .navigationTitle("nav.phrases".localized)
        .searchable(text: $searchText, prompt: "phrase.search".localized)
    }

    // MARK: - Add row

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("phrase.code_placeholder".localized, text: $newCode)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
            TextField("phrase.text_placeholder".localized, text: $newText)
                .textFieldStyle(.roundedBorder)
            TextField("1", text: $newWeight)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)

            Button(action: addPhrase) {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newCode.isEmpty || newText.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var phraseList: some View {
        List {
            ForEach(Array(filteredPhrases.enumerated()), id: \.element.id) { index, phrase in
                HStack(spacing: 12) {
                    Text(phrase.code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                        .frame(width: 100, alignment: .leading)

                    Text(phrase.text)
                        .font(.body)

                    Spacer()

                    // 权重调节
                    Stepper("", value: Binding(
                        get: { phraseSettings.phrases.firstIndex(where: { $0.id == phrase.id }).map { phraseSettings.phrases[$0].weight } ?? 1 },
                        set: { newValue in
                            if let idx = phraseSettings.phrases.firstIndex(where: { $0.id == phrase.id }) {
                                phraseSettings.phrases[idx].weight = newValue
                            }
                        }
                    ), in: 1...100)
                    .labelsHidden()

                    Text("\(phrase.weight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button("phrase.delete".localized, role: .destructive) {
                        phraseSettings.remove(id: phrase.id)
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { filteredPhrases[$0].id }
                for id in ids { phraseSettings.remove(id: id) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func addPhrase() {
        let weight = Int(newWeight) ?? 1
        phraseSettings.add(code: newCode.trimmingCharacters(in: .whitespaces),
                           text: newText.trimmingCharacters(in: .whitespaces),
                           weight: weight)
        newCode = ""
        newText = ""
        newWeight = "1"
    }
}
