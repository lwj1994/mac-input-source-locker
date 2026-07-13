#!/usr/bin/env bash
# Build an iOS or macOS app archive and upload it to TestFlight.
# Usage:
#   scripts/upload.sh --dry-run
#   scripts/upload.sh
#   scripts/upload.sh --build 42
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

find_env() {
    if [[ -n "${TF_UPLOAD_ENV:-}" ]]; then
        [[ -f "$TF_UPLOAD_ENV" ]] && { echo "$TF_UPLOAD_ENV"; return 0; }
        echo "TF_UPLOAD_ENV is set but is not a file: $TF_UPLOAD_ENV" >&2
        return 1
    fi

    local dir="$PWD"
    while :; do
        [[ -f "$dir/.tf-upload.env" ]] && { echo "$dir/.tf-upload.env"; return 0; }
        [[ "$dir" == "/" ]] && break
        dir="$(dirname "$dir")"
    done
    return 1
}

usage() {
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
}

DRY_RUN=0
BUILD_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --build) BUILD_OVERRIDE="${2:?missing build number}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

ENV_FILE="$(find_env || true)"
if [[ -z "$ENV_FILE" ]]; then
    echo "missing .tf-upload.env. Copy .agents/skills/apple-tf-upload/.env.example to <repo>/.tf-upload.env and fill it." >&2
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

: "${PLATFORM:?PLATFORM must be ios or macos}"
: "${SCHEME:?SCHEME is required}"
: "${TEAM_ID:?TEAM_ID is required}"

REPO_ROOT="$(cd "$(dirname "$ENV_FILE")" && pwd)"
BUILD_DIR="${TF_BUILD_DIR:-$REPO_ROOT/build/tf-upload}"
LOG_DIR="$BUILD_DIR/logs"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.runtime.plist"

mkdir -p "$BUILD_DIR" "$LOG_DIR"

case "$PLATFORM" in
    ios)
        SDK="iphoneos"
        ARCHIVE_DESTINATION="generic/platform=iOS"
        ALTOOL_PLATFORM="ios"
        ;;
    macos)
        SDK="macosx"
        ARCHIVE_DESTINATION="generic/platform=macOS"
        ALTOOL_PLATFORM="macos"
        ;;
    *)
        echo "unsupported PLATFORM: $PLATFORM (expected ios or macos)" >&2
        exit 1
        ;;
esac

echo "==> env:      $ENV_FILE"
echo "==> repo:     $REPO_ROOT"
echo "==> platform: $PLATFORM"
echo "==> scheme:   $SCHEME"

resolve_path() {
    local raw="$1"
    if [[ "$raw" == /* ]]; then
        echo "$raw"
    else
        echo "$REPO_ROOT/$raw"
    fi
}

find_xcode_container() {
    if [[ -n "${WORKSPACE_NAME:-}" ]]; then
        local workspace
        workspace="$(resolve_path "$WORKSPACE_NAME")"
        [[ -d "$workspace" ]] && { echo "workspace:$workspace"; return 0; }
        echo "WORKSPACE_NAME does not exist: $workspace" >&2
        return 1
    fi

    if [[ -n "${PROJECT_NAME:-}" ]]; then
        local project
        project="$(resolve_path "$PROJECT_NAME")"
        [[ -d "$project" ]] && { echo "project:$project"; return 0; }
        echo "PROJECT_NAME does not exist: $project" >&2
        return 1
    fi

    local workspace project
    workspace="$(find "$REPO_ROOT" \
        -path "$REPO_ROOT/.swiftpm" -prune -o \
        -path "$REPO_ROOT/.build" -prune -o \
        -name "*.xcworkspace" -type d -print 2>/dev/null | head -n1)"
    if [[ -n "$workspace" ]]; then
        echo "workspace:$workspace"
        return 0
    fi

    project="$(find "$REPO_ROOT" \
        -path "$REPO_ROOT/.swiftpm" -prune -o \
        -path "$REPO_ROOT/.build" -prune -o \
        -name "*.xcodeproj" -type d -print 2>/dev/null | head -n1)"
    if [[ -n "$project" ]]; then
        echo "project:$project"
        return 0
    fi

    return 1
}

run_logged() {
    local label="$1"
    shift
    local log="$LOG_DIR/$label.log"

    set +e
    "$@" 2>&1 | tee "$log"
    local status=${PIPESTATUS[0]}
    set -e

    if [[ $status -ne 0 ]]; then
        echo "command failed during $label; log: $log" >&2
        exit "$status"
    fi
}

run_xcodebuild_no_warnings() {
    local label="$1"
    shift
    local log="$LOG_DIR/$label.log"

    set +e
    xcodebuild "$@" 2>&1 | tee "$log"
    local status=${PIPESTATUS[0]}
    set -e

    if [[ $status -ne 0 ]]; then
        echo "xcodebuild failed during $label; log: $log" >&2
        exit "$status"
    fi

    if grep -nE '^[[:space:]]*[^:]+:[0-9]+:[0-9]+: warning:' "$log"; then
        echo "compiler warning(s) found during $label; build not uploaded." >&2
        exit 1
    fi
}

if [[ "${SWIFTPM_PRECHECK:-0}" == "1" && -f "$REPO_ROOT/Package.swift" ]]; then
    echo "==> swift test"
    run_logged "swift-test" swift test --package-path "$REPO_ROOT"

    if [[ -n "${SWIFTPM_BUILD_SCRIPT:-}" ]]; then
        BUILD_SCRIPT="$(resolve_path "$SWIFTPM_BUILD_SCRIPT")"
        if [[ -f "$BUILD_SCRIPT" ]]; then
            echo "==> SwiftPM build script: $BUILD_SCRIPT"
            run_logged "swiftpm-build-script" bash "$BUILD_SCRIPT"
        fi
    fi
fi

CONTAINER="$(find_xcode_container || true)"
if [[ -z "$CONTAINER" ]]; then
    echo "no archive-capable .xcodeproj or .xcworkspace found outside generated folders." >&2
    echo "SwiftPM .app bundles are not enough for TestFlight. Add a durable Xcode app target/workspace, then set PROJECT_NAME or WORKSPACE_NAME in .tf-upload.env." >&2
    exit 1
fi

CONTAINER_KIND="${CONTAINER%%:*}"
CONTAINER_PATH="${CONTAINER#*:}"
if [[ "$CONTAINER_KIND" == "workspace" ]]; then
    CONTAINER_ARGS=(-workspace "$CONTAINER_PATH")
else
    CONTAINER_ARGS=(-project "$CONTAINER_PATH")
fi

echo "==> $CONTAINER_KIND: $CONTAINER_PATH"

COMMON_SETTINGS=(
    DEVELOPMENT_TEAM="$TEAM_ID"
    SWIFT_SUPPRESS_WARNINGS=NO
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    GCC_TREAT_WARNINGS_AS_ERRORS=YES
)

[[ -n "${CODE_SIGN_STYLE:-}" ]] && COMMON_SETTINGS+=(CODE_SIGN_STYLE="$CODE_SIGN_STYLE")
[[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]] && COMMON_SETTINGS+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
[[ -n "${SIGNING_CERTIFICATE:-}" ]] && COMMON_SETTINGS+=(CODE_SIGN_IDENTITY="$SIGNING_CERTIFICATE")
[[ -n "${BUNDLE_ID:-}" ]] && COMMON_SETTINGS+=(PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID")

BUILD_NUMBER="${BUILD_OVERRIDE:-${BUILD_NUMBER:-}}"
if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="$(git -C "$REPO_ROOT" rev-list --count HEAD 2>/dev/null || true)"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
    BUILD_NUMBER="$(date +%Y%m%d%H%M)"
fi
COMMON_SETTINGS+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

echo "==> build:    $BUILD_NUMBER"

if [[ "${SKIP_XCODE_TESTS:-0}" != "1" ]]; then
    : "${TEST_DESTINATION:?TEST_DESTINATION is required unless SKIP_XCODE_TESTS=1}"
    TEST_ARGS=("${CONTAINER_ARGS[@]}" -scheme "$SCHEME" -configuration "${CONFIGURATION:-Release}" -destination "$TEST_DESTINATION")
    if [[ -n "${TEST_TARGET:-}" ]]; then
        TEST_ARGS+=("-only-testing:$TEST_TARGET")
    fi
    echo "==> xcodebuild test"
    run_xcodebuild_no_warnings "xcode-test" "${TEST_ARGS[@]}" test "${COMMON_SETTINGS[@]}"
else
    echo "==> xcodebuild test skipped by SKIP_XCODE_TESTS=1"
fi

echo "==> xcodebuild clean build"
run_xcodebuild_no_warnings "xcode-build" \
    "${CONTAINER_ARGS[@]}" \
    -scheme "$SCHEME" \
    -configuration "${CONFIGURATION:-Release}" \
    -sdk "$SDK" \
    -destination "$ARCHIVE_DESTINATION" \
    clean build \
    "${COMMON_SETTINGS[@]}"

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "==> xcodebuild archive"
run_xcodebuild_no_warnings "xcode-archive" \
    "${CONTAINER_ARGS[@]}" \
    -scheme "$SCHEME" \
    -configuration "${CONFIGURATION:-Release}" \
    -sdk "$SDK" \
    -destination "$ARCHIVE_DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    "${COMMON_SETTINGS[@]}"

AUTH_MODE="none"
AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
    AUTH_MODE="apikey"
    [[ -f "$ASC_KEY_PATH" ]] || { echo "ASC_KEY_PATH does not exist: $ASC_KEY_PATH" >&2; exit 1; }
    AUTH_ARGS=(-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$ASC_KEY_PATH")
elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_APP_PASSWORD:-}" ]]; then
    AUTH_MODE="appleid"
fi

if [[ "$DRY_RUN" == "0" && "$AUTH_MODE" == "none" ]]; then
    echo "no upload auth configured. Set ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH or ASC_USERNAME/ASC_APP_PASSWORD." >&2
    exit 1
fi

EXPORT_DESTINATION="upload"
if [[ "$DRY_RUN" == "1" || "$AUTH_MODE" == "appleid" ]]; then
    EXPORT_DESTINATION="export"
fi

cp "$SKILL_DIR/ExportOptions.plist" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Set :method ${EXPORT_METHOD:-app-store-connect}" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Set :destination $EXPORT_DESTINATION" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$EXPORT_PLIST"
if [[ -n "${CODE_SIGN_STYLE:-}" ]]; then
    signing_style="$(printf '%s' "$CODE_SIGN_STYLE" | tr '[:upper:]' '[:lower:]')"
    /usr/libexec/PlistBuddy -c "Set :signingStyle $signing_style" "$EXPORT_PLIST"
fi
if [[ -n "${SIGNING_CERTIFICATE:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Add :signingCertificate string $SIGNING_CERTIFICATE" "$EXPORT_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :signingCertificate $SIGNING_CERTIFICATE" "$EXPORT_PLIST"
fi
if [[ -n "${INSTALLER_SIGNING_CERTIFICATE:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Add :installerSigningCertificate string $INSTALLER_SIGNING_CERTIFICATE" "$EXPORT_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :installerSigningCertificate $INSTALLER_SIGNING_CERTIFICATE" "$EXPORT_PLIST"
fi
if [[ -n "${BUNDLE_ID:-}" && -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
    provisioning_profile_export_key="${PROVISIONING_PROFILE_EXPORT_KEY:-$BUNDLE_ID}"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$provisioning_profile_export_key string $PROVISIONING_PROFILE_SPECIFIER" "$EXPORT_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :provisioningProfiles:$provisioning_profile_export_key $PROVISIONING_PROFILE_SPECIFIER" "$EXPORT_PLIST"
fi
if [[ "${INTERNAL_ONLY:-0}" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Add :testFlightInternalTestingOnly bool true" "$EXPORT_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :testFlightInternalTestingOnly true" "$EXPORT_PLIST"
fi

echo "==> export destination: $EXPORT_DESTINATION"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates \
    "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "dry run complete. Archive: $ARCHIVE_PATH"
    echo "Export: $EXPORT_PATH"
    exit 0
fi

if [[ "$AUTH_MODE" == "appleid" ]]; then
    ARTIFACT="$(find "$EXPORT_PATH" -maxdepth 1 \( -name "*.ipa" -o -name "*.pkg" \) -type f | head -n1)"
    [[ -n "$ARTIFACT" ]] || { echo "no .ipa or .pkg found in $EXPORT_PATH" >&2; exit 1; }

    ALTOOL_ARGS=(--upload-package "$ARTIFACT" --username "$ASC_USERNAME" --password "$ASC_APP_PASSWORD")
    [[ -n "${ASC_PROVIDER_PUBLIC_ID:-}" ]] && ALTOOL_ARGS+=(--provider-public-id "$ASC_PROVIDER_PUBLIC_ID")
    ALTOOL_ARGS+=(--output-format normal)

    echo "==> altool upload-package: $(basename "$ARTIFACT")"
    xcrun altool "${ALTOOL_ARGS[@]}" 2>&1 | tee "$BUILD_DIR/altool.log"
fi

echo "uploaded build $BUILD_NUMBER to App Store Connect for $ALTOOL_PLATFORM."
