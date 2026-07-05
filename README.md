# InputLocker

English | [简体中文](README.zh-CN.md)

InputLocker is a small macOS menu bar utility that keeps your keyboard input source pinned to a selected source.

It uses macOS Text Input Source Services, not private APIs. The lock is practical rather than absolute: when macOS or an app changes the input source, InputLocker switches it back.

![InputLocker menu overview](Packaging/AppStoreScreenshots/InputLocker-preview-1-menu-overview.png)

## Features

- Select a target keyboard input source from the menu bar.
- Pause or resume the lock without quitting the app.
- See the target source, current app, and current input source in a compact menu dashboard.
- Re-apply the target source after app switches and through a lightweight periodic check.
- Open macOS Keyboard Settings directly from the menu.
- Localized interface for English, Simplified Chinese, Traditional Chinese, Japanese, and Korean.

## Requirements

- macOS 13 or later.
- Xcode command line tools for building from source.

## Run From Source

```sh
swift run InputLocker
```

## Build The App Bundle

```sh
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/InputLocker.app
```

The SwiftPM build script creates `.build/InputLocker.app` and copies the app resources into the bundle.

## Xcode And TestFlight

This repository also includes an Xcode project for archive-capable macOS builds:

```sh
xcodebuild -project InputLocker.xcodeproj -scheme InputLocker -destination 'platform=macOS' test
```

For App Store Connect or TestFlight preparation, copy the example environment file and fill in real local credentials:

```sh
cp .agents/skills/apple-tf-upload/.env.example .tf-upload.env
.agents/skills/apple-tf-upload/scripts/upload.sh --dry-run
```

Do not commit `.tf-upload.env`; it is ignored on purpose.

## Tests

```sh
swift test
```

## Notes

Some secure or system-owned text fields can still override third-party input methods. InputLocker does not bypass macOS security rules.

## Change Log

See [CHANGELOG.md](CHANGELOG.md).
