# 更新日志

[English](CHANGELOG.md) | 简体中文

这里记录 InputLocker 的重要变化。

## 1.1.0 - 2026-07-05

- 移除 VIP / StoreKit 限制，锁定相关能力直接可用。
- 接入 AppleViewModel，集中管理菜单栏控制器和设置窗口状态。
- 在菜单和设置中新增按 App 绑定输入法规则。
- 将锁定引擎改为输入法变化事件驱动，并加入有界纠偏重试，替代周期轮询。
- 新增 Spotlight、Raycast、Alfred、LaunchBar 等浮层启动器处理；这些浮层现在始终回退到全局输入法。
- 新增锁定引擎、浮层焦点、App 生命周期和输入法事件的 unified logging。
- 在设置中新增诊断区，支持导出日志。

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
