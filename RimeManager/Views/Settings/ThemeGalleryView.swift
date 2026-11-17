import SwiftUI

enum ThemeGalleryFilter: String, CaseIterable, Identifiable {
    case all
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "theme.filter_all".localized
        case .light: return "theme.filter_light".localized
        case .dark: return "theme.filter_dark".localized
        }
    }
}

/// A card-based gallery for the curated GitHub theme catalog.
struct ThemeGalleryView: View {
    @ObservedObject var config: SquirrelConfig
    @Binding var previewDark: Bool
    @Binding var selectedThemeID: String

    @State private var filter: ThemeGalleryFilter = .all
    @State private var detailsTheme: PresetColorTheme?

    private let columns = [GridItem(.adaptive(minimum: 225, maximum: 300), spacing: 14)]

    private var filteredThemes: [PresetColorTheme] {
        switch filter {
        case .all: return ThemeCatalog.themes
        case .light: return ThemeCatalog.themes.filter { !$0.isDark }
        case .dark: return ThemeCatalog.themes.filter(\.isDark)
        }
    }

    private var activeThemeID: String? {
        previewDark ? config.colorSchemeDarkName : config.colorSchemeLightName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryHeader

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(filteredThemes) { theme in
                    ThemeCardView(
                        theme: theme,
                        isSelected: selectedThemeID == theme.id,
                        isActive: activeThemeID == theme.id,
                        onApply: { apply(theme) },
                        onCopy: { copy(theme) },
                        onDetails: { detailsTheme = theme }
                    )
                }
            }

            Text("appearance.theme_gallery_subtitle".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(item: $detailsTheme) { theme in
            ThemeDetailSheet(
                theme: theme,
                onApply: {
                    apply(theme)
                    detailsTheme = nil
                },
                onCopy: {
                    copy(theme)
                    detailsTheme = nil
                }
            )
            .frame(width: 620)
        }
    }

    private var galleryHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("appearance.theme_gallery".localized)
                    .font(.headline)
                Text("appearance.theme_gallery_subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $filter) {
                ForEach(ThemeGalleryFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
        }
    }

    private func apply(_ theme: PresetColorTheme) {
        config.apply(theme: theme)
        selectedThemeID = theme.id
        previewDark = theme.isDark
        FeedbackManager.shared.showSuccess("theme.applied".localized)
    }

    private func copy(_ theme: PresetColorTheme) {
        config.applyCopy(of: theme)
        selectedThemeID = theme.customTheme.id
        previewDark = theme.isDark
        FeedbackManager.shared.showSuccess("theme.applied".localized)
    }
}

private struct ThemeCardView: View {
    let theme: PresetColorTheme
    let isSelected: Bool
    let isActive: Bool
    let onApply: () -> Void
    let onCopy: () -> Void
    let onDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemeCandidateStrip(palette: theme.palette)
                .frame(height: 96)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(theme.displayName)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    appearanceBadge
                }

                Text("\(theme.author) · \(theme.license)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button("theme.details".localized, action: onDetails)
                    .controlSize(.small)

                Spacer()

                if isActive {
                    Text("theme.active".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Button("theme.apply".localized, action: onApply)
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.8) : Color(nsColor: .quaternaryLabelColor),
                    lineWidth: isSelected ? 1.6 : 1
                )
        }
        .shadow(color: .black.opacity(0.055), radius: 7, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onDetails)
        .contextMenu {
            Button("theme.apply".localized, action: onApply)
            Button("theme.copy".localized, action: onCopy)
            Button("theme.details".localized, action: onDetails)
        }
    }

    private var appearanceBadge: some View {
        Text((theme.isDark ? "appearance.preview_dark" : "appearance.preview_light").localized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

private struct ThemeCandidateStrip: View {
    let palette: ThemePalette

    var body: some View {
        let background = ColorScheme.parseHexColor(palette.background) ?? Color(nsColor: .windowBackgroundColor)
        let label = ColorScheme.parseHexColor(palette.label) ?? .secondary
        let candidate = ColorScheme.parseHexColor(palette.candidateText) ?? .primary
        let highlightBackground = ColorScheme.parseHexColor(palette.highlightedCandidateBackground) ?? .accentColor
        let highlightText = ColorScheme.parseHexColor(palette.highlightedCandidateText) ?? .white
        let highlightLabel = ColorScheme.parseHexColor(palette.highlightedLabelColor) ?? .white

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 0) {
                Text("nihao")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(label.opacity(0.7))
                Rectangle()
                    .fill(ColorScheme.parseHexColor(palette.highlightedPreeditText) ?? .accentColor)
                    .frame(width: 1.2, height: 13)
            }

            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("1")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(highlightLabel)
                    Text("你好")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(highlightText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(highlightBackground, in: RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 4) {
                    Text("2 输入")
                    Text("3 Rime")
                }
                .font(.system(size: 12))
                .foregroundStyle(candidate)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(ColorScheme.parseHexColor(palette.border) ?? Color(nsColor: .quaternaryLabelColor), lineWidth: 1)
        }
    }
}

private struct ThemeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let theme: PresetColorTheme
    let onApply: () -> Void
    let onCopy: () -> Void

    private var contrastRows: [(title: String, ratio: Double?)] {
        [
            ("color.candidate".localized, ThemeColor.contrastRatio(theme.palette.candidateText, on: theme.palette.background)),
            ("color.hl_cand".localized, ThemeColor.contrastRatio(theme.palette.highlightedCandidateText, on: theme.palette.highlightedCandidateBackground)),
            ("color.comment".localized, ThemeColor.contrastRatio(theme.palette.comment, on: theme.palette.background)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.title2.weight(.semibold))
                    Text(theme.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ThemeCandidateStrip(palette: theme.palette)
                .frame(height: 150)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 10) {
                metadataRow(title: "theme.author".localized, value: theme.author)
                metadataRow(title: "theme.license".localized, value: theme.license)
                metadataRow(title: "theme.source".localized, value: theme.sourceURL)
            }
            .padding(14)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(contrastRows, id: \.title) { row in
                    HStack {
                        Text(row.title)
                            .font(.callout)
                        Spacer()
                        if let ratio = row.ratio {
                            Text(String(format: "%.1f:1", ratio))
                                .monospacedDigit()
                                .font(.callout.weight(.medium))
                                .foregroundStyle(ratio < 3 ? .orange : .green)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if contrastRows.contains(where: { ($0.ratio ?? 10) < 3 }) {
                    Label("theme.low_contrast".localized, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 3)

            HStack(spacing: 10) {
                Button("theme.copy".localized, action: onCopy)
                    .controlSize(.large)

                Spacer()

                Button("theme.apply".localized, action: onApply)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            if URL(string: value) != nil, value.hasPrefix("https://") {
                Link(value, destination: URL(string: value)!)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(value)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
    }
}
