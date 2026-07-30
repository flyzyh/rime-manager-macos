import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var deployStep: DeployStep = .checking

    enum DeployStep {
        case checking, needDeploy, done, error(String)
    }

    private let deployService = DeployService()

    var body: some View {
        Group {
            switch deployStep {
            case .checking: checkingView
            case .needDeploy: welcomeView
            case .done: MainView()
            case .error(let msg): errorView(msg)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            checkSetup()
        }
    }

    private func checkSetup() {
        if deployService.isRimeConfigured {
            appState.autoDetectRimeDirectory()
            deployStep = .done
        } else {
            deployStep = .needDeploy
        }
    }

    private var checkingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(0.8)
            Text("Checking...").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.fill").font(.system(size: 48)).foregroundStyle(.blue)
            Text("Rime Manager").font(.largeTitle).fontWeight(.bold)
            Text("No Rime configuration detected.\nPlease install oh-my-rime (薄荷拼音) first.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)

            Link(destination: URL(string: "https://github.com/Mintimate/oh-my-rime")!) {
                Label("Download oh-my-rime", systemImage: "arrow.down.circle.fill").frame(width: 220)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            Button("I already installed, detect again") { checkSetup() }.buttonStyle(.link)
            Button("Open directory manually...") { appState.selectRimeDirectory(); deployStep = .done }.buttonStyle(.link)
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 48)).foregroundStyle(.red)
            Text("Failed").font(.title).fontWeight(.bold)
            Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { checkSetup() }.buttonStyle(.borderedProminent)
            Button("Open manually") { appState.selectRimeDirectory(); deployStep = .done }.buttonStyle(.link)
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
