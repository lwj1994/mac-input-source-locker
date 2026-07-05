#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/InputLocker.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TAHOE_ICON_DIR="$ROOT_DIR/Packaging/InputLocker.icon"

cd "$ROOT_DIR"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/InputLocker" "$MACOS_DIR/InputLocker"
cp "Packaging/InputLocker-Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Packaging/InputLockerLegacy.icns" "$RESOURCES_DIR/InputLockerLegacy.icns"
if [[ -d "$TAHOE_ICON_DIR" ]]; then
    ACTOOL_LOG="$(mktemp)"
    if ! xcrun actool "$TAHOE_ICON_DIR" \
        --compile "$RESOURCES_DIR" \
        --app-icon InputLocker \
        --enable-on-demand-resources NO \
        --development-region en \
        --target-device mac \
        --platform macosx \
        --minimum-deployment-target 26.0 \
        --output-partial-info-plist /dev/null \
        --include-all-app-icons \
        --enable-icon-stack-fallback-generation=disabled > "$ACTOOL_LOG"; then
        cat "$ACTOOL_LOG" >&2
        exit 1
    fi
    if [[ ! -f "$RESOURCES_DIR/Assets.car" ]]; then
        cat "$ACTOOL_LOG" >&2
        echo "Failed to compile $TAHOE_ICON_DIR into Assets.car" >&2
        exit 1
    fi
    rm -f "$ACTOOL_LOG"
else
    cp "Packaging/InputLocker.icns" "$RESOURCES_DIR/InputLocker.icns"
fi
find "$BUILD_DIR" -maxdepth 1 -type d -name "*.bundle" -exec cp -R {} "$RESOURCES_DIR/" \;
chmod +x "$MACOS_DIR/InputLocker"

echo "$APP_DIR"
