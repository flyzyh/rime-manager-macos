import SwiftUI
import Yams

/// 按键绑定可视化管理（key_binder bindings）
@MainActor
final class KeyBindingSettings: ObservableObject {
    @Published var bindings: [KeyBinding] = []

    struct KeyBinding: Identifiable {
        let id = UUID()
        var when: String        // always / composing / paging / has_menu / predicting
        var accept: String      // 触发键，如 Control+p
        var action: String      // send / toggle / select
        var target: String      // 目标，如 Up / ascii_mode / .next
        var comment: String = ""
    }

    // MARK: - 常用按键选项

    static let whenOptions = ["always", "composing", "paging", "has_menu", "predicting"]
    static let actionOptions = ["send", "toggle", "select"]
    static let keyOptions = [
        "space", "Return", "Tab", "BackSpace", "Escape", "Delete",
        "Up", "Down", "Left", "Right", "Home", "End",
        "Page_Up", "Page_Down",
        "minus", "equal", "comma", "period", "slash", "grave", "bracketleft", "bracketright",
        "Control+space", "Control+p", "Control+n", "Control+grave", "Control+comma", "Control+period",
        "Shift+space", "Shift+Tab", "Alt+v", "Control+Shift+1", "Control+Shift+2", "Control+Shift+3", "Control+Shift+4", "Control+Shift+5",
    ]
    static let toggleTargets = ["ascii_mode", "full_shape", "transcription", "extended_charset", "ascii_punct", "emoji_suggestion"]
    static let sendTargets = ["Up", "Down", "Left", "Right", "Home", "End", "Delete", "Escape", "Page_Up", "Page_Down", "Return", "space", "comma", "period", "Shift+Left", "Shift+Right", "Shift+Delete"]

    // MARK: - Load

    func load(schemaYAML: String, defaultYAML: String) {
        var dicts: [[String: Any]] = []

        // 从 default.yaml 读取
        if let d = try? Yams.load(yaml: defaultYAML) as? [String: Any],
           let kb = d["key_binder"] as? [String: Any],
           let b = kb["bindings"] as? [[String: Any]] {
            dicts = b
        }

        // 从 schema 读取并合并
        if let d = try? Yams.load(yaml: schemaYAML) as? [String: Any],
           let kb = d["key_binder"] as? [String: Any],
           let b = kb["bindings"] as? [[String: Any]] {
            for item in b { dicts.append(item) }
        }

        bindings = dicts.compactMap { dict in
            guard let accept = dict["accept"] as? String else { return nil }
            let when = dict["when"] as? String ?? "always"
            var action = "send"
            var target = ""
            if let t = dict["toggle"] as? String { action = "toggle"; target = t }
            else if let s = dict["select"] as? String { action = "select"; target = s }
            else if let s = dict["send"] as? String { action = "send"; target = s }
            else if let s = dict["send"] as? Int { action = "send"; target = String(s) } // 小键盘数字映射
            return KeyBinding(when: when, accept: accept, action: action, target: target)
        }
    }

    // MARK: - CRUD

    func add(when: String = "always", accept: String = "Control+space", action: String = "toggle", target: String = "ascii_mode") {
        bindings.append(KeyBinding(when: when, accept: accept, action: action, target: target))
    }

    func remove(id: UUID) {
        bindings.removeAll { $0.id == id }
    }

    // MARK: - Generate

    func generateBindings() -> [[String: Any]] {
        bindings.map { b in
            var dict: [String: Any] = ["when": b.when, "accept": b.accept]
            dict[b.action] = b.target
            return dict
        }
    }
}
