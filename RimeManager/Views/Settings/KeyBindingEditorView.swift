import SwiftUI

/// 按键绑定可视化编辑器
struct KeyBindingEditorView: View {
    @EnvironmentObject private var appState: AppState

    private var kb: KeyBindingSettings { appState.configManager.keyBindingSettings }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("keybind.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { kb.add() }) {
                    Label("keybind.add".localized, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if kb.bindings.isEmpty {
                ContentUnavailableView(
                    "keybind.empty_title".localized,
                    systemImage: "keyboard",
                    description: Text("keybind.empty_desc".localized)
                )
            } else {
                List {
                    ForEach(kb.bindings) { binding in
                        KeyBindingRow(binding: binding, kb: kb)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { kb.bindings[$0].id }
                        for id in ids { kb.remove(id: id) }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("nav.keybind".localized)
    }
}

// MARK: - Single Row

private struct KeyBindingRow: View {
    let binding: KeyBindingSettings.KeyBinding
    @ObservedObject var kb: KeyBindingSettings

    private var idx: Int? {
        kb.bindings.firstIndex(where: { $0.id == binding.id })
    }

    var body: some View {
        HStack(spacing: 8) {
            // 触发时机
            Picker("", selection: whenBinding) {
                ForEach(KeyBindingSettings.whenOptions, id: \.self) { Text($0) }
            }
            .frame(width: 90)

            // 按键
            Picker("", selection: acceptBinding) {
                ForEach(KeyBindingSettings.keyOptions, id: \.self) { Text($0) }
            }
            .frame(width: 130)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // 动作
            Picker("", selection: actionBinding) {
                ForEach(KeyBindingSettings.actionOptions, id: \.self) { Text($0) }
            }
            .frame(width: 70)

            // 目标
            Picker("", selection: targetBinding) {
                ForEach(targetOptions, id: \.self) { Text($0) }
            }
            .frame(width: 130)

            Spacer()
        }
        .font(.caption)
        .padding(.vertical, 2)
    }

    // MARK: - Bindings

    private var whenBinding: Binding<String> {
        Binding(
            get: { binding.when },
            set: { if let i = idx { kb.bindings[i].when = $0 } }
        )
    }

    private var acceptBinding: Binding<String> {
        Binding(
            get: { binding.accept },
            set: { if let i = idx { kb.bindings[i].accept = $0 } }
        )
    }

    private var actionBinding: Binding<String> {
        Binding(
            get: { binding.action },
            set: { if let i = idx { kb.bindings[i].action = $0 } }
        )
    }

    private var targetBinding: Binding<String> {
        Binding(
            get: { binding.target },
            set: { if let i = idx { kb.bindings[i].target = $0 } }
        )
    }

    private var targetOptions: [String] {
        binding.action == "toggle"
            ? KeyBindingSettings.toggleTargets
            : KeyBindingSettings.sendTargets
    }
}
