import SwiftUI

/// Live preview of the candidate window appearance.
struct CandidatePreviewView: View {
    @ObservedObject var config: SquirrelConfig
    @ObservedObject var inputSettings: InputSettings
    @Binding var isDark: Bool

    private var scheme: EditableColorScheme? {
        config.effectiveScheme(isDark: isDark)
    }

    var body: some View {
        // Candidate window preview
        candidateWindow
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var candidateWindow: some View {
        let allWords = ["中文", "中国", "重要", "终于", "重量", "种类", "重点", "终点", "众多"]
        let words = Array(allWords.prefix(inputSettings.candidateCount))

        return HStack(spacing: 2) {
            // Input text
            HStack(spacing: 2) {
                Text("zhong")
                    .font(.system(size: config.fontPoint))
                    .foregroundColor(scheme?.parsedTextColor ?? .primary)
                Rectangle()
                    .fill(scheme?.parsedHilitedText ?? .orange)
                    .frame(width: 2, height: config.fontPoint)
            }

            // Candidates
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                HStack(spacing: 2) {
                    Text("\(i + 1).")
                        .font(.system(size: max(config.labelFontPoint, 11)))
                        .foregroundColor(i == 0 ? scheme?.parsedHilitedLabel : scheme?.parsedLabelColor ?? .secondary)
                    Text(word)
                        .font(.system(size: config.fontPoint))
                        .foregroundColor(i == 0 ? scheme?.parsedHilitedCandidateText : scheme?.parsedCandidateText ?? .primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background {
                    if i == 0 {
                        (scheme?.parsedHilitedBack ?? .orange)
                            .clipShape(RoundedRectangle(cornerRadius: config.hilitedCornerRadius))
                    }
                }
            }
        }
        .padding(6)
        .fixedSize(horizontal: true, vertical: false)
        .background(scheme?.parsedBackColor ?? Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .stroke(scheme?.parsedBorderColor ?? .secondary.opacity(0.2))
        )
        .opacity(config.alpha)
    }
}
