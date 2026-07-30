import SwiftUI

/// Real-time preview of the candidate window based on squirrel config.
struct LivePreviewView: View {
    @ObservedObject var config: SquirrelConfig
    @Binding var isDark: Bool

    @State private var sampleInput: String = "zhong"
    @State private var sampleCandidates: [String] = [
        "1. 中文", "2. 中国", "3. 重要", "4. 终于", "5. 重量"
    ]

    /// Reactively computed current scheme
    private var currentScheme: EditableColorScheme? {
        if isDark {
            return config.colorSchemes[config.colorSchemeDarkName]
        } else {
            return config.colorSchemes[config.colorSchemeLightName]
        }
    }

    /// Force refresh ID that changes when scheme selection changes
    private var refreshID: String {
        "\(config.colorSchemeLightName)-\(config.colorSchemeDarkName)-\(isDark)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Live Preview", systemImage: "eye")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: $isDark) {
                    Label("Light", systemImage: "sun.max").tag(false)
                    Label("Dark", systemImage: "moon").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 80)

                Button(action: {}) {
                    Image(systemName: "chevron.left")
                }.disabled(true)
                Button(action: {}) {
                    Image(systemName: "chevron.right")
                }.disabled(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }

            // Preview area
            VStack {
                Spacer()
                candidateWindowPreview
                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Pinyin Input")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Enter pinyin...", text: $sampleInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onChange(of: sampleInput) { _, val in updateCandidates(for: val) }
                }
                .padding(12)
                .background(.ultraThinMaterial)
            }

            // Config summary
            HStack(spacing: 12) {
                Label(config.textOrientation == .horizontal ? "—" : "|",
                      systemImage: "arrow.left.and.right")
                    .font(.caption).foregroundStyle(.secondary)
                Label("α\(String(format: "%.0f", config.alpha * 100))%",
                      systemImage: "circle.lefthalf.filled")
                    .font(.caption).foregroundStyle(.secondary)
                Label("R\(Int(config.cornerRadius))",
                      systemImage: "app.dashed")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(config.fontFace)
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
        .id(refreshID)
    }

    // MARK: - Candidate window

    private var candidateWindowPreview: some View {
        let cs = currentScheme
        let isHorizontal = config.textOrientation == .horizontal

        return Group {
            if isHorizontal {
                // Horizontal: preedit on top, candidates in a ROW
                VStack(alignment: .leading, spacing: 0) {
                    preeditArea(cs)
                    Rectangle()
                        .fill(cs?.parsedBorderColor ?? .secondary.opacity(0.15))
                        .frame(height: 1)
                    horizontalCandidates(cs)
                }
            } else {
                // Vertical: preedit on left, candidates in a COLUMN
                VStack(alignment: .leading, spacing: 0) {
                    preeditArea(cs)
                    Rectangle()
                        .fill(cs?.parsedBorderColor ?? .secondary.opacity(0.15))
                        .frame(height: 1)
                    candidatesList(cs)
                }
            }
        }
        .background(cs?.parsedBackColor ?? Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .stroke(cs?.parsedBorderColor ?? .secondary.opacity(0.2),
                        lineWidth: config.borderWidth)
        )
        .shadow(color: (cs?.parsedShadowColor ?? .black.opacity(0.15)).opacity(config.alpha),
                radius: config.shadowSize)
        .opacity(config.alpha)
        .padding(20)
    }

    // MARK: - Layout helpers

    private func preeditArea(_ cs: EditableColorScheme?) -> some View {
        HStack(spacing: 2) {
            if config.inlinePreedit {
                Text(sampleInput)
                    .font(.custom(config.fontFace, size: config.fontPoint))
                    .foregroundColor(cs?.parsedTextColor ?? .primary)
                Rectangle()
                    .fill(cs?.parsedHilitedText ?? .orange)
                    .frame(width: 2, height: config.fontPoint * 1.1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, config.spacing / 2 + 4)
    }

    /// Horizontal layout: candidates in a row
    private func horizontalCandidates(_ cs: EditableColorScheme?) -> some View {
        HStack(spacing: config.spacing) {
            ForEach(Array(sampleCandidates.enumerated()), id: \.offset) { index, candidate in
                let isHilited = (index == 0)
                HStack(spacing: 2) {
                    Text("\(index + 1)")
                        .font(.custom(config.labelFontFace, size: config.labelFontPoint))
                        .foregroundColor(isHilited ? cs?.parsedHilitedLabel : cs?.parsedLabelColor ?? .secondary)
                    Text(candidate.replacingOccurrences(of: "\(index + 1). ", with: ""))
                        .font(.custom(config.fontFace, size: config.fontPoint))
                        .foregroundColor(isHilited ? cs?.parsedHilitedCandidateText : cs?.parsedCandidateText ?? .primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if isHilited {
                            (cs?.parsedHilitedBack ?? .orange)
                                .clipShape(RoundedRectangle(cornerRadius: config.hilitedCornerRadius))
                        }
                    }
                )
            }
        }
        .padding(6)
    }

    /// Vertical layout: candidates in a column (traditional display)
    private func candidatesList(_ cs: EditableColorScheme?) -> some View {
        VStack(alignment: .leading, spacing: config.lineSpacing) {
            ForEach(Array(sampleCandidates.enumerated()), id: \.offset) { index, candidate in
                let isHilited = (index == 0)
                HStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.custom(config.labelFontFace, size: config.labelFontPoint))
                        .foregroundColor(isHilited ? cs?.parsedHilitedLabel : cs?.parsedLabelColor ?? .secondary)
                    Text(candidate)
                        .font(.custom(config.fontFace, size: config.fontPoint))
                        .foregroundColor(isHilited ? cs?.parsedHilitedCandidateText : cs?.parsedCandidateText ?? .primary)
                    if index == 1 {
                        Text("📝")
                            .font(.custom(config.commentFontFace, size: config.commentFontPoint))
                            .foregroundColor(isHilited ? cs?.parsedHilitedComment : cs?.parsedCommentText ?? .secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, config.spacing / 2)
                .background(
                    Group {
                        if isHilited {
                            (cs?.parsedHilitedBack ?? .orange)
                                .clipShape(RoundedRectangle(cornerRadius: config.hilitedCornerRadius))
                        } else {
                            Color.clear
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func updateCandidates(for input: String) {
        let map: [String: [String]] = [
            "zhong": ["1. 中文", "2. 中国", "3. 重要", "4. 终于", "5. 重量"],
            "shu": ["1. 输入", "2. 书", "3. 数", "4. 树", "5. 属"],
            "fang": ["1. 方案", "2. 方法", "3. 方便", "4. 房", "5. 放"],
            "pei": ["1. 配置", "2. 配", "3. 培", "4. 陪", "5. 赔"],
            "yan": ["1. 颜色", "2. 眼", "3. 言", "4. 严", "5. 研"],
            "zi": ["1. 字体", "2. 自", "3. 字", "4. 资", "5. 紫"],
            "biao": ["1. 标题", "2. 表", "3. 标", "4. 彪", "5. 裱"],
            "tou": ["1. 透明", "2. 头", "3. 投", "4. 透", "5. 偷"],
        ]
        sampleCandidates = map[input.lowercased()] ?? ["1. \(input)", "2. ???", "3. ???", "4. ???", "5. ???"]
    }
}

// MARK: - Color Scheme Editor Card

struct ColorSchemeEditorCard: View {
    let name: String
    @ObservedObject var scheme: EditableColorScheme
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ColorPickerRow(label: "Background", hex: $scheme.backColor)
                ColorPickerRow(label: "Text / Input", hex: $scheme.textColor)
                ColorPickerRow(label: "Hilited Text", hex: $scheme.hilitedTextColor)
                ColorPickerRow(label: "Candidate Text", hex: $scheme.candidateTextColor)
                ColorPickerRow(label: "Hilited Cand. Text", hex: $scheme.hilitedCandidateTextColor)
                ColorPickerRow(label: "Hilited Cand. BG", hex: $scheme.hilitedCandidateBackColor)
                ColorPickerRow(label: "Label", hex: $scheme.labelColor)
                ColorPickerRow(label: "Hilited Label", hex: $scheme.hilitedCandidateLabelColor)
                ColorPickerRow(label: "Comment", hex: $scheme.commentTextColor)
                ColorPickerRow(label: "Hilited Comment", hex: $scheme.hilitedCommentTextColor)
                ColorPickerRow(label: "Border", hex: $scheme.borderColor)
                ColorPickerRow(label: "Shadow", hex: $scheme.shadowColor)
            }
            .padding(.leading, 8)
            .padding(.bottom, 8)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(scheme.parsedBackColor)
                    .frame(width: 16, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                Text(name)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(scheme.parsedHilitedBack)
                    .frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(scheme.parsedTextColor)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    let label: String
    @Binding var hex: String
    @State private var colorValue: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            ColorPicker("", selection: $colorValue)
                .labelsHidden().frame(width: 24)

            RoundedRectangle(cornerRadius: 3)
                .fill(colorValue)
                .frame(width: 22, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(.secondary.opacity(0.3), lineWidth: 0.5))

            TextField("0xAARRGGBB", text: $hex)
                .font(.system(size: 10, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: hex) { _, h in
                    if let c = ColorScheme.parseHexColor(h) { colorValue = c }
                }
        }
        .onAppear {
            if let c = ColorScheme.parseHexColor(hex) { colorValue = c }
        }
        .onChange(of: colorValue) { _, c in
            hex = ColorScheme.colorToRimeHex(c)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = SquirrelConfig()
    config.colorSchemes = [
        "mint_light_blue": EditableColorScheme(name: "mint_light_blue"),
        "mint_dark_blue": EditableColorScheme(name: "mint_dark_blue"),
    ]
    return LivePreviewView(config: config, isDark: .constant(false))
        .frame(width: 320, height: 500)
}
