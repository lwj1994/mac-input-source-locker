# 更新日志

[English](CHANGELOG.md) | 简体中文

这里记录 InputLocker 的重要变化。

## 1.0.0 - 2026-07-05

- 将 App bundle 版本更新为 `1.0.0`。
- 新增可归档的 macOS Xcode 项目，用于分发构建流程。
- 新增面向 App Store 的 bundle 元数据、沙盒 entitlement、App 图标资源和预览截图。
- 新增 TestFlight 准备辅助脚本，支持 dry-run 归档和导出检查。
- 新增资源 bundle 适配层，让本地化字符串和菜单栏图标在 SwiftPM 与 Xcode 构建中都能正确加载。
- 新增紧凑菜单面板，显示锁定状态、目标输入法、当前 App 和当前输入法。
- 新增英文、简体中文、繁体中文、日文、韩文界面文案。

## 0.1.0 - 2026-07-05

- 初始 SwiftPM 菜单栏 App。
- 新增目标输入法选择、暂停/开启锁定、App 切换后重新应用、定时检查和核心测试。
