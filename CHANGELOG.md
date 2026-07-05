# Change Log

English | [简体中文](CHANGELOG.zh-CN.md)

All notable changes to InputLocker are documented in this file.

## 1.0.0 - 2026-07-05

- Updated the app bundle version to `1.0.0`.
- Added an archive-capable Xcode project for macOS distribution workflows.
- Added App Store oriented bundle metadata, sandbox entitlement, app icon assets, and preview screenshots.
- Added a TestFlight preparation helper with dry-run archive/export support.
- Added a resource bundle adapter so localized strings and menu bar artwork load correctly from both SwiftPM and Xcode builds.
- Added a compact menu dashboard showing lock state, target input source, current app, and current input source.
- Added localized UI strings for English, Simplified Chinese, Traditional Chinese, Japanese, and Korean.

## 0.1.0 - 2026-07-05

- Initial SwiftPM menu bar app.
- Added target input source selection, pause/resume control, app-switch enforcement, periodic checks, and core tests.
