import SwiftUI

/// 自定义短语管理（custom_phrase.txt）
/// 格式：编码\t短语\t权重，每行一条，# 开头为注释
@MainActor
final class PhraseSettings: ObservableObject {
    @Published var phrases: [Phrase] = []
    @Published var fileName: String = "custom_phrase.txt"

    private var headerComments: [String] = []

    struct Phrase: Identifiable {
        let id = UUID()
        var code: String      // 编码，如 mima
        var text: String      // 短语，如 密码
        var weight: Int = 1   // 权重，越大越靠前
    }

    // MARK: - Load

    func load(from content: String, fileName: String = "custom_phrase.txt") {
        self.fileName = fileName
        headerComments = []
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
                    code: parts[0].trimmingCharacters(in: .whitespaces),
                    text: parts[1].trimmingCharacters(in: .whitespaces),
                    weight: weight
                ))
            } else {
                // 空格分隔格式
                let sp = line.split(separator: " ", maxSplits: 2)
                if sp.count >= 2 {
                    let weight = sp.count >= 3 ? (Int(sp[2]) ?? 1) : 1
                    items.append(Phrase(code: String(sp[0]), text: String(sp[1]), weight: weight))
                }
            }
        }
        phrases = items
    }

    // MARK: - CRUD

    func add(code: String, text: String, weight: Int = 1) {
        guard !code.isEmpty, !text.isEmpty else { return }
        phrases.append(Phrase(code: code, text: text, weight: weight))
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
        for p in phrases {
            lines.append("\(p.code)\t\(p.text)\t\(p.weight)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
