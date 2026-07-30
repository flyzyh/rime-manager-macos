import SwiftUI

/// Main visual configuration editor for squirrel settings.
/// Replaces raw YAML editing with a friendly control panel.
struct SquirrelConfigView: View {
    @ObservedObject var config: SquirrelConfig
    var onSave: (() -> Void)?

    @State private var selectedTab: ConfigTab = .layout
    @State private var previewIsDark: Bool = false

    enum ConfigTab: String, CaseIterable {
        case layout = "Layout"
        case appearance = "Appearance"
        case fonts = "Fonts"
        case colors = "Colors"

        var icon: String {
            switch self {
            case .layout: return "square.grid.3x3"
            case .appearance: return "circle.lefthalf.filled"
            case .fonts: return "textformat"
            case .colors: return "paintpalette"
            }
        }
    }

    var body: some View {
        HSplitView {
            // Left: Control panels
            VStack(spacing: 0) {
                // Tab picker
                Picker("Section", selection: $selectedTab) {
                    ForEach(ConfigTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(8)

                Divider()

                // Content
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch selectedTab {
                        case .layout: layoutPanel
                        case .appearance: appearancePanel
                        case .fonts: fontsPanel
                        case .colors: colorsPanel
                        }
                    }
                    .padding(12)
                }

                // Bottom: save button
                if let onSave = onSave {
                    Divider()
                    HStack {
                        Spacer()
                        Button("Apply & Save") {
                            onSave()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(10)
                    .background(.bar)
                }
            }
            .frame(minWidth: 350, idealWidth: 400)

            // Right: Live preview
            LivePreviewView(config: config, isDark: $previewIsDark)
                .frame(minWidth: 280, idealWidth: 340)
        }
    }

    // MARK: - Layout Panel

    private var layoutPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Candidate Orientation")
            Picker("Text Orientation", selection: $config.textOrientation) {
                ForEach(TextOrientation.allCases, id: \.self) { o in
                    Text(o.displayName).tag(o)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            SectionHeader("Candidate Layout")
            Picker("Layout", selection: $config.candidateListLayout) {
                ForEach(CandidateLayout.allCases, id: \.self) { l in
                    Text(l.displayName).tag(l)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            SectionHeader("Display Options")

            ConfigToggle("Inline Preedit", isOn: $config.inlinePreedit)
                .help("Show input text inline in the candidate window")
            ConfigToggle("Inline Candidate", isOn: $config.inlineCandidate)
            ConfigToggle("Show Paging", isOn: $config.showPaging)
            ConfigToggle("Mutual Exclusive", isOn: $config.mutualExclusive)
            ConfigToggle("Remember Window Size", isOn: $config.rememberSize)

            SectionHeader("Status Message")
            Picker("", selection: $config.statusMessageType) {
                ForEach(StatusMessageType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }

            SectionHeader("Candidate Format")
            TextField("Format", text: $config.candidateFormat)
                .textFieldStyle(.roundedBorder)

            SectionHeader("Page Size")
            ConfigIntStepper("Candidates per page", value: $config.pageSize, range: 5...15)
        }
    }

    // MARK: - Appearance Panel

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Effects")
            ConfigToggle("Translucency (半透明)", isOn: $config.translucency)
            ConfigToggle("Background Blur (模糊)", isOn: $config.blurEnabled)

            SectionHeader("Transparency (Alpha)")
            ConfigSlider("Opacity", value: $config.alpha, range: 0.3...1.0, format: "%.0f%%") { v in Int(v * 100) }

            SectionHeader("Corner Radius")
            ConfigSlider("Window", value: $config.cornerRadius, range: 0...20, format: "%.0f")
            ConfigSlider("Highlight", value: $config.hilitedCornerRadius, range: 0...20, format: "%.0f")

            SectionHeader("Border")
            ConfigStepper("Border Height", value: $config.borderHeight, range: 0...10)
            ConfigStepper("Border Width", value: $config.borderWidth, range: 0...10)

            SectionHeader("Spacing")
            ConfigStepper("Line Spacing", value: $config.lineSpacing, range: 0...20)
            ConfigStepper("Item Spacing", value: $config.spacing, range: 0...20)

            SectionHeader("Shadow")
            ConfigSlider("Shadow Size", value: $config.shadowSize, range: 0...30, format: "%.0f")
        }
    }

    // MARK: - Fonts Panel

    private var fontsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Main Font")
            FontPickerRow(label: "Font Face", text: $config.fontFace)
            ConfigSlider("Size", value: $config.fontPoint, range: 10...36, format: "%.0f pt")

            SectionHeader("Label Font")
            FontPickerRow(label: "Font Face", text: $config.labelFontFace)
            ConfigSlider("Size", value: $config.labelFontPoint, range: 8...24, format: "%.0f pt")

            SectionHeader("Comment Font")
            FontPickerRow(label: "Font Face", text: $config.commentFontFace)
            ConfigSlider("Size", value: $config.commentFontPoint, range: 8...24, format: "%.0f pt")
        }
    }

    // MARK: - Colors Panel

    private var colorsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Color Schemes")

            if config.colorSchemes.isEmpty {
                Text("No color schemes found in configuration.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(config.colorSchemes.keys.sorted()), id: \.self) { name in
                    if let scheme = config.colorSchemes[name] {
                        ColorSchemeEditorCard(name: name, scheme: scheme)
                    }
                }
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 4)
    }
}

// MARK: - Config Control Components

struct ConfigToggle: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

struct ConfigSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var displayTransform: ((Double) -> Int)? = nil

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
         format: String, display: ((Double) -> Int)? = nil) {
        self.label = label
        self._value = value
        self.range = range
        self.format = format
        self.displayTransform = display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let transform = displayTransform {
                    Text("\(transform(value))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text(String(format: format, value))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Slider(value: $value, in: range)
                .controlSize(.mini)
        }
    }
}

struct ConfigStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) {
        self.label = label
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Stepper("\(Int(value))", value: $value, in: range, step: 1)
                .labelsHidden()
            Text("\(Int(value))")
                .font(.caption).monospacedDigit().frame(width: 24, alignment: .trailing)
        }
    }
}

struct ConfigIntStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) {
        self.label = label
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Stepper("\(value)", value: $value, in: range)
                .labelsHidden()
            Text("\(value)")
                .font(.caption).monospacedDigit().frame(width: 24, alignment: .trailing)
        }
    }
}

struct FontPickerRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            TextField("Font name", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }
}
