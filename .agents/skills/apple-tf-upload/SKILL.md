---
name: apple-tf-upload
description: Build, verify, archive, export, and upload iOS or macOS Apple app builds to TestFlight through App Store Connect. Use when the user asks to upload to TF/TestFlight, ship a beta build, archive for App Store Connect, create or check a `.tf-upload.env`, or compare the iOS and macOS TestFlight upload flows.
---

# Apple TestFlight Upload

Use this skill for Apple App Store Connect/TestFlight release work. The iOS and macOS upload pipeline is similar: test, archive, export, upload. It is not identical: iOS normally exports an `.ipa`; macOS requires Mac App Store compatible signing/capabilities and may export a `.pkg`.

This skill intentionally works from an Xcode project or workspace. A locally assembled SwiftPM `.app` bundle is not enough for TestFlight; macOS TestFlight still needs an App Store Connect archive with correct signing, sandboxing, bundle id, version, and entitlements.

## First Checks

1. Inspect the repo before running anything:
   - Find `.tf-upload.env` at the repo root, or set `TF_UPLOAD_ENV`.
   - Find an `.xcodeproj` or `.xcworkspace` outside generated folders such as `.swiftpm`.
   - Read `Package.swift`, project settings, and scripts if the repo is SwiftPM-only.
2. If the repo has no Xcode project/workspace, run only local sanity checks such as `swift test` or existing build scripts. Stop before upload and explain that an archive-capable Xcode app target is required.
3. Do not invent App Store Connect credentials, team ids, bundle ids, profile names, or key paths. Ask the user or leave placeholders in `.tf-upload.env`.
4. Do not upload unless the user explicitly asked to upload. Use `scripts/upload.sh --dry-run` for preparation, archive, and export checks.

## Config

Create `.tf-upload.env` from `.agents/skills/apple-tf-upload/.env.example` and keep the real file out of git.

Required:

```bash
PLATFORM=macos                  # ios or macos
SCHEME=InputLocker              # Xcode scheme to archive
TEAM_ID=ABCD123456              # Apple Developer Team ID
```

Project selection, choose one if auto-detection is ambiguous:

```bash
PROJECT_NAME=InputLocker.xcodeproj
WORKSPACE_NAME=InputLocker.xcworkspace
```

Recommended validation:

```bash
TEST_DESTINATION=platform=macOS
TEST_TARGET=InputLockerTests
SKIP_XCODE_TESTS=0
SWIFTPM_PRECHECK=1
SWIFTPM_BUILD_SCRIPT=Scripts/build-app.sh
```

Authentication, prefer App Store Connect API key:

```bash
ASC_KEY_ID=ABCD123456
ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555
ASC_KEY_PATH=/absolute/path/AuthKey_ABCD123456.p8
```

Apple ID app-specific password also works:

```bash
ASC_USERNAME=you@example.com
ASC_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
ASC_PROVIDER_PUBLIC_ID=
```

Optional signing/export settings:

```bash
BUNDLE_ID=com.example.InputLocker
CODE_SIGN_STYLE=Automatic
PROVISIONING_PROFILE_SPECIFIER=
SIGNING_CERTIFICATE=
EXPORT_METHOD=app-store-connect
INTERNAL_ONLY=0
```

## Commands

From the repo root:

```bash
.agents/skills/apple-tf-upload/scripts/upload.sh --dry-run
.agents/skills/apple-tf-upload/scripts/upload.sh
.agents/skills/apple-tf-upload/scripts/upload.sh --build 42
```

Use `--dry-run` before the first real upload. It runs checks, archives, and exports locally but skips the final App Store Connect upload step.

## Script Behavior

`scripts/upload.sh`:

1. Loads `.tf-upload.env`.
2. Runs optional SwiftPM sanity checks when `SWIFTPM_PRECHECK=1`.
3. Requires an Xcode project/workspace and archive scheme.
4. Runs Xcode tests unless `SKIP_XCODE_TESTS=1`.
5. Builds and archives Release with Swift and Clang warnings treated as errors.
6. Uses `CURRENT_PROJECT_VERSION` from `--build`, `BUILD_NUMBER`, or git commit count.
7. Generates `build/tf-upload/ExportOptions.runtime.plist`.
8. Exports locally in dry-run or Apple ID mode.
9. Uploads with `xcodebuild -exportArchive destination=upload` for API key mode, or `xcrun altool --upload-package` for Apple ID mode.

## Platform Notes

iOS:

- Use `PLATFORM=ios`.
- Archive destination is `generic/platform=iOS`.
- Test destination should usually be an iOS Simulator, for example `platform=iOS Simulator,name=iPhone 16`.
- Exported upload artifact is normally `.ipa`.

macOS:

- Use `PLATFORM=macos`.
- Archive destination is `generic/platform=macOS`.
- Test destination can be `platform=macOS`.
- The app target must be App Store Connect/TestFlight compatible. Check app sandbox, hardened runtime policy, bundle id, version/build numbers, Mac App Store provisioning, and distribution certificates.
- A SwiftPM-built `.app` from `Scripts/build-app.sh` is useful as a local smoke build, but it is not the archive that TestFlight accepts.

## Current Repo Note

This repository is currently a SwiftPM macOS menu bar app with `Scripts/build-app.sh` and no checked-in `.xcodeproj` or `.xcworkspace`. For a real macOS TestFlight upload, first add or generate a durable Xcode app project/workspace that can archive `InputLocker` with App Store Connect signing.
