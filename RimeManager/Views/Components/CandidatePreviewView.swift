import SwiftUI

/// Live preview of the candidate window appearance.
/// Accurately mirrors Squirrel rendering behavior.
struct CandidatePreviewView: View {
    @ObservedObject var config: SquirrelConfig
    @ObservedObject var inputSettings: InputSettings
    @Binding var isDark: Bool

    private var scheme: EditableColorScheme? {
        config.effectiveScheme(isDark: isDark)
    }

    private var isVertical: Bool {
        config.textOrientation == .vertical || config.candidateListLayout == .stacked
    }

    var body: some View {
        candidateWindow
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 0)
    }

    private var candidateWindow: some View {
        let allWords = ["暗暗", "安安", "嗷嗷", "氨水", "爱爱", "暗暗", "哎哎", "安安", "暗暗"]
        let words = Array(allWords.prefix(inputSettings.candidateCount))

        return VStack(alignment: .leading, spacing: 0) {
            // Preedit line (only when not inline)
            if !config.inlinePreedit {
                preeditLine
                    .padding(.bottom, CGFloat(max(config.spacing, 4)))
            }

            // Candidates
            if isVertical {
                verticalCandidates(words)
            } else {
                horizontalCandidates(words)
            }

            // Paging indicator
            if config.showPaging {
                pagingIndicator
                    .padding(.top, 4)
            }
        }
        .padding(CGFloat(max(Int(config.borderHeight), 6)))
        .background(scheme?.parsedBackColor ?? Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .stroke(scheme?.parsedBorderColor ?? .secondary.opacity(0.2))
        )
        .opacity(config.alpha)
    }

    // MARK: - Preedit

    private var preeditLine: some View {
        HStack(spacing: 0) {
            Text("a a s da s d")
                .font(.system(size: config.fontPoint))
                .foregroundColor(scheme?.parsedTextColor ?? .primary)
            Rectangle()
                .fill(scheme?.parsedHilitedText ?? .orange)
                .frame(width: 1.5, height: config.fontPoint + 2)
        }
    }

    // MARK: - Horizontal (linear) layout with wrapping

    private func horizontalCandidates(_ words: [String]) -> some View {
        FlowLayout(
            spacing: CGFloat(max(config.spacing, 2)),
            lineSpacing: CGFloat(max(config.lineSpacing, 2))
        ) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                candidateItem(index: i, word: word)
            }
        }
    }

    // MARK: - Vertical (stacked) layout

    private func verticalCandidates(_ words: [String]) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(max(config.lineSpacing, 2))) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                candidateItem(index: i, word: word)
            }
        }
    }

    // MARK: - Single candidate item

    private func candidateItem(index i: Int, word: String) -> some View {
        let formatted = formatCandidate(index: i + 1, text: word)

        return HStack(spacing: 0) {
            // Label part
            Text(formatted.label)
                .font(.system(size: max(config.labelFontPoint, 11)))
                .foregroundColor(i == 0
                    ? (scheme?.parsedHilitedLabel ?? .white)
                    : (scheme?.parsedLabelColor ?? .secondary))

            // Candidate text part
            Text(formatted.text)
                .font(.system(size: config.fontPoint))
                .foregroundColor(i == 0
                    ? (scheme?.parsedHilitedCandidateText ?? .white)
                    : (scheme?.parsedCandidateText ?? .primary))

            // Comment (simulated)
            if i == 2 {
                Text("  注释")
                    .font(.system(size: config.commentFontPoint))
                    .foregroundColor(i == 0
                        ? (scheme?.parsedHilitedComment ?? .white)
                        : (scheme?.parsedCommentText ?? .secondary))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background {
            if i == 0 {
                (scheme?.parsedHilitedBack ?? .orange)
                    .clipShape(RoundedRectangle(cornerRadius: config.hilitedCornerRadius))
            }
        }
    }

    // MARK: - Paging indicator

    private var pagingIndicator: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10))
                    .foregroundColor(scheme?.parsedLabelColor ?? .secondary)
                Text("1/2")
                    .font(.system(size: 10))
                    .foregroundColor(scheme?.parsedLabelColor ?? .secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(scheme?.parsedLabelColor ?? .secondary)
            }
            Spacer()
        }
    }

    // MARK: - Format parsing

    private func formatCandidate(index: Int, text: String) -> (label: String, text: String) {
        let format = config.candidateFormat
        // Parse format string: %c = label number, %@ = candidate text
        // Common formats: "%c. %@", "%c\u2005%@\u2005", "%c %@ "
        let labelStr = "\(index)"

        // Split by %c and %@
        var result = format
        result = result.replacingOccurrences(of: "%c", with: "⟨LABEL⟩")
        result = result.replacingOccurrences(of: "%@", with: "⟨TEXT⟩")

        let parts = result.components(separatedBy: "⟨LABEL⟩")
        var label = labelStr
        var candidateText = text

        if parts.count == 2 {
            let afterLabel = parts[1]
            if let textRange = afterLabel.range(of: "⟨TEXT⟩") {
                let separator = String(afterLabel[afterLabel.startIndex..<textRange.lowerBound])
                let suffix = String(afterLabel[textRange.upperBound...])
                label = labelStr + separator
                candidateText = text + suffix
            } else {
                label = labelStr
                candidateText = afterLabel.replacingOccurrences(of: "⟨TEXT⟩", with: text)
            }
        }

        // Clean up any remaining format markers
        label = label.replacingOccurrences(of: "⟨TEXT⟩", with: "")
        candidateText = candidateText.replacingOccurrences(of: "⟨LABEL⟩", with: "")

        return (label, candidateText)
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(size)
            currentRowWidth += size.width + spacing
        }

        let totalHeight = rows.reduce(0) { $0 + ($1.map(\.height).max() ?? 0) }
            + CGFloat(rows.count - 1) * lineSpacing
        let totalWidth = rows.map { row in
            row.reduce(0) { $0 + $1.width } + CGFloat(max(row.count - 1, 0)) * spacing
        }.max() ?? 0

        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
