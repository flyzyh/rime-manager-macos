# Changelog

## v1.4.0 — 2026-11-13

### 配置写入语义修复

- 修正输入引擎开关写入层级：`enable_encoder`、`enable_sentence`、`enable_user_dict`、`encode_commit_history` 现在写入 `rime_mint.custom.yaml`，确保对 `rime_mint` 方案生效。
- 自定义短语改为 Rime 标准的 `短语 \t 编码 \t 权重` 顺序，修复旧版本“编码/短语”反向写入导致的候选异常。
- 当当前方案未加载 `custom_phrase.txt` 时，短语页会明确提示，并提供一键接入 `table_translator@custom_phrase`。
- Squirrel 外观、配色、应用规则改为字段级 patch（`style/*`、`preset_color_schemes/*`、`app_options/*`），不再整体替换节点，保留未建模字段和其他配色方案。
- 标点映射改为 `punctuator/half_shape` / `punctuator/full_shape` 子路径 patch，保留 `punctuator.import_preset`。
- `ascii_composer` 不再硬编码覆盖 `Shift_R`、`Control_L`、`Control_R`、`Caps_Lock`；只写用户实际管理的按键行为。
- Return 直接上屏从隐藏行为改为显式开关，且避免重复绑定。

### 引擎与补丁兼容性

- 新增 Rime patch 形态归一化：支持读取并安全重写 `engine/.../+:`、`engine/.../@N:`。
- switches 优先使用 `switches/@N/reset`，避免覆盖未管理项；已有完整 switches patch 时按完整列表安全更新。
- 被旧 patch 禁用的 Lua 条目仍会显示并可恢复。
- OpenCC 只显示当前方案实际存在的 simplifier，追加项也可关闭。

### 词典、方案与状态同步

- 词典管理跟随当前方案 effective `translator/dictionary`，不再硬编码 `rime_mint.dict.yaml`。
- 支持 multi-document dict YAML 校验，保留词典正文、注释和文档分隔符。
- 词库读取支持 UTF-8 / GB18030 fallback。
- 方案扫描覆盖 Squirrel SharedSupport，排除 `build/`、备份和同步目录。
- 外部文件变更或内置原始编辑器保存后，立即重建设置模型，避免后续“应用”用旧状态覆盖新文件。
- 所有生成内容先统一校验再写盘，减少中断后的“半新半旧”配置状态。

### 界面与高级设置

- 方案切换快捷键支持多值编辑。
- 当前方案未接入自定义短语时，短语页显示警告与接入按钮。
- `installation_id` 非空后禁止误清空。
- `sync_dir` 保存时展开 `~` 为绝对路径。

### 升级提示

- 旧的 nested 外观/标点 patch 会在下一次“应用并部署”时自动迁移为字段级 slash path。
- 如果此前依赖旧版本自动写入的 Return 绑定，请在“输入行为”中查看新的 Return 开关。
- 自定义短语文件按新列序解析；如手工维护，请使用 `短语 \t 编码 \t 权重`。

## v1.3.1

- 修复候选词数量配置层级错误（schema 层 `page_size` 需 patch 到 `rime_mint.custom.yaml`）。
- 恢复备份后自动重启输入法，外观配置真正生效。
- 新增“液态玻璃”配色方案。
- 修正 Squirrel 颜色字节序为 `0xAABBGGRR`。
- 修复多个破坏性配置写入问题：engine/translator 列表覆盖、`installation.yaml` 字段抹除等。
- 部署改为完全重启 Squirrel，确保面板外观生效。

## v1.3.0

- 自定义短语编辑器。
- 标点映射编辑器（半角/全角）。
- 按键绑定可视化。
- Lua 扩展开关。
- 高级设置（同步、OpenCC、方案切换快捷键、用户词库）。
- 词库词条数统计与侧边栏数量徽章。
- 官方 Rime 图标。

## v1.2.0

- macOS 设置风格界面（`NavigationSplitView`）。
- 按应用独立配置、Toast 反馈、液态玻璃窗口。
