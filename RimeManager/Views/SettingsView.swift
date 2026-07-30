import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @AppStorage("autoBackupBeforeSave") private var autoBackupBeforeSave = true
    @AppStorage("showLineNumbers") private var showLineNumbers = true
    @AppStorage("editorFontSize") private var editorFontSize = 13.0
    @AppStorage("highlightYAMLSyntax") private var highlightYAMLSyntax = true
    @AppStorage("watchExternalChanges") private var watchExternalChanges = true

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            EditorSettingsView(
                showLineNumbers: $showLineNumbers,
                editorFontSize: $editorFontSize,
                highlightYAMLSyntax: $highlightYAMLSyntax
            )
            .tabItem {
                Label("Editor", systemImage: "pencil.and.outline")
            }

            BackupSettingsView(autoBackupBeforeSave: $autoBackupBeforeSave)
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Rime Directory:")
                    if let url = appState.rimeDirectoryURL {
                        Text(url.path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Not set")
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button("Change...") {
                        appState.selectRimeDirectory()
                    }
                }
            } header: {
                Text("Rime Configuration")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default path: ~/Library/Rime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Squirrel path: /Library/Input Methods/Squirrel.app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Information")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @Binding var showLineNumbers: Bool
    @Binding var editorFontSize: Double
    @Binding var highlightYAMLSyntax: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Show line numbers", isOn: $showLineNumbers)
                Toggle("Syntax highlighting", isOn: $highlightYAMLSyntax)

                HStack {
                    Text("Font size:")
                    Slider(value: $editorFontSize, in: 9...24, step: 1)
                    Text("\(Int(editorFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            } header: {
                Text("Editor Options")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Backup Settings

struct BackupSettingsView: View {
    @Binding var autoBackupBeforeSave: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Auto-backup before saving", isOn: $autoBackupBeforeSave)
                Text("Creates a timestamped backup of each file before overwriting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Backup Options")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
