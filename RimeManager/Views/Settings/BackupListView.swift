import SwiftUI

/// Backup management view with list, create, restore, and delete operations.
struct BackupListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var backups: [URL] = []
    @State private var selectedBackup: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Header with create button
            backupHeader

            if backups.isEmpty {
                emptyState
            } else {
                backupList
            }
        }
        .navigationTitle("nav.backups".localized)
        .onAppear { refreshBackups() }
    }

    // MARK: - Header

    private var backupHeader: some View {
        HStack {
            Text("backup.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                appState.createBackup()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    refreshBackups()
                }
            }) {
                Label("backup.create".localized, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(appState.rimeDirectoryURL == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "backup.empty_title".localized,
            systemImage: "externaldrive",
            description: Text("backup.empty_desc".localized)
        )
    }

    // MARK: - Backup List

    private var backupList: some View {
        List(selection: $selectedBackup) {
            ForEach(backups, id: \.self) { backup in
                BackupRow(backup: backup)
                    .tag(backup)
                    .contextMenu {
                        Button("backup.restore".localized) {
                            restoreBackup(backup)
                        }
                        Divider()
                        Button("backup.delete".localized, role: .destructive) {
                            deleteBackup(backup)
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottomTrailing) {
            // Action buttons for selected backup
            if let backup = selectedBackup {
                HStack(spacing: 8) {
                    Button("backup.restore".localized) {
                        restoreBackup(backup)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("backup.delete".localized, role: .destructive) {
                        deleteBackup(backup)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
            }
        }
    }

    // MARK: - Actions

    private func refreshBackups() {
        backups = appState.importExport.listBackups(in: appState.rimeDirectoryURL)
    }

    private func restoreBackup(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "backup.restore_confirm_title".localized
        alert.informativeText = "backup.restore_confirm_message".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "backup.restore".localized)
        alert.addButton(withTitle: "common.cancel".localized)

        if alert.runModal() == .alertFirstButtonReturn {
            appState.importExport.restoreBackup(url, to: appState.rimeDirectoryURL)
            appState.reloadFiles()
            appState.configManager.loadAllConfigs(in: appState.rimeDirectoryURL)
        }
    }

    private func deleteBackup(_ url: URL) {
        appState.importExport.deleteBackup(url)
        refreshBackups()
        selectedBackup = nil
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: URL

    private var modifiedDate: Date? {
        (try? backup.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private var fileCount: Int {
        (try? FileManager.default.contentsOfDirectory(at: backup, includingPropertiesForKeys: nil))?.count ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text(backup.lastPathComponent)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let date = modifiedDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(fileCount) files")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
