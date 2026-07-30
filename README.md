# Rime Manager for macOS

一个为 macOS 开发的 Rime 输入法可视化管理工具，专为 [薄荷拼音 (oh-my-rime)](https://github.com/Mintimate/oh-my-rime) 设计。无需编辑 YAML，通过优雅的图形界面管理你的 Rime 配置。

A native macOS app for managing Rime input method configurations visually. Designed for [oh-my-rime (Mint Pinyin)](https://github.com/Mintimate/oh-my-rime). No YAML editing required.

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

### 📝 输入方案管理 Schema
- 查看当前默认输入方案
- 管理 Ctrl+` 轮换队列（启用/禁用方案）
- 支持全拼、双拼、五笔、笔画等 15+ 方案
- 一键设为默认

### 📚 词库管理 Dictionaries
- 薄荷拼音内置词库开关（基础词库、扩展词库、颜文字等）
- 雾凇拼音纠错词库

### 💾 备份管理 Backups
- 自动备份（首次检测配置、每次写入前）
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

---

## 截图 Screenshots

> <img width="2216" height="1608" alt="image" src="https://github.com/user-attachments/assets/bb9b2d63-2bab-4165-a86a-08cc7beb5fc2" />

---

## 系统要求 Requirements

- macOS 14.0 (Sonoma) 或更高版本
- [Squirrel (鼠鬚管)](https://rime.im/download/) 输入法引擎
- [薄荷拼音 oh-my-rime](https://github.com/Mintimate/oh-my-rime)（需提前安装）

> ⚠️ **重要**：本软件不再内置薄荷拼音配置。请先按照 [oh-my-rime 指南](https://www.mintimate.cc/zh/guide/) 安装薄荷拼音方案，再使用本工具进行可视化管理。

---

## 安装与使用 Usage

### 下载 Download

从 [Releases](https://github.com/flyzyh/rime-manager-macos/releases) 下载最新版 `RimeManager.app`。

### 前置准备 Prerequisites

1. 安装 [Squirrel (鼠鬚管)](https://rime.im/download/)
2. 按照 [oh-my-rime 指南](https://www.mintimate.cc/zh/guide/) 下载并安装薄荷拼音方案到 `~/Library/Rime/`
3. 部署 Rime（点击菜单栏输入法图标 → 部署）

### 首次启动 First Launch

1. 双击 `RimeManager.app`
2. 软件会自动检测 `~/Library/Rime/` 中的配置
3. 若未检测到配置，会提示你先安装薄荷拼音

### 日常使用 Daily Use

| 操作 | 说明 |
|------|------|
| 修改外观 | Appearance 标签页调整后点击 **保存** 或 **应用并部署** |
| 切换输入方案 | Schema 标签页启用/禁用，Ctrl+` 切换 |
| 管理词库 | Dictionaries 标签页开关各词库 |
| 恢复配置 | Backups 标签页选择备份点恢复 |

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
