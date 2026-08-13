#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SCRATCH_PATH="${WORKPULSE_SCRATCH_PATH:-/tmp/workpulse-native-build}"
OUTPUT_DIR="${PROJECT_DIR}/build"
APP_DIR="${OUTPUT_DIR}/WorkPulse.app"
ARCHIVE_PATH="${OUTPUT_DIR}/WorkPulse-local-dev.zip"
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
STAGING_ROOT="$(mktemp -d /tmp/workpulse-package.XXXXXX)"
STAGED_APP="${STAGING_ROOT}/WorkPulse.app"
STAGED_WIDGET="${STAGED_APP}/Contents/PlugIns/WorkPulseWidget.appex"
VERIFY_ROOT="${STAGING_ROOT}/verify"
LOCAL_APP_GROUP="group.com.workpulse.prototype"
STAGED_HOST_ENTITLEMENTS="${STAGING_ROOT}/WorkPulse.entitlements"
STAGED_WIDGET_ENTITLEMENTS="${STAGING_ROOT}/WorkPulseWidget.entitlements"
trap 'rm -rf "${STAGING_ROOT}"' EXIT

CLANG_MODULE_CACHE_PATH=/tmp/workpulse-clang-cache \
SWIFT_MODULE_CACHE_PATH=/tmp/workpulse-swift-cache \
swift build \
  --package-path "${PROJECT_DIR}" \
  --disable-sandbox \
  --scratch-path "${SCRATCH_PATH}"

mkdir -p "${STAGED_APP}/Contents/MacOS"
mkdir -p "${STAGED_APP}/Contents/Resources"
mkdir -p "${STAGED_WIDGET}/Contents/MacOS"
cp "${SCRATCH_PATH}/arm64-apple-macosx/debug/WorkPulseMenuBar" "${STAGED_APP}/Contents/MacOS/WorkPulseMenuBar"
cp "${PROJECT_DIR}/AppBundle/Info.plist" "${STAGED_APP}/Contents/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${STAGED_APP}/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${STAGED_APP}/Contents/Info.plist")"
cp "${SCRATCH_PATH}/arm64-apple-macosx/debug/WorkPulseWidgetCompile" "${STAGED_WIDGET}/Contents/MacOS/WorkPulseWidget"
cp "${PROJECT_DIR}/Xcode/WidgetInfo.plist" "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace CFBundleExecutable -string WorkPulseWidget "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string com.workpulse.prototype.widgets "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace CFBundleName -string WorkPulseWidget "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "${APP_VERSION}" "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${APP_BUILD}" "${STAGED_WIDGET}/Contents/Info.plist"
plutil -replace WorkPulseAppGroupIdentifier -string "${LOCAL_APP_GROUP}" "${STAGED_WIDGET}/Contents/Info.plist"
cp "${PROJECT_DIR}/Xcode/WorkPulse.entitlements" "${STAGED_HOST_ENTITLEMENTS}"
cp "${PROJECT_DIR}/Xcode/WorkPulseWidget.entitlements" "${STAGED_WIDGET_ENTITLEMENTS}"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 ${LOCAL_APP_GROUP}" "${STAGED_HOST_ENTITLEMENTS}"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 ${LOCAL_APP_GROUP}" "${STAGED_WIDGET_ENTITLEMENTS}"
chmod 755 "${STAGED_APP}/Contents/MacOS/WorkPulseMenuBar"
chmod 755 "${STAGED_WIDGET}/Contents/MacOS/WorkPulseWidget"

# Local-development signature only. This makes the bundle internally valid for
# LaunchServices testing; it is not Developer ID signing or notarization.
if command -v codesign >/dev/null 2>&1; then
  xattr -cr "${STAGED_APP}"
  codesign --force --sign - \
    --entitlements "${STAGED_WIDGET_ENTITLEMENTS}" \
    "${STAGED_WIDGET}"
  codesign --force --sign - \
    --entitlements "${STAGED_HOST_ENTITLEMENTS}" \
    "${STAGED_APP}"
  codesign --verify --deep --strict "${STAGED_APP}"
fi

mkdir -p "${OUTPUT_DIR}"
rm -f "${ARCHIVE_PATH}"
ditto -c -k --keepParent "${STAGED_APP}" "${ARCHIVE_PATH}"
mkdir -p "${VERIFY_ROOT}"
ditto -x -k "${ARCHIVE_PATH}" "${VERIFY_ROOT}"
codesign --verify --deep --strict "${VERIFY_ROOT}/WorkPulse.app"
[[ -x "${VERIFY_ROOT}/WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget" ]]
plutil -extract NSExtension.NSExtensionPointIdentifier raw \
  "${VERIFY_ROOT}/WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex/Contents/Info.plist" \
  | rg -q '^com\.apple\.widgetkit-extension$'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${VERIFY_ROOT}/WorkPulse.app/Contents/Info.plist")" == \
   "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${VERIFY_ROOT}/WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex/Contents/Info.plist")" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${VERIFY_ROOT}/WorkPulse.app/Contents/Info.plist")" == \
   "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${VERIFY_ROOT}/WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex/Contents/Info.plist")" ]]

# Keep one canonical installed copy. A second unpacked app under the Desktop build
# directory is automatically discovered by LaunchServices and creates a duplicate
# Widget Gallery registration, so the distributable ZIP is the only build artifact.
rm -rf "${APP_DIR}"

echo "Packaged verified local archive with Widget Extension ${ARCHIVE_PATH}"
