import SwiftUI

/// 高级设置：同步 / OpenCC 简繁 / 方案切换快捷键 / 用户词库
struct AdvancedSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var confirmClear = false

    private var adv: AdvancedSettings { appState.configManager.advancedSettings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                syncSection
                openccSection
                switcherSection
                userdbSection
            }
            .padding(20)
        }
        .navigationTitle("nav.advanced".localized)
        .confirmationDialog("adv.clear_confirm".localized, isPresented: $confirmClear) {
            Button("adv.clear_action".localized, role: .destructive) {
                if let dir = appState.rimeDirectoryURL {
                    _ = adv.clearUserDB(in: dir)
                    adv.scanUserDB(in: dir)
                    FeedbackManager.shared.showSuccess("adv.clear_done".localized)
                }
            }
        }
    }

    // MARK: - 同步设置

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("adv.sync_title".localized).font(.headline)

            HStack {
                Text("adv.install_id".localized).font(.caption).foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                TextField("installation_id", text: Binding(
                    get: { adv.installationID },
                    set: { adv.installationID = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .disabled(!adv.installationID.isEmpty)
            }

            HStack {
                Text("adv.sync_dir".localized).font(.caption).foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                TextField("~/Library/Rime/sync", text: Binding(
                    get: { adv.syncDir },
                    set: { adv.syncDir = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            if !adv.distributionName.isEmpty {
                HStack {
                    Text("adv.distro".localized).font(.caption).foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Text(adv.distributionName).font(.caption)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - OpenCC 简繁转换

    private var openccSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("adv.opencc_title".localized).font(.headline)

            ForEach(Array(adv.enabledSimplifiers.keys.sorted()), id: \.self) { chain in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { adv.enabledSimplifiers[chain] ?? false },
                        set: { adv.enabledSimplifiers[chain] = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()

                    Text(chain)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 140, alignment: .leading)

                    Text(AdvancedSettings.openccChains[chain] ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.vertical, 1)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 方案切换快捷键

    private var switcherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("adv.switcher_title".localized).font(.headline)

            ForEach(adv.switcherHotkeys.indices, id: \.self) { index in
                HStack {
                    Text(index == 0 ? "adv.hotkey".localized : "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    TextField("Control+grave", text: Binding(
                        get: { adv.switcherHotkeys.indices.contains(index) ? adv.switcherHotkeys[index] : "" },
                        set: { if adv.switcherHotkeys.indices.contains(index) { adv.switcherHotkeys[index] = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                    Button {
                        adv.switcherHotkeys.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(adv.switcherHotkeys.count <= 1)
                }
            }

            Button {
                adv.switcherHotkeys.append("Control+grave")
            } label: {
                Label("adv.hotkey.add".localized, systemImage: "plus.circle")
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 用户词库

    private var userdbSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("adv.userdb_title".localized).font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("adv.userdb_size".localized).font(.caption).foregroundStyle(.secondary)
                    Text(adv.userdbSize.isEmpty ? "--" : adv.userdbSize).font(.body)
                }
                Spacer()
                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Label("adv.clear_userdb".localized, systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
