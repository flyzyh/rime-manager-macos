import SwiftUI

/// Input behavior settings view with Form-based controls.
struct InputSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var inputSettings: InputSettings { appState.configManager.inputSettings }

    var body: some View {
        Form {
            defaultModeSection
            switchesSection
            keyboardSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("nav.input".localized)
    }

    // MARK: - Default Mode

    private var defaultModeSection: some View {
        Section("input.section_mode".localized) {
            Picker("input.language".localized, selection: Binding(
                get: { inputSettings.asciiMode },
                set: { inputSettings.asciiMode = $0 }
            )) {
                Text("input.chinese".localized).tag(false)
                Text("input.english".localized).tag(true)
            }
            .pickerStyle(.segmented)

            Picker("input.tradition".localized, selection: Binding(
                get: { inputSettings.transcription },
                set: { inputSettings.transcription = $0 }
            )) {
                Text("input.simplified".localized).tag(false)
                Text("input.traditional".localized).tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Switches

    private var switchesSection: some View {
        Section("input.section_switches".localized) {
            Toggle("input.emoji".localized, isOn: Binding(
                get: { inputSettings.emojiSuggestion },
                set: { inputSettings.emojiSuggestion = $0 }
            ))

            Toggle("input.full_shape".localized, isOn: Binding(
                get: { inputSettings.fullShape },
                set: { inputSettings.fullShape = $0 }
            ))

            Toggle("input.tone_display".localized, isOn: Binding(
                get: { inputSettings.toneDisplay },
                set: { inputSettings.toneDisplay = $0 }
            ))
        }
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        Section("input.section_keyboard".localized) {
            Toggle("input.caps_lock".localized, isOn: Binding(
                get: { inputSettings.capsLockSwitch },
                set: { inputSettings.capsLockSwitch = $0 }
            ))

            Picker("input.shift_behavior".localized, selection: Binding(
                get: { inputSettings.shiftSwitch },
                set: { inputSettings.shiftSwitch = $0 }
            )) {
                Text("input.shift_commit_code".localized).tag("commit_code")
                Text("input.shift_commit_text".localized).tag("commit_text")
                Text("input.shift_inline_ascii".localized).tag("inline_ascii")
                Text("input.shift_clear".localized).tag("clear")
                Text("input.shift_noop".localized).tag("noop")
            }
        }
    }
}
