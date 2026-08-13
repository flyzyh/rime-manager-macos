# Rime Manager for macOS

一个为 macOS 开发的 Rime 输入法可视化管理工具，专为 [薄荷拼音 (oh-my-rime)](https://github.com/Mintimate/oh-my-rime) 设计。无需编辑 YAML，通过优雅的图形界面管理你的 Rime 配置。

A native macOS app for managing Rime input method configurations visually. Designed for [oh-my-rime (Mint Pinyin)](https://github.com/Mintimate/oh-my-rime). No YAML editing required.

---

## 更新日志 Changelog

### v1.3.1
- 🔵 修复候选词数量配置层级错误（schema 层 page_size 需 patch 到 rime_mint.custom.yaml）
- 🎨 恢复备份后自动重启输入法，外观配置真正生效
- 🧊 新增「液态玻璃」配色方案（半透明背景 + Apple 蓝高亮 + 18px 圆角）
- 🎯 修正 Squirrel 颜色字节序为 0xAABBGGRR（低位=Red，高位=Alpha）
- 🛡️ 修复 9 个破坏性配置写入漏洞：部分列表覆盖 engine、translator 丢失 dictionary、installation.yaml 字段抹除等
- 💾 部署改为完全重启 Squirrel（--reload 不重载面板外观）

### v1.3.0
- ✏️ 自定义短语编辑器（custom_phrase.txt 图形化管理）
- 🔣 标点映射编辑器（半角/全角符号自定义）
- ⌨️ 按键绑定可视化（四维编辑 + 60+ 预设键位）
- 🧩 Lua 扩展开关（17 个脚本分组启停 + 反查开关）
- ⚙️ 高级设置（同步、OpenCC 简繁链、方案切换快捷键、用户词库清空）
- 📚 词库词条数统计 + 侧边栏数量徽章
- 🎨 官方 Rime 图标（佛振/梁海/雨過之後 设计）

### v1.2.0
- macOS 设置风格界面（NavigationSplitView 侧边栏）
- 按应用独立配置、Toast 反馈、液态玻璃窗口

---

## 功能 Features

### 🎛️ 外观配置 Appearance
- 实时预览候选框（支持亮色/暗色切换）
- 横排/竖排布局切换
- 字体、字号调节
- 透明度、圆角、间距滑杆
- 半透明背景、背景模糊开关
- 配色方案管理（亮色/暗色/自动跟随系统）
- 8 种颜色独立取色器（背景、文字、高亮背景、候选字、序号、注释、边框、阴影）

### ⌨️ 输入行为 Input
- 默认中英模式、简繁字形切换
- Emoji 建议、全角、声调显示、中英标点开关
- Caps Lock 行为、Shift 键行为
- 编码器、整句、用户词库引擎选项
- 按应用独立配置（浏览器强制 inline 修复回车问题）

### 📝 输入方案管理 Schemas
- 查看当前默认输入方案
- 管理 Ctrl+` 轮换队列（启用/禁用方案）
- 支持全拼、双拼、五笔、笔画等 15+ 方案
- 一键设为默认

### 📚 词库管理 Dictionaries
- 薄荷拼音内置词库开关（基础词库、扩展词库、颜文字等）
- 雾凇拼音纠错词库
- **词条数统计**（每个词库显示词条数量）

### ✏️ 自定义短语 Phrases
- 图形化管理 `custom_phrase.txt`
- 添加 / 删除 / 搜索短语
- 权重调节（影响候选排序）

### 🔣 标点映射 Punctuation
- 半角 / 全角符号映射编辑
- 支持普通提交、多候选、成对括号三种格式

### ⌨️ 按键绑定 Key Bindings
- 可视化编辑键盘快捷键
- 触发时机 / 按键 / 动作 / 目标四维配置
- 60+ 预设键位下拉选择

### 🧩 Lua 扩展开关 Lua Extensions
- 17 个 Lua 脚本按处理器 / 翻译器 / 过滤器分组启停
- 计算器、日期时间、农历、金额大小写、错音纠错等
- 反查（部首 / 笔画 / 五笔）开关

### ⚙️ 高级设置 Advanced
- **同步配置**：installation_id、同步目录
- **简繁转换（OpenCC）**：8 种转换链选择
- **方案切换快捷键**自定义
- **用户词库管理**：占用空间统计、一键清空

### 💾 备份管理 Backups
- 手动创建备份
- 备份恢复与删除
- 所有备份保存在 `~/Library/Rime/backups/`

### 🌐 多语言 i18n
- 简体中文 / 繁體中文 / English
- 默认跟随系统语言

### 🔧 其他
- 浏览器回车键修复（强制 inline 模式，解决知乎等编辑器兼容问题）
- 一键部署 Rime
- 保存配置但不部署
- Toast 反馈提示
- 液态玻璃（Liquid Glass）界面

---

## 系统要求 Requirements

- macOS 14.0 (Sonoma) 或更高版本
- [Squirrel (鼠鬚管)](https://rime.im/download/) 输入法引擎
- [薄荷拼音 (oh-my-rime)](https://github.com/Mintimate/oh-my-rime)

---

## 安装与使用 Usage

### 下载 Download

从 [Releases](https://github.com/flyzyh/rime-manager-macos/releases) 下载最新版 `RimeManager.app`。

### 首次启动 First Launch

1. 双击 `RimeManager.app`
2. 若系统无 Rime 配置，跟随引导安装 oh-my-rime
3. 若已有配置，自动检测后进入主界面

### 日常使用 Daily Use

| 操作 | 说明 |
|------|------|
| 修改配置 | 侧边栏选择分类，调整后点击工具栏 **应用并部署** |
| 切换输入方案 | 输入方案页启用/禁用，Ctrl+` 切换 |
| 管理词库 | 词库页开关各词库，查看词条数 |
| 添加短语 | 短语页输入编码+短语+权重 |
| 恢复配置 | 备份页选择备份点恢复 |

### 从源码构建 Build from Source

```bash
git clone git@github.com:flyzyh/rime-manager-macos.git
cd rime-manager-macos
make app
```

---

## 技术栈 Tech Stack

- Swift 6 + SwiftUI
- Yams (YAML 解析)
- Combine (响应式数据流)
- 纯原生 macOS 设计，符合 Apple HIG

---

## 开源协议 License

MIT License — 详见 [LICENSE](LICENSE)
