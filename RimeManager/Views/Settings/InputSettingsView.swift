import SwiftUI

/// Input behavior settings view with Form-based controls.
struct InputSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var inputSettings: InputSettings { appState.configManager.inputSettings }
    private var config: SquirrelConfig { appState.configManager.squirrelConfig }

    var body: some View {
        Form {
            defaultModeSection
            switchesSection
            keyboardSection
            engineSection
            notificationSection
            appOptionsSection
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

            Toggle("input.ascii_punct".localized, isOn: Binding(
                get: { inputSettings.asciiPunct },
                set: { inputSettings.asciiPunct = $0 }
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

    // MARK: - Engine

    private var engineSection: some View {
        Section("input.section_engine".localized) {
            Toggle("input.enable_encoder".localized, isOn: Binding(
                get: { inputSettings.enableEncoder },
                set: { inputSettings.enableEncoder = $0 }
            ))

            Toggle("input.enable_sentence".localized, isOn: Binding(
                get: { inputSettings.enableSentence },
                set: { inputSettings.enableSentence = $0 }
            ))

            Toggle("input.enable_user_dict".localized, isOn: Binding(
                get: { inputSettings.enableUserDict },
                set: { inputSettings.enableUserDict = $0 }
            ))

            Toggle("input.encode_commit_history".localized, isOn: Binding(
                get: { inputSettings.encodeCommitHistory },
                set: { inputSettings.encodeCommitHistory = $0 }
            ))
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        Section("input.section_notifications".localized) {
            Picker("input.show_notifications".localized, selection: Binding(
                get: { config.showNotificationsWhen },
                set: { config.showNotificationsWhen = $0 }
            )) {
                Text("input.notif_always".localized).tag(ShowNotificationsWhen.always)
                Text("input.notif_appropriate".localized).tag(ShowNotificationsWhen.appropriate)
                Text("input.notif_never".localized).tag(ShowNotificationsWhen.never)
            }
        }
    }

    // MARK: - App Options

    private var appOptionsSection: some View {
        Section {
            ForEach(config.appOptions) { entry in
                AppOptionRow(entry: entry, config: config)
            }
            .onDelete { offsets in
                config.appOptions.remove(atOffsets: offsets)
            }

            Button(action: addAppOption) {
                Label("input.add_app_rule".localized, systemImage: "plus.circle")
            }
            .buttonStyle(.link)
        } header: {
            Text("input.section_app_options".localized)
        } footer: {
            Text("input.app_options_footer".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addAppOption() {
        config.appOptions.append(AppOptionEntry(bundleID: "com.example.app", noInline: false))
    }
}

// MARK: - App Option Row

struct AppOptionRow: View {
    let entry: AppOptionEntry
    @ObservedObject var config: SquirrelConfig

    private var binding: Binding<AppOptionEntry> {
        Binding(
            get: {
                config.appOptions.first(where: { $0.id == entry.id }) ?? entry
            },
            set: { newValue in
                if let idx = config.appOptions.firstIndex(where: { $0.id == entry.id }) {
                    config.appOptions[idx] = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Bundle ID", text: binding.bundleID)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack(spacing: 16) {
                Toggle("no_inline", isOn: Binding(
                    get: { binding.wrappedValue.noInline ?? false },
                    set: { binding.wrappedValue.noInline = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)

                Toggle("ascii_mode", isOn: Binding(
                    get: { binding.wrappedValue.asciiMode ?? false },
                    set: { binding.wrappedValue.asciiMode = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)

                Toggle("vim_mode", isOn: Binding(
                    get: { binding.wrappedValue.vimMode ?? false },
                    set: { binding.wrappedValue.vimMode = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
