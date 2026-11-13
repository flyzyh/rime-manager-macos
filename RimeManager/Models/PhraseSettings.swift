import SwiftUI

/// 自定义短语管理（custom_phrase.txt）
/// Rime/oh-my-rime 格式：短语\t编码\t权重，每行一条，# 开头为注释
@MainActor
final class PhraseSettings: ObservableObject {
    @Published var phrases: [Phrase] = []
    @Published var fileName: String = "custom_phrase.txt"
    @Published var schemaSupportsCustomPhrase = false
    @Published var installIntoCurrentSchemaRequested = false

    private var headerComments: [String] = []
    private var invalidLines: [String] = []
    private var schemaTranslatorNames: Set<String> = []

    struct Phrase: Identifiable {
        let id = UUID()
        var text: String      // 短语，如 密码
        var code: String      // 编码，如 mima
        var weight: Int = 1   // 权重，越大越靠前
    }

    func setSchemaSupport(_ supported: Bool, translatorNames: Set<String> = []) {
        schemaSupportsCustomPhrase = supported
        schemaTranslatorNames = translatorNames
        if supported { installIntoCurrentSchemaRequested = false }
    }

    func installIntoCurrentSchema() {
        installIntoCurrentSchemaRequested = true
    }

    func customPhraseSchemaPatch(currentTranslators: [String], hasExistingTranslatorPatch: Bool) -> [String: Any] {
        guard installIntoCurrentSchemaRequested, !schemaSupportsCustomPhrase else { return [:] }
        var patch: [String: Any] = ["custom_phrase/user_dict": "custom_phrase"]
        if currentTranslators.contains("table_translator@custom_phrase") {
            return patch
        }
        if hasExistingTranslatorPatch {
            patch["engine/translators"] = currentTranslators + ["table_translator@custom_phrase"]
        } else {
            patch["engine/translators/+"] = ["table_translator@custom_phrase"]
        }
        return patch
    }

    // MARK: - Load

    func load(from content: String, fileName: String = "custom_phrase.txt") {
        self.fileName = fileName
        headerComments = []
        invalidLines = []
        var items: [Phrase] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") {
                headerComments.append(line)
                continue
            }
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 2 {
                let weight = parts.count >= 3 ? (Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1) : 1
                items.append(Phrase(
                    text: parts[0].trimmingCharacters(in: .whitespaces),
                    code: parts[1].trimmingCharacters(in: .whitespaces),
                    weight: weight
                ))
            } else {
                // 空格分隔格式；第一列短语可包含空格，因此第二个空格后是编码+权重。
                let sp = line.split(separator: " ", maxSplits: 2)
                if sp.count >= 2 {
                    // 无 tab 时优先按“短语 编码 权重”解析；编码本身不含空格。
                    let tail = String(sp.count >= 3 ? sp[2] : sp[1]).trimmingCharacters(in: .whitespaces)
                    let tailParts = tail.components(separatedBy: .whitespacesAndNewlines)
                    let code = tailParts.first ?? ""
                    let weight = tailParts.count > 1 ? (Int(tailParts[1]) ?? 1) : 1
                    if !code.isEmpty {
                        items.append(Phrase(text: String(sp[0]), code: code, weight: weight))
                    } else {
                        invalidLines.append(line)
                    }
                } else {
                    invalidLines.append(line)
                }
            }
        }
        phrases = items
    }

    // MARK: - CRUD

    func add(text: String, code: String, weight: Int = 1) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty, !cleanText.isEmpty,
              !cleanCode.contains("\t"), !cleanText.contains("\t") else { return }
        phrases.append(Phrase(text: cleanText, code: cleanCode, weight: weight))
    }

    func remove(at offsets: IndexSet) {
        phrases.remove(atOffsets: offsets)
    }

    func remove(id: UUID) {
        phrases.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        phrases.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Generate

    func generateContent() -> String {
        var lines = headerComments
        lines.append(contentsOf: invalidLines.map { "# " + $0 })
        for p in phrases {
            lines.append("\(p.text)\t\(p.code)\t\(p.weight)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
