import SwiftUI

/// Navigation sidebar items for the main settings interface.
enum SidebarItem: String, CaseIterable, Identifiable {
    case appearance
    case input
    case schemas
    case dicts
    case backups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "nav.appearance".localized
        case .input: return "nav.input".localized
        case .schemas: return "nav.schemas".localized
        case .dicts: return "nav.dicts".localized
        case .backups: return "nav.backups".localized
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintpalette"
        case .input: return "keyboard"
        case .schemas: return "list.bullet.rectangle"
        case .dicts: return "books.vertical"
        case .backups: return "externaldrive"
        }
    }

    var section: SidebarSection {
        switch self {
        case .appearance, .input, .schemas, .dicts: return .config
        case .backups: return .manage
        }
    }
}

enum SidebarSection: String, CaseIterable {
    case config
    case manage

    var title: String {
        switch self {
        case .config: return "nav.config_section".localized
        case .manage: return "nav.manage_section".localized
        }
    }
}

/// Main view with NavigationSplitView layout (macOS Settings style).
struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var feedback = FeedbackManager.shared
    @ObservedObject private var locale = LocaleManager.shared

    @State private var selectedItem: SidebarItem? = .appearance

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .background(.regularMaterial)
        }
        .navigationSplitViewStyle(.automatic)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appState.applyAllConfigChanges()
                    appState.deployRime()
                }) {
                    Label("toolbar.apply_deploy".localized, systemImage: "checkmark.icloud")
                }
                .disabled(appState.rimeDirectoryURL == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if let url = appState.rimeDirectoryURL {
                        NSWorkspace.shared.open(url)
                    } else {
                        appState.selectRimeDirectory()
                    }
                }) {
                    Image(systemName: "folder")
                }
                .help("toolbar.open_config_dir".localized)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: { appState.saveCurrentFile() }) {
                        Label("save.btn".localized, systemImage: "square.and.arrow.down")
                    }
                    .disabled(appState.selectedFile == nil)

                    Divider()

                    Button(action: { appState.exportCurrentConfig() }) {
                        Label("export.config_title".localized, systemImage: "square.and.arrow.up")
                    }

                    Button(action: { appState.importConfig() }) {
                        Label("import.title".localized, systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    Button(action: { appState.createBackup() }) {
                        Label("backup.create".localized, systemImage: "externaldrive.badge.plus")
                    }

                    Divider()

                    Button(action: { appState.selectRimeDirectory() }) {
                        Label("dialog.select_dir_title".localized, systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = feedback.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: feedback.toast?.id)
        .id(locale.currentLocale)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                Section(section.title) {
                    ForEach(SidebarItem.allCases.filter { $0.section == section }) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        HStack {
            Picker("", selection: Binding(
                get: { locale.currentLocale },
                set: { locale.currentLocale = $0 }
            )) {
                ForEach(LocaleManager.AppLocale.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .appearance:
            AppearanceSettingsView()
        case .input:
            InputSettingsView()
        case .schemas:
            SchemaListView()
        case .dicts:
            DictListView()
        case .backups:
            BackupListView()
        case nil:
            ContentUnavailableView(
                "nav.appearance".localized,
                systemImage: "sidebar.left",
                description: Text("Select an item from the sidebar")
            )
        }
    }

}
