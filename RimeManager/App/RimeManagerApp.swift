import SwiftUI
import AppKit

/// NSApplicationDelegate adapter to ensure proper app activation.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears as a regular GUI app (not background)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Configure window for Liquid Glass on macOS 26+
        configureWindowForGlass()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func configureWindowForGlass() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = NSApp.windows.first else { return }
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
        }
    }
}

@main
struct RimeManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "main_v6") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 750, minHeight: 500)
        }
        .defaultSize(width: 960, height: 680)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Rime Manager") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Rime Manager",
                            .applicationVersion: "1.1.0",
                            .credits: "A macOS tool for managing Rime input method configurations."
                        ]
                    )
                }
            }

            CommandGroup(after: .newItem) {
                Button("Open Rime Directory...") {
                    appState.selectRimeDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("File") {
                Button("Save") {
                    appState.saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.selectedFile == nil)

                Button("Reload") {
                    appState.reloadFiles()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Export File...") {
                    appState.exportSelectedFile()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.selectedFile == nil || appState.selectedFile?.isDirectory == true)

                Button("Export All Config...") {
                    appState.exportCurrentConfig()
                }
                .disabled(appState.rimeDirectoryURL == nil)

                Button("Import Config...") {
                    appState.importConfig()
                }
                .disabled(appState.rimeDirectoryURL == nil)

                Divider()

                Button("Create Backup") {
                    appState.createBackup()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(appState.rimeDirectoryURL == nil)

                Divider()

                Button("Deploy Rime") {
                    appState.deployRime()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(appState.rimeDirectoryURL == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
