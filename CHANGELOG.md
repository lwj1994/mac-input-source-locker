# Change Log

English | [简体中文](CHANGELOG.zh-CN.md)

All notable changes to InputLocker are documented in this file.

## 1.1.2 - 2026-07-07

- Fixed menu bar visibility persistence so hiding or showing another menu bar app such as Codex no longer toggles InputLocker.

## 1.1.1 - 2026-07-06

- Fixed packaged resource bundle discovery so localized strings and menu bar artwork load reliably in release app bundles.
- Fixed the menu bar status icon tinting so it adapts correctly across light and dark menu bar appearances.

## 1.1.0 - 2026-07-05

- Removed the VIP / StoreKit gating paths so all locking features are available directly.
- Added AppleViewModel-backed app state for the menu bar controller and settings window.
- Added per-app input source rules in the menu and settings UI.
- Reworked enforcement around input source change events with bounded reconcile retries instead of periodic polling.
- Added floating launcher handling for Spotlight, Raycast, Alfred, and LaunchBar; these floating surfaces now always fall back to the global input source.
- Added unified logging for enforcement, floating focus detection, app lifecycle, and input source events.
- Added a diagnostics section in Settings with log export support.

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
