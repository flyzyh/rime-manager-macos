import SwiftUI

/// Live preview of Rime color schemes (squirrel themes).
struct ColorSchemePreviewView: View {
    let schemes: [ColorScheme]

    @State private var selectedSchemeID: UUID?
    @State private var sampleInput: String = "zhong"
    @State private var sampleCandidates: [String] = [
        "1. 中文", "2. 中国", "3. 重要", "4. 终于", "5. 重量"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Color Schemes")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Scheme picker
            if schemes.count > 1 {
                Picker("Scheme", selection: $selectedSchemeID) {
                    ForEach(schemes) { scheme in
                        HStack {
                            Circle()
                                .fill(scheme.isDark ? .black : .white)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                            Text(scheme.name)
                        }
                        .tag(scheme.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Live preview
            if let selectedID = selectedSchemeID,
               let scheme = schemes.first(where: { $0.id == selectedID }) {
                schemePreviewCard(scheme)
            } else if let firstScheme = schemes.first {
                schemePreviewCard(firstScheme)
                    .onAppear { selectedSchemeID = firstScheme.id }
            }

            // Input field
            VStack(alignment: .leading, spacing: 4) {
                Text("Test Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Pinyin input...", text: $sampleInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
    }

    // MARK: - Preview card

    @ViewBuilder
    private func schemePreviewCard(_ scheme: ColorScheme) -> some View {
        VStack(spacing: 0) {
            // Candidate window preview
            VStack(alignment: .leading, spacing: 0) {
                // Preedit area (input text)
                HStack {
                    Text(sampleInput)
                        .font(previewFont(scheme, size: scheme.fontPoint ?? 18))
                        .foregroundColor(scheme.textColor ?? .primary)

                    if scheme.isDark {
                        Rectangle()
                            .fill(scheme.hilitedTextColor ?? .orange)
                            .frame(width: 2, height: 16)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(scheme.isDark ? .clear : .clear)

                // Separator
                Rectangle()
                    .fill(scheme.borderColor ?? .secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                // Candidates
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(sampleCandidates.enumerated()), id: \.offset) { index, candidate in
                        HStack(spacing: 4) {
                            // Label (number)
                            Text("\(index + 1)")
                                .font(previewFont(scheme, size: scheme.labelFontPoint ?? 14))
                                .foregroundColor(
                                    index == 0
                                        ? (scheme.hilitedCandidateLabelColor ?? .white)
                                        : (scheme.labelColor ?? .secondary)
                                )

                            // Candidate text
                            Text(candidate)
                                .font(previewFont(scheme, size: scheme.fontPoint ?? 18))
                                .foregroundColor(
                                    index == 0
                                        ? (scheme.hilitedCandidateTextColor ?? .white)
                                        : (scheme.candidateTextColor ?? .primary)
                                )

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            index == 0
                                ? (scheme.hilitedCandidateBackColor ?? .orange)
                                : .clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: scheme.hilitedCornerRadius ?? 6))
                    }
                }
                .padding(.vertical, 4)
            }
            .background(scheme.backColor ?? Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: scheme.cornerRadius ?? 8))
            .overlay(
                RoundedRectangle(cornerRadius: scheme.cornerRadius ?? 8)
                    .stroke(scheme.borderColor ?? .secondary.opacity(0.2), lineWidth: scheme.borderWidth ?? 0.5)
            )
            .shadow(
                color: (scheme.shadowColor ?? .black.opacity(0.2)).opacity(scheme.alpha ?? 0.84),
                radius: scheme.shadowSize ?? 8
            )
            .opacity(scheme.alpha ?? 1.0)

            // Color swatches
            colorSwatches(scheme)
        }
    }

    // MARK: - Color swatches

    private func colorSwatches(_ scheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Colors")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50, maximum: 80), spacing: 4)], spacing: 4) {
                colorSwatch("Text", scheme.textColor)
                colorSwatch("Back", scheme.backColor)
                colorSwatch("HL Back", scheme.hilitedCandidateBackColor)
                colorSwatch("Label", scheme.labelColor)
                colorSwatch("HL Lbl", scheme.hilitedCandidateLabelColor)
                colorSwatch("Cand", scheme.candidateTextColor)
                colorSwatch("HL Cand", scheme.hilitedCandidateTextColor)
                colorSwatch("Cmnt", scheme.commentTextColor)
                colorSwatch("Border", scheme.borderColor)
            }
        }
    }

    private func colorSwatch(_ name: String, _ color: Color?) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color ?? .clear)
                .frame(height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                )
            Text(name)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private func previewFont(_ scheme: ColorScheme, size: Double) -> Font {
        if let face = scheme.fontFace {
            return .custom(face, size: size)
        }
        return .system(size: size)
    }
}

// MARK: - Preview

#Preview {
    let schemes = [
        ColorScheme(
            name: "mint_light_blue",
            isDark: false,
            backColor: Color(red: 0.95, green: 0.95, blue: 0.97),
            hilitedCandidateBackColor: Color(red: 0.87, green: 0.52, blue: 0.04),
            labelColor: Color(red: 0.56, green: 0.56, blue: 0.58),
            hilitedCandidateLabelColor: .white,
            candidateTextColor: Color(red: 0.24, green: 0.24, blue: 0.27),
            hilitedCandidateTextColor: .white,
            textColor: Color(red: 1.0, green: 0.52, blue: 0.04),
            borderColor: Color(red: 0.49, green: 0.49, blue: 0.50).opacity(0.25),
            shadowColor: .black.opacity(0.125),
            alpha: 0.84, cornerRadius: 8, hilitedCornerRadius: 6,
            shadowSize: 8, fontFace: "PingFangSC", fontPoint: 18,
            labelFontFace: "PingFangSC", labelFontPoint: 14,
            commentFontFace: "PingFangSC", commentFontPoint: 13
        )
    ]
    return ColorSchemePreviewView(schemes: schemes)
        .padding()
        .frame(width: 280, height: 500)
}
