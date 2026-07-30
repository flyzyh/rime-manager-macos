import SwiftUI

/// Appearance settings view with live preview and Form-based controls.
struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var previewDark: Bool = false
    @State private var selectedSchemeName: String = ""

    private var config: SquirrelConfig { appState.configManager.squirrelConfig }
    private var inputSettings: InputSettings { appState.configManager.inputSettings }

    /// The scheme object currently being edited.
    private var activeScheme: EditableColorScheme? {
        config.colorSchemes[selectedSchemeName]
    }

    var body: some View {
        Form {
            // Preview + Color section at top
            Section {
                previewAndColorContent
            }

            layoutSection
            fontSection
            effectsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("nav.appearance".localized)
        .onAppear { syncSchemeName() }
        .onChange(of: previewDark) { _, _ in syncSchemeName() }
        .onChange(of: config.colorSchemeLightName) { _, _ in if !previewDark { syncSchemeName() } }
        .onChange(of: config.colorSchemeDarkName) { _, _ in if previewDark { syncSchemeName() } }
    }

    private func syncSchemeName() {
        selectedSchemeName = previewDark ? config.colorSchemeDarkName : config.colorSchemeLightName
    }

    private func updateSchemeName(_ newName: String) {
        selectedSchemeName = newName
        if previewDark {
            config.colorSchemeDarkName = newName
        } else {
            config.colorSchemeLightName = newName
        }
    }

    // MARK: - Preview + Color (coupled, inside a single Section)

    @ViewBuilder
    private var previewAndColorContent: some View {
        // Header: title + light/dark toggle
        HStack {
            Text("appearance.preview_mode".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $previewDark) {
                Text("appearance.preview_light".localized).tag(false)
                Text("appearance.preview_dark".localized).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)
        }

        // Live preview
        CandidatePreviewView(config: config, inputSettings: inputSettings, isDark: $previewDark)
            .padding(.vertical, 4)

        Divider()

        // Scheme picker - compact HStack layout
        HStack(spacing: 8) {
            Text(previewDark
                 ? "appearance.dark_scheme".localized
                 : "appearance.light_scheme".localized)
                .font(.body)

            Picker("", selection: Binding(
                get: { selectedSchemeName },
                set: { updateSchemeName($0) }
            )) {
                ForEach(Array(config.colorSchemes.keys.sorted()), id: \.self) { name in
                    HStack(spacing: 6) {
                        if let cs = config.colorSchemes[name] {
                            Circle()
                                .fill(cs.parsedHilitedBack)
                                .frame(width: 10, height: 10)
                        }
                        Text(name)
                    }
                    .tag(name)
                }
            }
            .labelsHidden()
        }

        // Color editor for the active scheme
        if let scheme = activeScheme {
            ColorSchemeEditorView(scheme: scheme, title: selectedSchemeName)
                .id(selectedSchemeName)
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        Section("appearance.section_layout".localized) {
            Picker("appearance.orientation".localized, selection: Binding(
                get: { config.textOrientation },
                set: { config.textOrientation = $0 }
            )) {
                Text("appearance.horizontal".localized).tag(TextOrientation.horizontal)
                Text("appearance.vertical".localized).tag(TextOrientation.vertical)
            }
            .pickerStyle(.segmented)

            intSliderRow(
                label: "input.page_size".localized,
                value: Binding(
                    get: { inputSettings.candidateCount },
                    set: { inputSettings.candidateCount = $0 }
                ),
                range: 3...9
            )

            Toggle("appearance.inline_preedit".localized, isOn: Binding(
                get: { config.inlinePreedit },
                set: { config.inlinePreedit = $0 }
            ))

            Toggle("appearance.show_paging".localized, isOn: Binding(
                get: { config.showPaging },
                set: { config.showPaging = $0 }
            ))
        }
    }

    // MARK: - Font Section

    private var fontSection: some View {
        Section("appearance.section_font".localized) {
            Picker("appearance.font_face".localized, selection: Binding(
                get: { config.fontFace },
                set: { config.fontFace = $0 }
            )) {
                ForEach(["PingFangSC", "PingFangHK", "Heiti SC", "Songti SC", "Kaiti SC", "SF Pro", "Menlo", "Helvetica Neue"], id: \.self) {
                    Text($0)
                }
            }

            doubleSliderRow(
                label: "appearance.font_size".localized,
                value: Binding(
                    get: { config.fontPoint },
                    set: { config.fontPoint = $0 }
                ),
                range: 10...36,
                unit: "pt"
            )

            Picker("appearance.label_font".localized, selection: Binding(
                get: { config.labelFontFace },
                set: { config.labelFontFace = $0 }
            )) {
                ForEach(["PingFangSC", "PingFangHK", "Heiti SC", "SF Pro", "Menlo"], id: \.self) {
                    Text($0)
                }
            }

            doubleSliderRow(
                label: "appearance.label_size".localized,
                value: Binding(
                    get: { config.labelFontPoint },
                    set: { config.labelFontPoint = $0 }
                ),
                range: 8...24,
                unit: "pt"
            )
        }
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        Section("appearance.section_effects".localized) {
            percentSliderRow(
                label: "appearance.alpha".localized,
                value: Binding(
                    get: { config.alpha },
                    set: { config.alpha = $0 }
                ),
                range: 0.3...1.0
            )

            doubleSliderRow(
                label: "appearance.corner_radius".localized,
                value: Binding(
                    get: { config.cornerRadius },
                    set: { config.cornerRadius = $0 }
                ),
                range: 0...20,
                unit: ""
            )

            doubleSliderRow(
                label: "appearance.hilited_radius".localized,
                value: Binding(
                    get: { config.hilitedCornerRadius },
                    set: { config.hilitedCornerRadius = $0 }
                ),
                range: 0...20,
                unit: ""
            )

            Toggle("appearance.translucency".localized, isOn: Binding(
                get: { config.translucency },
                set: { config.translucency = $0 }
            ))

            Toggle("appearance.blur".localized, isOn: Binding(
                get: { config.blurEnabled },
                set: { config.blurEnabled = $0 }
            ))
        }
    }

    // MARK: - Slider Row Builders

    private func doubleSliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Slider(value: value, in: range, step: 1)
                    .frame(height: 20)
                HStack(spacing: 4) {
                    Text("\(Int(value.wrappedValue))")
                        .monospacedDigit()
                    if !unit.isEmpty { Text(unit).foregroundStyle(.secondary) }
                    stepperArrows(
                        increment: { value.wrappedValue = min(value.wrappedValue + 1, range.upperBound) },
                        decrement: { value.wrappedValue = max(value.wrappedValue - 1, range.lowerBound) }
                    )
                }
                .frame(width: 70, height: 20)
            }
        }
    }

    private func percentSliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Slider(value: value, in: range, step: 0.01)
                    .frame(height: 20)
                HStack(spacing: 4) {
                    Text("\(Int(value.wrappedValue * 100))")
                        .monospacedDigit()
                    Text("%").foregroundStyle(.secondary)
                    stepperArrows(
                        increment: { value.wrappedValue = min(value.wrappedValue + 0.01, range.upperBound) },
                        decrement: { value.wrappedValue = max(value.wrappedValue - 0.01, range.lowerBound) }
                    )
                }
                .frame(width: 70, height: 20)
            }
        }
    }

    private func intSliderRow(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                    .frame(height: 20)
                HStack(spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .monospacedDigit()
                    stepperArrows(
                        increment: { value.wrappedValue = min(value.wrappedValue + 1, range.upperBound) },
                        decrement: { value.wrappedValue = max(value.wrappedValue - 1, range.lowerBound) }
                    )
                }
                .frame(width: 50, height: 20)
            }
        }
    }

    private func stepperArrows(increment: @escaping () -> Void, decrement: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: increment) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 7, weight: .semibold))
                    .frame(width: 14, height: 10)
            }
            .buttonStyle(.borderless)
            Button(action: decrement) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .frame(width: 14, height: 10)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Color Scheme Editor

struct ColorSchemeEditorView: View {
    @ObservedObject var scheme: EditableColorScheme
    let title: String

    var body: some View {
        DisclosureGroup(title) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    SchemeColorPickerRow("color.background".localized, $scheme.backColor, scheme.parsedBackColor)
                    SchemeColorPickerRow("color.text".localized, $scheme.textColor, scheme.parsedTextColor)
                }
                GridRow {
                    SchemeColorPickerRow("color.hl_bg".localized, $scheme.hilitedCandidateBackColor, scheme.parsedHilitedBack)
                    SchemeColorPickerRow("color.candidate".localized, $scheme.candidateTextColor, scheme.parsedCandidateText)
                }
                GridRow {
                    SchemeColorPickerRow("color.hl_cand".localized, $scheme.hilitedCandidateTextColor, scheme.parsedHilitedCandidateText)
                    SchemeColorPickerRow("color.label".localized, $scheme.labelColor, scheme.parsedLabelColor)
                }
                GridRow {
                    SchemeColorPickerRow("color.comment".localized, $scheme.commentTextColor, scheme.parsedCommentText)
                    SchemeColorPickerRow("color.border".localized, $scheme.borderColor, scheme.parsedBorderColor)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct SchemeColorPickerRow: View {
    let label: String
    @Binding var hex: String
    let swatch: Color

    init(_ label: String, _ hex: Binding<String>, _ swatch: Color) {
        self.label = label
        self._hex = hex
        self.swatch = swatch
    }

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(swatch)
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
                )

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 60, alignment: .leading)

            ColorPicker("", selection: Binding(
                get: { swatch },
                set: { hex = ColorScheme.colorToRimeHex($0) }
            ))
            .labelsHidden()
        }
    }
}
