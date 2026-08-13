import SwiftUI

/// Manages app language for i18n, defaulting to system locale.
final class LocaleManager: ObservableObject, @unchecked Sendable {
    @Published var currentLocale: AppLocale {
        didSet { UserDefaults.standard.set(currentLocale.rawValue, forKey: "app_locale") }
    }

    static let shared = LocaleManager()

    enum AppLocale: String, CaseIterable {
        case system = "system"
        case zhHans = "zh-Hans"
        case zhHant = "zh-Hant"
        case en = "en"

        var displayName: String {
            switch self {
            case .system:
                let lang = LocaleManager.systemLanguageCode()
                switch lang {
                case "zh-Hans": return "跟随系统"
                case "zh-Hant": return "跟隨系統"
                default: return "System"
                }
            case .zhHans: return "简体中文"
            case .zhHant: return "繁體中文"
            case .en: return "English"
            }
        }

        var languageCode: String? {
            switch self {
            case .system: return nil
            case .zhHans: return "zh-Hans"
            case .zhHant: return "zh-Hant"
            case .en: return "en"
            }
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_locale") ?? "system"
        currentLocale = AppLocale(rawValue: saved) ?? .system
    }

    /// Resolve a localized string key to the current locale (safe from any context).
    static func localized(_ key: String) -> String {
        let locale = shared.currentLocale
        let lang = locale.languageCode ?? systemLanguageCode()
        return strings[key]?[lang] ?? strings[key]?["en"] ?? key
    }

    static func systemLanguageCode() -> String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        if lang == "zh" {
            let script = Locale.current.language.script?.identifier
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        return lang
    }

    // MARK: - String table

    static let strings: [String: [String: String]] = [
        "app.name": ["en": "Rime Manager", "zh-Hans": "Rime 配置管家", "zh-Hant": "Rime 配置管家"],
        "typing.title": ["en": "Typing", "zh-Hans": "输入行为", "zh-Hant": "輸入行為"],
        "typing.subtitle": ["en": "Input Settings", "zh-Hans": "输入方案设置", "zh-Hant": "輸入方案設置"],
        "typing.cn_en": ["en": "CN/EN", "zh-Hans": "中/英", "zh-Hant": "中/英"],
        "typing.simp_trad": ["en": "Simp/Trad", "zh-Hans": "简/繁", "zh-Hant": "簡/繁"],
        "typing.emoji": ["en": "Emoji", "zh-Hans": "Emoji", "zh-Hant": "Emoji"],
        "typing.full_half": ["en": "Full/Half", "zh-Hans": "全/半角", "zh-Hant": "全/半角"],
        "typing.english": ["en": "EN", "zh-Hans": "英", "zh-Hant": "英"],
        "typing.chinese": ["en": "中", "zh-Hans": "中", "zh-Hant": "中"],
        "typing.traditional": ["en": "繁", "zh-Hans": "繁", "zh-Hant": "繁"],
        "typing.simplified": ["en": "简", "zh-Hans": "简", "zh-Hant": "簡"],
        "typing.full": ["en": "全", "zh-Hans": "全", "zh-Hant": "全"],
        "typing.half": ["en": "半", "zh-Hans": "半", "zh-Hant": "半"],
        "typing.candidates": ["en": "Candidates per page", "zh-Hans": "每页候选数", "zh-Hant": "每頁候選數"],
        "typing.help_cnen": ["en": "Default input mode", "zh-Hans": "默认输入模式", "zh-Hant": "默認輸入模式"],
        "typing.help_trad": ["en": "Character set", "zh-Hans": "字符集", "zh-Hant": "字符集"],
        "typing.help_emoji": ["en": "Emoji suggestions", "zh-Hans": "表情建议", "zh-Hant": "表情建議"],
        "typing.help_full": ["en": "Full-width chars", "zh-Hans": "全角字符", "zh-Hant": "全角字符"],
        "appearance.title": ["en": "Appearance", "zh-Hans": "外观", "zh-Hant": "外觀"],
        "appearance.subtitle": ["en": "Skin Settings", "zh-Hans": "皮肤设置", "zh-Hant": "皮膚設置"],
        "appearance.layout": ["en": "Layout", "zh-Hans": "布局", "zh-Hant": "佈局"],
        "appearance.colors": ["en": "Colors", "zh-Hans": "配色", "zh-Hant": "配色"],
        "appearance.fonts": ["en": "Fonts", "zh-Hans": "字体", "zh-Hant": "字體"],
        "appearance.horizontal": ["en": "Horizontal", "zh-Hans": "横排", "zh-Hant": "橫排"],
        "appearance.vertical": ["en": "Vertical", "zh-Hans": "竖排", "zh-Hant": "豎排"],
        "appearance.opacity": ["en": "Opacity", "zh-Hans": "透明度", "zh-Hant": "透明度"],
        "appearance.corner": ["en": "Corner Radius", "zh-Hans": "圆角", "zh-Hant": "圓角"],
        "appearance.hl_radius": ["en": "Highlight Radius", "zh-Hans": "高亮圆角", "zh-Hant": "高亮圓角"],
        "appearance.translucent": ["en": "Translucent Background", "zh-Hans": "半透明背景", "zh-Hant": "半透明背景"],
        "appearance.blur": ["en": "Background Blur", "zh-Hans": "背景模糊", "zh-Hant": "背景模糊"],
        "appearance.light_scheme": ["en": "Light Scheme", "zh-Hans": "亮色方案", "zh-Hant": "亮色方案"],
        "appearance.dark_scheme": ["en": "Dark Scheme", "zh-Hans": "暗色方案", "zh-Hant": "暗色方案"],
        "appearance.light_colors": ["en": "Light Scheme Colors", "zh-Hans": "亮色配色编辑", "zh-Hant": "亮色配色編輯"],
        "appearance.dark_colors": ["en": "Dark Scheme Colors", "zh-Hans": "暗色配色编辑", "zh-Hant": "暗色配色編輯"],
        "preview.title": ["en": "Live Preview", "zh-Hans": "实时预览", "zh-Hant": "實時預覽"],
        "preview.input": ["en": "Test Pinyin Input", "zh-Hans": "测试拼音", "zh-Hant": "測試拼音"],
        "apply.title": ["en": "Apply & Deploy", "zh-Hans": "应用并部署", "zh-Hant": "應用並部署"],
        "apply.pending": ["en": "Changes not yet applied", "zh-Hans": "修改尚未应用", "zh-Hant": "修改尚未應用"],
        "config.loaded": ["en": "Config loaded", "zh-Hans": "配置已加载", "zh-Hant": "配置已加載"],
        "welcome.title": ["en": "Rime Manager", "zh-Hans": "Rime 配置管家", "zh-Hant": "Rime 配置管家"],
        "welcome.subtitle": ["en": "Elegant configuration for Rime", "zh-Hans": "优雅管理你的 Rime 输入法", "zh-Hant": "優雅管理你的 Rime 輸入法"],
        "welcome.open": ["en": "Open Rime Config Directory", "zh-Hans": "打开 Rime 配置目录", "zh-Hant": "打開 Rime 配置目錄"],
        "welcome.hint": ["en": "Usually at ~/Library/Rime", "zh-Hans": "通常位于 ~/Library/Rime", "zh-Hant": "通常位於 ~/Library/Rime"],
        "welcome.autodetect": ["en": "Auto-detect", "zh-Hans": "自动检测", "zh-Hant": "自動檢測"],
        "color.background": ["en": "Background", "zh-Hans": "背景", "zh-Hant": "背景"],
        "color.text": ["en": "Text / Input", "zh-Hans": "文字/输入", "zh-Hant": "文字/輸入"],
        "color.hl_bg": ["en": "Hilited BG", "zh-Hans": "高亮背景", "zh-Hant": "高亮背景"],
        "color.candidate": ["en": "Candidate Text", "zh-Hans": "候选文字", "zh-Hant": "候選文字"],
        "color.hl_cand": ["en": "Hilited Cand.", "zh-Hans": "选中候选", "zh-Hant": "選中候選"],
        "color.label": ["en": "Label", "zh-Hans": "序号", "zh-Hant": "序號"],
        "color.comment": ["en": "Comment", "zh-Hans": "注释", "zh-Hant": "註釋"],
        "color.border": ["en": "Border", "zh-Hans": "边框", "zh-Hant": "邊框"],
        "color.shadow": ["en": "Shadow", "zh-Hans": "阴影", "zh-Hant": "陰影"],
        "font.text": ["en": "Text", "zh-Hans": "文字", "zh-Hant": "文字"],
        "font.label": ["en": "Label", "zh-Hans": "序号", "zh-Hant": "序號"],
        "font.comment": ["en": "Comment", "zh-Hans": "注释", "zh-Hant": "註釋"],
        "layout.title": ["en": "Layout", "zh-Hans": "布局", "zh-Hant": "佈局"],
        "layout.horizontal": ["en": "Horizontal", "zh-Hans": "横排", "zh-Hant": "橫排"],
        "layout.vertical": ["en": "Vertical", "zh-Hans": "竖排", "zh-Hant": "豎排"],
        "font.title": ["en": "Font", "zh-Hans": "字体", "zh-Hant": "字體"],
        "opacity.title": ["en": "Opacity", "zh-Hans": "透明度", "zh-Hant": "透明度"],
        "corner.title": ["en": "Corner Radius", "zh-Hans": "圆角", "zh-Hant": "圓角"],
        "translucent.label": ["en": "Translucent Background", "zh-Hans": "半透明背景", "zh-Hant": "半透明背景"],
        "blur.label": ["en": "Background Blur", "zh-Hans": "背景模糊", "zh-Hant": "背景模糊"],
        "scheme.title": ["en": "Color Scheme", "zh-Hans": "配色方案", "zh-Hant": "配色方案"],
        "scheme.light": ["en": "Light", "zh-Hans": "亮色", "zh-Hant": "亮色"],
        "scheme.dark": ["en": "Dark", "zh-Hans": "暗色", "zh-Hant": "暗色"],
        "mode.title": ["en": "Default Mode", "zh-Hans": "默认模式", "zh-Hant": "默認模式"],
        "charset.title": ["en": "Character Set", "zh-Hans": "字符集", "zh-Hant": "字符集"],
        "candidates.title": ["en": "Candidates", "zh-Hans": "候选数", "zh-Hant": "候選數"],
        "emoji.label": ["en": "Emoji Suggestions", "zh-Hans": "Emoji 建议", "zh-Hant": "Emoji 建議"],
        "fullwidth.label": ["en": "Full-width Characters", "zh-Hans": "全角字符", "zh-Hant": "全角字符"],
        "schema.tab": ["en": "Schemas", "zh-Hans": "输入方案", "zh-Hant": "輸入方案"],
        "appearance.tab": ["en": "Appearance", "zh-Hans": "外观", "zh-Hant": "外觀"],
        "dicts.tab": ["en": "Dictionaries", "zh-Hans": "词库", "zh-Hant": "詞庫"],
        "backups.tab": ["en": "Backups", "zh-Hans": "备份", "zh-Hant": "備份"],
        "backup.btn": ["en": "Backup", "zh-Hans": "备份", "zh-Hant": "備份"],
        "save.btn": ["en": "Save", "zh-Hans": "保存", "zh-Hant": "保存"],

        // Error messages
        "error.file_read": ["en": "Failed to read file: %@", "zh-Hans": "读取文件失败：%@", "zh-Hant": "讀取檔案失敗：%@"],
        "error.file_write": ["en": "Failed to write %@: %@", "zh-Hans": "写入 %@ 失败：%@", "zh-Hant": "寫入 %@ 失敗：%@"],
        "error.yaml_parse": ["en": "YAML parse error: %@", "zh-Hans": "YAML 解析错误：%@", "zh-Hant": "YAML 解析錯誤：%@"],
        "error.deploy": ["en": "Deployment failed: %@", "zh-Hans": "部署失败：%@", "zh-Hant": "部署失敗：%@"],
        "error.import": ["en": "Import failed: %@", "zh-Hans": "导入失败：%@", "zh-Hant": "匯入失敗：%@"],
        "error.backup": ["en": "Backup failed: %@", "zh-Hans": "备份失败：%@", "zh-Hant": "備份失敗：%@"],
        "error.dir_not_set": ["en": "Rime directory not configured", "zh-Hans": "未配置 Rime 目录", "zh-Hant": "未配置 Rime 目錄"],
        "error.config_load": ["en": "Config load failed: %@", "zh-Hans": "配置加载失败：%@", "zh-Hant": "配置載入失敗：%@"],
        "alert.error_title": ["en": "Error", "zh-Hans": "错误", "zh-Hant": "錯誤"],

        // Toast messages
        "save.success": ["en": "Saved successfully", "zh-Hans": "保存成功", "zh-Hant": "儲存成功"],
        "deploy.success": ["en": "Rime deployed", "zh-Hans": "部署成功", "zh-Hant": "部署成功"],
        "deploy.failed": ["en": "Deploy failed", "zh-Hans": "部署失败", "zh-Hant": "部署失敗"],
        "export.success": ["en": "Exported successfully", "zh-Hans": "导出成功", "zh-Hant": "匯出成功"],
        "export.failed": ["en": "Export failed", "zh-Hans": "导出失败", "zh-Hant": "匯出失敗"],
        "import.success": ["en": "Imported successfully", "zh-Hans": "导入成功", "zh-Hant": "匯入成功"],
        "backup.success": ["en": "Backup created", "zh-Hans": "备份已创建", "zh-Hant": "備份已建立"],
        "backup.failed": ["en": "Backup failed", "zh-Hans": "备份失败", "zh-Hant": "備份失敗"],
        "backup.restored": ["en": "Backup restored", "zh-Hans": "备份已恢复", "zh-Hant": "備份已恢復"],
        "backup.deleted": ["en": "Backup deleted", "zh-Hans": "备份已删除", "zh-Hant": "備份已刪除"],

        // Dialogs
        "dialog.select_dir_title": ["en": "Select Rime Configuration Directory", "zh-Hans": "选择 Rime 配置目录", "zh-Hant": "選擇 Rime 配置目錄"],
        "dialog.select_dir_message": ["en": "Select your Rime configuration directory (usually ~/Library/Rime)", "zh-Hans": "选择 Rime 配置目录（通常位于 ~/Library/Rime）", "zh-Hant": "選擇 Rime 配置目錄（通常位於 ~/Library/Rime）"],
        "export.config_title": ["en": "Export Rime Configuration", "zh-Hans": "导出 Rime 配置", "zh-Hant": "匯出 Rime 配置"],
        "export.file_title": ["en": "Export File", "zh-Hans": "导出文件", "zh-Hant": "匯出檔案"],
        "import.title": ["en": "Import Rime Configuration", "zh-Hans": "导入 Rime 配置", "zh-Hant": "匯入 Rime 配置"],

        // Navigation sidebar
        "nav.config_section": ["en": "Configuration", "zh-Hans": "配置", "zh-Hant": "配置"],
        "nav.manage_section": ["en": "Management", "zh-Hans": "管理", "zh-Hant": "管理"],
        "nav.appearance": ["en": "Appearance", "zh-Hans": "外观", "zh-Hant": "外觀"],
        "nav.input": ["en": "Input", "zh-Hans": "输入", "zh-Hant": "輸入"],
        "nav.schemas": ["en": "Schemas", "zh-Hans": "输入方案", "zh-Hant": "輸入方案"],
        "nav.dicts": ["en": "Dictionaries", "zh-Hans": "词库", "zh-Hant": "詞庫"],
        "nav.backups": ["en": "Backups", "zh-Hans": "备份", "zh-Hant": "備份"],
        "nav.files": ["en": "Files", "zh-Hans": "文件", "zh-Hant": "檔案"],
        "nav.punct": ["en": "Punctuation", "zh-Hans": "标点", "zh-Hant": "標點"],
        "nav.keybind": ["en": "Key Bindings", "zh-Hans": "按键", "zh-Hant": "按鍵"],
        "nav.phrases": ["en": "Phrases", "zh-Hans": "短语", "zh-Hant": "短語"],
        "nav.lua": ["en": "Lua Extensions", "zh-Hans": "Lua 扩展", "zh-Hant": "Lua 擴展"],
        "nav.advanced": ["en": "Advanced", "zh-Hans": "高级", "zh-Hant": "高級"],
        "phrase.empty_title": ["en": "No Custom Phrases", "zh-Hans": "暂无自定义短语", "zh-Hant": "暫無自定義短語"],
        "phrase.empty_desc": ["en": "Add your first phrase above", "zh-Hans": "在上方添加第一条短语", "zh-Hant": "在上方添加第一條短語"],
        "phrase.search": ["en": "Search phrases", "zh-Hans": "搜索短语", "zh-Hant": "搜索短語"],
        "phrase.code_placeholder": ["en": "Code (e.g. mima)", "zh-Hans": "编码（如 mima）", "zh-Hant": "編碼（如 mima）"],
        "phrase.text_placeholder": ["en": "Phrase (e.g. 密码)", "zh-Hans": "短语（如 密码）", "zh-Hant": "短語（如 密碼）"],
        "phrase.delete": ["en": "Delete", "zh-Hans": "删除", "zh-Hant": "刪除"],
        "punct.half": ["en": "Half-width", "zh-Hans": "半角", "zh-Hant": "半角"],
        "punct.full": ["en": "Full-width", "zh-Hans": "全角", "zh-Hant": "全角"],
        "punct.hint": ["en": "Key to symbol mapping when typing", "zh-Hans": "输入按键时输出的符号映射", "zh-Hant": "輸入按鍵時輸出的符號映射"],
        "punct.key_placeholder": ["en": "Key", "zh-Hans": "按键", "zh-Hant": "按鍵"],
        "punct.value_placeholder": ["en": "Symbol", "zh-Hans": "符号", "zh-Hant": "符號"],
        "punct.delete": ["en": "Delete", "zh-Hans": "删除", "zh-Hant": "刪除"],
        "keybind.subtitle": ["en": "Customize keyboard shortcuts", "zh-Hans": "自定义键盘快捷键", "zh-Hant": "自定義鍵盤快捷鍵"],
        "keybind.add": ["en": "Add Binding", "zh-Hans": "添加绑定", "zh-Hant": "添加綁定"],
        "keybind.empty_title": ["en": "No Key Bindings", "zh-Hans": "暂无按键绑定", "zh-Hant": "暫無按鍵綁定"],
        "keybind.empty_desc": ["en": "Add a binding to customize shortcuts", "zh-Hans": "添加绑定来自定义快捷键", "zh-Hant": "添加綁定來自定義快捷鍵"],
        "lua.reverse_title": ["en": "Reverse Lookup", "zh-Hans": "反查", "zh-Hant": "反查"],
        "lua.type_processor": ["en": "Processors", "zh-Hans": "处理器", "zh-Hant": "處理器"],
        "lua.type_translator": ["en": "Translators", "zh-Hans": "翻译器", "zh-Hant": "翻譯器"],
        "lua.type_filter": ["en": "Filters", "zh-Hans": "过滤器", "zh-Hant": "過濾器"],
        "adv.sync_title": ["en": "Sync", "zh-Hans": "同步", "zh-Hant": "同步"],
        "adv.install_id": ["en": "Install ID", "zh-Hans": "安装标识", "zh-Hant": "安裝標識"],
        "adv.sync_dir": ["en": "Sync Directory", "zh-Hans": "同步目录", "zh-Hant": "同步目錄"],
        "adv.distro": ["en": "Distribution", "zh-Hans": "发行版", "zh-Hant": "發行版"],
        "adv.opencc_title": ["en": "Chinese Conversion (OpenCC)", "zh-Hans": "简繁转换（OpenCC）", "zh-Hant": "簡繁轉換（OpenCC）"],
        "adv.switcher_title": ["en": "Schema Switcher", "zh-Hans": "方案切换", "zh-Hant": "方案切換"],
        "adv.hotkey": ["en": "Hotkey", "zh-Hans": "快捷键", "zh-Hant": "快捷鍵"],
        "adv.userdb_title": ["en": "User Dictionary", "zh-Hans": "用户词库", "zh-Hant": "用戶詞庫"],
        "adv.userdb_size": ["en": "Size", "zh-Hans": "占用空间", "zh-Hant": "佔用空間"],
        "adv.clear_userdb": ["en": "Clear User Dictionary", "zh-Hans": "清空用户词库", "zh-Hant": "清空用戶詞庫"],
        "adv.clear_confirm": ["en": "Clear all learned words? This cannot be undone.", "zh-Hans": "确定清空所有学习过的词？此操作不可恢复。", "zh-Hant": "確定清空所有學習過的詞？此操作不可恢復。"],
        "adv.clear_action": ["en": "Clear", "zh-Hans": "清空", "zh-Hant": "清空"],
        "adv.clear_done": ["en": "User dictionary cleared", "zh-Hans": "用户词库已清空", "zh-Hant": "用戶詞庫已清空"],

        // Toolbar
        "toolbar.apply_deploy": ["en": "Apply & Deploy", "zh-Hans": "应用并部署", "zh-Hant": "應用並部署"],
        "toolbar.open_config_dir": ["en": "Open Config Directory", "zh-Hans": "打开配置目录", "zh-Hant": "開啟設定目錄"],
        "toolbar.more": ["en": "More", "zh-Hans": "更多", "zh-Hant": "更多"],

        // Appearance settings
        "appearance.section_layout": ["en": "Layout", "zh-Hans": "布局", "zh-Hant": "佈局"],
        "appearance.section_font": ["en": "Font", "zh-Hans": "字体", "zh-Hant": "字體"],
        "appearance.section_effects": ["en": "Effects", "zh-Hans": "效果", "zh-Hant": "效果"],
        "appearance.section_colors": ["en": "Color Scheme", "zh-Hans": "配色方案", "zh-Hant": "配色方案"],
        "appearance.orientation": ["en": "Orientation", "zh-Hans": "排列方向", "zh-Hant": "排列方向"],
        "appearance.inline_preedit": ["en": "Inline Preedit", "zh-Hans": "内嵌编码", "zh-Hant": "內嵌編碼"],
        "appearance.show_paging": ["en": "Show Paging", "zh-Hans": "显示翻页", "zh-Hant": "顯示翻頁"],
        "appearance.font_face": ["en": "Font Family", "zh-Hans": "字体", "zh-Hant": "字體"],
        "appearance.font_size": ["en": "Font Size", "zh-Hans": "字号", "zh-Hant": "字號"],
        "appearance.label_font": ["en": "Label Font", "zh-Hans": "序号字体", "zh-Hant": "序號字體"],
        "appearance.label_size": ["en": "Label Size", "zh-Hans": "序号字号", "zh-Hant": "序號字號"],
        "appearance.alpha": ["en": "Opacity", "zh-Hans": "透明度", "zh-Hant": "透明度"],
        "appearance.corner_radius": ["en": "Corner Radius", "zh-Hans": "圆角", "zh-Hant": "圓角"],
        "appearance.hilited_radius": ["en": "Highlight Radius", "zh-Hans": "高亮圆角", "zh-Hant": "高亮圓角"],
        "appearance.translucency": ["en": "Translucent", "zh-Hans": "半透明", "zh-Hant": "半透明"],
        "appearance.preview_mode": ["en": "Preview", "zh-Hans": "预览", "zh-Hant": "預覽"],
        "appearance.preview_light": ["en": "Light", "zh-Hans": "亮色", "zh-Hant": "亮色"],
        "appearance.preview_dark": ["en": "Dark", "zh-Hans": "暗色", "zh-Hant": "暗色"],

        // Input settings
        "input.section_mode": ["en": "Default Mode", "zh-Hans": "默认模式", "zh-Hant": "預設模式"],
        "input.section_candidates": ["en": "Candidates", "zh-Hans": "候选", "zh-Hant": "候選"],
        "input.section_switches": ["en": "Switches", "zh-Hans": "开关", "zh-Hant": "開關"],
        "input.section_keyboard": ["en": "Keyboard", "zh-Hans": "键盘", "zh-Hant": "鍵盤"],
        "input.mode": ["en": "Input Mode", "zh-Hans": "输入模式", "zh-Hant": "輸入模式"],
        "input.chinese": ["en": "Chinese", "zh-Hans": "中文", "zh-Hant": "中文"],
        "input.english": ["en": "English", "zh-Hans": "English", "zh-Hant": "English"],
        "input.charset": ["en": "Character Set", "zh-Hans": "字符集", "zh-Hant": "字元集"],
        "input.simplified": ["en": "Simplified", "zh-Hans": "简体", "zh-Hant": "簡體"],
        "input.traditional": ["en": "Traditional", "zh-Hans": "繁体", "zh-Hant": "繁體"],
        "input.candidate_count": ["en": "Candidates per Page", "zh-Hans": "每页候选数", "zh-Hant": "每頁候選數"],
        "input.emoji": ["en": "Emoji Suggestions", "zh-Hans": "Emoji 建议", "zh-Hant": "Emoji 建議"],
        "input.fullwidth": ["en": "Full-width Characters", "zh-Hans": "全角字符", "zh-Hant": "全形字元"],
        "input.tone": ["en": "Tone Display", "zh-Hans": "声调显示", "zh-Hant": "聲調顯示"],
        "input.capslock": ["en": "Caps Lock to Switch", "zh-Hans": "Caps Lock 切换", "zh-Hant": "Caps Lock 切換"],
        "input.shift_behavior": ["en": "Shift Key Behavior", "zh-Hans": "Shift 键行为", "zh-Hant": "Shift 鍵行為"],

        // Schema list
        "schema.current": ["en": "Current", "zh-Hans": "当前", "zh-Hant": "當前"],
        "schema.default": ["en": "Default", "zh-Hans": "默认", "zh-Hant": "預設"],
        "schema.set_default": ["en": "Set as Default", "zh-Hans": "设为默认", "zh-Hant": "設為預設"],
        "schema.switch_hint": ["en": "Ctrl+` to switch", "zh-Hans": "Ctrl+` 切换", "zh-Hant": "Ctrl+` 切換"],

        // Dict list
        "dict.empty": ["en": "No dictionaries", "zh-Hans": "暂无词库", "zh-Hant": "暫無詞庫"],

        // Backup list
        "backup.create": ["en": "Create Backup", "zh-Hans": "创建备份", "zh-Hant": "建立備份"],
        "backup.empty": ["en": "No backups", "zh-Hans": "暂无备份", "zh-Hant": "暫無備份"],
        "backup.restore": ["en": "Restore", "zh-Hans": "恢复", "zh-Hant": "恢復"],
        "backup.delete": ["en": "Delete", "zh-Hans": "删除", "zh-Hant": "刪除"],
        "backup.subtitle": ["en": "Manage configuration backups", "zh-Hans": "管理配置备份", "zh-Hant": "管理配置備份"],
        "backup.empty_title": ["en": "No Backups", "zh-Hans": "暂无备份", "zh-Hant": "暫無備份"],
        "backup.empty_desc": ["en": "Create a backup to protect your configuration", "zh-Hans": "创建备份以保护您的配置", "zh-Hant": "建立備份以保護您的配置"],
        "backup.restore_confirm_title": ["en": "Restore Backup", "zh-Hans": "恢复备份", "zh-Hant": "恢復備份"],
        "backup.restore_confirm_message": ["en": "This will overwrite current configuration. A safety backup will be created first.", "zh-Hans": "这将覆盖当前配置。会先创建一个安全备份。", "zh-Hant": "這將覆蓋當前配置。會先建立一個安全備份。"],

        // Common
        "common.cancel": ["en": "Cancel", "zh-Hans": "取消", "zh-Hant": "取消"],
        "common.confirm": ["en": "Confirm", "zh-Hans": "确认", "zh-Hant": "確認"],
        "common.ok": ["en": "OK", "zh-Hans": "好", "zh-Hant": "好"],

        // Input settings (additional)
        "input.language": ["en": "Language", "zh-Hans": "语言", "zh-Hant": "語言"],
        "input.tradition": ["en": "Character Set", "zh-Hans": "字符集", "zh-Hant": "字元集"],
        "input.section_candidate": ["en": "Candidates", "zh-Hans": "候选", "zh-Hant": "候選"],
        "input.page_size": ["en": "Candidates per Page", "zh-Hans": "每页候选数", "zh-Hant": "每頁候選數"],
        "input.show_paging": ["en": "Show Paging", "zh-Hans": "显示翻页", "zh-Hant": "顯示翻頁"],
        "input.full_shape": ["en": "Full-width Characters", "zh-Hans": "全角字符", "zh-Hant": "全形字元"],
        "input.tone_display": ["en": "Tone Display", "zh-Hans": "声调显示", "zh-Hant": "聲調顯示"],
        "input.caps_lock": ["en": "Caps Lock to Switch", "zh-Hans": "Caps Lock 切换", "zh-Hant": "Caps Lock 切換"],
        "input.shift_commit_code": ["en": "Commit Code", "zh-Hans": "提交编码", "zh-Hant": "提交編碼"],
        "input.shift_commit_text": ["en": "Commit Text", "zh-Hans": "提交文字", "zh-Hant": "提交文字"],
        "input.shift_inline_ascii": ["en": "Inline ASCII", "zh-Hans": "内嵌英文", "zh-Hant": "內嵌英文"],
        "input.shift_clear": ["en": "Clear", "zh-Hans": "清除", "zh-Hant": "清除"],
        "input.shift_noop": ["en": "No Action", "zh-Hans": "无操作", "zh-Hant": "無操作"],

        // Schema list (additional)
        "schema.subtitle": ["en": "Manage input schemas", "zh-Hans": "管理输入方案", "zh-Hant": "管理輸入方案"],
        "schema.refresh": ["en": "Refresh", "zh-Hans": "刷新", "zh-Hant": "重新整理"],
        "schema.empty_title": ["en": "No Schemas", "zh-Hans": "暂无方案", "zh-Hant": "暫無方案"],
        "schema.empty_desc": ["en": "No input schemas found in Rime directory", "zh-Hans": "Rime 目录中未找到输入方案", "zh-Hant": "Rime 目錄中未找到輸入方案"],
        "schema.default_badge": ["en": "Default", "zh-Hans": "默认", "zh-Hant": "預設"],

        // Dict list (additional)
        "dict.subtitle": ["en": "Manage dictionary imports", "zh-Hans": "管理词库导入", "zh-Hant": "管理詞庫匯入"],
        "dict.enable_all": ["en": "Enable All", "zh-Hans": "全部启用", "zh-Hant": "全部啟用"],
        "dict.disable_all": ["en": "Disable All", "zh-Hans": "全部禁用", "zh-Hant": "全部停用"],
        "dict.batch": ["en": "Batch", "zh-Hans": "批量", "zh-Hant": "批量"],
        "dict.empty_title": ["en": "No Dictionaries", "zh-Hans": "暂无词库", "zh-Hant": "暫無詞庫"],
        "dict.empty_desc": ["en": "No dictionary imports configured", "zh-Hans": "未配置词库导入", "zh-Hant": "未配置詞庫匯入"],

        // File editor
        "files.toggle_preview": ["en": "Toggle Preview", "zh-Hans": "切换预览", "zh-Hant": "切換預覽"],
        "files.no_selection": ["en": "No File Selected", "zh-Hans": "未选择文件", "zh-Hant": "未選擇檔案"],
        "files.no_selection_desc": ["en": "Select a file from the sidebar to edit", "zh-Hans": "从侧边栏选择文件进行编辑", "zh-Hant": "從側邊欄選擇檔案進行編輯"],

        // Appearance - new layout options
        "appearance.candidate_layout": ["en": "Candidate Layout", "zh-Hans": "候选排列", "zh-Hant": "候選排列"],
        "appearance.layout_linear": ["en": "Linear", "zh-Hans": "线性", "zh-Hant": "線性"],
        "appearance.layout_stacked": ["en": "Stacked", "zh-Hans": "堆叠", "zh-Hant": "堆疊"],
        "appearance.layout_tabled": ["en": "Tabled", "zh-Hans": "表格", "zh-Hant": "表格"],
        "appearance.inline_candidate": ["en": "Inline Candidate", "zh-Hans": "内嵌候选", "zh-Hant": "內嵌候選"],
        "appearance.mutual_exclusive": ["en": "Color Exclusive", "zh-Hans": "颜色不叠加", "zh-Hant": "顏色不疊加"],
        "appearance.remember_size": ["en": "Remember Panel Size", "zh-Hans": "记住面板尺寸", "zh-Hant": "記住面板尺寸"],
        "appearance.candidate_format": ["en": "Candidate Format", "zh-Hans": "候选格式", "zh-Hant": "候選格式"],
        "appearance.status_message": ["en": "Status Message", "zh-Hans": "状态通知样式", "zh-Hant": "狀態通知樣式"],
        "appearance.comment_font": ["en": "Comment Font", "zh-Hans": "注释字体", "zh-Hant": "註釋字體"],
        "appearance.comment_size": ["en": "Comment Size", "zh-Hans": "注释字号", "zh-Hant": "註釋字號"],

        // Appearance - spacing & border
        "appearance.section_spacing": ["en": "Spacing & Border", "zh-Hans": "间距与边框", "zh-Hant": "間距與邊框"],
        "appearance.line_spacing": ["en": "Line Spacing", "zh-Hans": "行间距", "zh-Hant": "行間距"],
        "appearance.spacing": ["en": "Preedit Spacing", "zh-Hans": "预编辑间距", "zh-Hant": "預編輯間距"],
        "appearance.border_height": ["en": "Border Height", "zh-Hans": "边框高度", "zh-Hant": "邊框高度"],
        "appearance.border_width": ["en": "Border Width", "zh-Hans": "边框宽度", "zh-Hant": "邊框寬度"],
        "appearance.shadow_size": ["en": "Shadow Size", "zh-Hans": "阴影大小", "zh-Hant": "陰影大小"],

        // Input - engine
        "input.section_engine": ["en": "Input Engine", "zh-Hans": "输入引擎", "zh-Hant": "輸入引擎"],
        "input.enable_encoder": ["en": "Auto Word Creation", "zh-Hans": "自动造词", "zh-Hant": "自動造詞"],
        "input.enable_sentence": ["en": "Sentence Input", "zh-Hans": "整句输入", "zh-Hant": "整句輸入"],
        "input.enable_user_dict": ["en": "User Dictionary", "zh-Hans": "用户词典", "zh-Hant": "用戶詞典"],
        "input.encode_commit_history": ["en": "Encode Commit History", "zh-Hans": "自动编码历史", "zh-Hant": "自動編碼歷史"],
        "input.ascii_punct": ["en": "Western Punctuation", "zh-Hans": "西文标点", "zh-Hant": "西文標點"],

        // Input - notifications
        "input.section_notifications": ["en": "Notifications", "zh-Hans": "通知", "zh-Hant": "通知"],
        "input.show_notifications": ["en": "Show Notifications", "zh-Hans": "显示通知", "zh-Hant": "顯示通知"],
        "input.notif_always": ["en": "Always", "zh-Hans": "始终", "zh-Hant": "始終"],
        "input.notif_appropriate": ["en": "Appropriate", "zh-Hans": "适时", "zh-Hant": "適時"],
        "input.notif_never": ["en": "Never", "zh-Hans": "从不", "zh-Hant": "從不"],

        // Input - app options
        "input.section_app_options": ["en": "App-Specific Rules", "zh-Hans": "应用专属规则", "zh-Hant": "應用專屬規則"],
        "input.add_app_rule": ["en": "Add Rule", "zh-Hans": "添加规则", "zh-Hant": "添加規則"],
        "input.app_options_footer": ["en": "Configure input behavior per application. Browser rules (Safari/Chrome/Edge) are always included.", "zh-Hans": "按应用配置输入行为。浏览器规则（Safari/Chrome/Edge）始终包含。", "zh-Hant": "按應用配置輸入行為。瀏覽器規則（Safari/Chrome/Edge）始終包含。"],
    ]
}

// MARK: - Convenience

extension String {
    var localized: String { LocaleManager.localized(self) }
}
