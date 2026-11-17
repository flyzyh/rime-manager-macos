---
name: rime-patch-semantics
description: Rime 配置 patch 的层级合并规则与 Yams 库的坑（本项目修复 bug 时用部署产物实测验证）
metadata:
  node_type: memory
  type: project
  originSessionId: sess_b694f509-ff67-4e8a-9aa2-10e53cbe0763
---

rime-manager-macos 项目（Rime 配置管理 App）开发中的关键领域知识，2026-09-04 修复 6 个高危 bug 时用 `~/Library/Rime/build/` 编译产物实测验证：

1. **Rime patch 层级规则**：合并次序 default.yaml ← default.custom.yaml ← schema.yaml ← schema.custom.yaml；映射递归合并、**列表整体替换**。因此：schema.yaml 定义了的节点（如 rime_mint 的 `engine`/`switches`/`key_binder`/`menu`/`translator`/`punctuator`），patch 到 default.custom.yaml 不生效，必须写 rime_mint.custom.yaml；反之 `switcher`/`ascii_composer` 只有 default.yaml 定义，写 default.custom.yaml 才对。扁平键（`menu/page_size`、`switcher/hotkeys`、`key_binder/bindings/+`）是字面量键，Rime 按斜杠路径解析。
2. **patch 键冲突**：同一 patch 里 `key_binder` 与 `key_binder/bindings/+` 并存时应用顺序不确定，禁止同时出现（ConfigManager.buildDefaultCustomYAML 已做互斥处理）。
3. **Yams 库的坑**：`Yams.load` 遇到多文档直接 **throw**（dict.yaml 的词条正文在 `...` 之后的第二个文档）；`Yams.dump` 默认 `sortKeys: false` 键序随机，且会丢注释。改 YAML 要用文本块替换（见 DictSettings.generateYAML）。
4. **Rime 颜色字节序**：`0xAABBGGRR`（蓝高红低，与常见 RGB 相反），6 位以内的 Int 值补零必须补成 6 位（补成 8 位会把高字节 00 当 alpha=0 全透明）。
5. 验证配置是否生效的可靠方法：拷贝 ~/Library/Rime 到临时目录 → 跑生成逻辑 → 用 `/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer --build <dir> <SharedSupport>` 编译 → 检查 build/ 下编译产物。
