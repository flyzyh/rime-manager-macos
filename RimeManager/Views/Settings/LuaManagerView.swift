import SwiftUI

/// Lua 扩展开关 + 反查配置
struct LuaManagerView: View {
    @EnvironmentObject private var appState: AppState

    private var lua: LuaSettings { appState.configManager.luaSettings }

    private var groupedByType: [(String, [LuaSettings.LuaEntry])] {
        let types = ["processor", "translator", "filter"]
        return types.compactMap { type in
            let entries = lua.luaEntries.filter { $0.type == type }
            return entries.isEmpty ? nil : (type, entries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Lua 脚本
                ForEach(groupedByType, id: \.0) { type, entries in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(typeTitle(type))
                            .font(.headline)

                        ForEach(entries) { entry in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { entry.enabled },
                                    set: { _ in lua.toggle(entry.id) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.scriptName)
                                        .font(.system(.body, design: .monospaced))
                                        .strikethrough(!entry.enabled, color: .secondary)
                                    if !entry.description.isEmpty {
                                        Text(entry.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                // 反查
                if !lua.reverseLookups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("lua.reverse_title".localized)
                            .font(.headline)

                        ForEach(Array(lua.reverseLookups.keys.sorted()), id: \.self) { name in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { lua.reverseLookups[name] ?? false },
                                    set: { lua.reverseLookups[name] = $0 }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()

                                Text(name)
                                    .font(.system(.body, design: .monospaced))
                                Text(lua.reverseLookups[name] == true ? "反查启用" : "反查停用")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
        }
        .navigationTitle("nav.lua".localized)
    }

    private func typeTitle(_ type: String) -> String {
        switch type {
        case "processor": return "lua.type_processor".localized
        case "translator": return "lua.type_translator".localized
        case "filter": return "lua.type_filter".localized
        default: return type
        }
    }
}
