---
name: project-rime-manager-writeback-rules
description: rime-manager-macos 回写架构的四条铁律：基底保留+deepMerge、变更检测快照必须覆盖全部可编辑字段、patch 键互斥、读写形态对称
metadata:
  type: project
  source: 2026-09-04 全量代码审查修复 10 类 bug 后沉淀（含 1 个修复过程引入又当场修复的回归）
---

**现象**：本项目的 bug 高度集中在"设置改了但没生效/被静默还原/丢用户手工配置"三类。

**根因**：回写逻辑的四类设计缺陷（历史上反复复发）。

**修复方案（四条铁律，改 ConfigManager/各 Settings 模型时必查）**：
1. **基底保留**：所有 `.custom.yaml` 回写必须以加载时的原始 dict 为基底（`originalDefaultCustomDict`/`originalSchemaCustomDict`）+ `deepMerge` 只覆盖本程序管理的键；绝不从零重建。
2. **快照完整性**：变更检测快照必须覆盖 UI 可编辑的**全部**字段——曾因 `modifiedColorSchemesDict` 只比颜色、漏了方案级 alpha/圆角导致修改静默丢失；switcher 用 baseline（加载时 UI 值）比较而非原始值，避免固化默认。
3. **patch 键互斥**：`key_binder/bindings`（全量）与 `key_binder/bindings/+`（追加）禁止同时存在；`menu` 节点与 `menu/page_size` 扁平键同理——写入前按基底已有形态选择，读取时两种形态都要兼容（否则"写得出读不回"）。
4. **层级正确**：schema.yaml 定义了的节点（switches/engine/key_binder/translator/menu/punctuator）patch 到 `rime_mint.custom.yaml`；只有 default.yaml 定义的（switcher/ascii_composer）才写 `default.custom.yaml`。

**Why**：Rime 的合并语义（列表整体替换）+ Yams 的坑（见全局经验 [[yams-multidoc-yaml-pitfalls]]、[[rime-config-patch-semantics]]）叠加，任何"看起来自然"的直接实现都会踩坑。2026-09-04 修复中曾引入"扁平 menu/page_size 读不回"回归，当轮审查发现后已修复并有往返测试（SquirrelConfigTests.testFlatMenuPageSizeRoundTrip）。

**How to apply**：改动回写逻辑后必须跑全量测试（`swift test`，80 个，含 ConfigManagerTests 集成测试）；涉及真实生效验证时用 rime_deployer 编译法（见全局经验）。
