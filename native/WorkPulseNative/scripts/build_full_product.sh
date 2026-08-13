#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DERIVED_DATA="${WORKPULSE_DERIVED_DATA:-/tmp/workpulse-xcode-derived-data}"
OUTPUT_DIR="${ROOT}/build/full-product"
TEAM="${WORKPULSE_DEVELOPMENT_TEAM:-}"
APP=""
HOST_ENTITLEMENTS=""
WIDGET_ENTITLEMENTS=""
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

cleanup() {
  [[ -n "${HOST_ENTITLEMENTS}" ]] && rm -f "${HOST_ENTITLEMENTS}"
  [[ -n "${WIDGET_ENTITLEMENTS}" ]] && rm -f "${WIDGET_ENTITLEMENTS}"
  if [[ -n "${APP}" && -d "${APP}" ]]; then
    # Xcode registers embedded extensions while building. Remove both the
    # PlugInKit and LaunchServices records for DerivedData so the signed
    # archive cannot temporarily coexist with a second Gallery provider.
    pluginkit -r "${APP}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || true
    "${LSREGISTER}" -u "${APP}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

detect_xcode_team() {
  defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | awk '/teamID =/ { value=$3; gsub(/[;"[:space:]]/, "", value); print value; exit }'
}

if ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 "完整产品构建需要完整 Xcode；最终用户安装生成的 WorkPulse.app 时不需要 Xcode。"
  exit 2
fi

if [[ -z "${TEAM}" ]]; then
  TEAM="$(detect_xcode_team)"
fi
if [[ -z "${TEAM}" ]]; then
  print -u2 "Xcode 尚未提供 Apple Development Team；请在 Xcode > Settings > Apple Accounts 登录并选择 Personal Team。"
  exit 2
fi
APP_GROUP="${TEAM}.com.workpulse.shared"

if ! security find-identity -v -p codesigning | rg -q 'Apple Development'; then
  print -u2 "Xcode 已识别 Team ${TEAM}，但钥匙串尚无 Apple Development 证书。请先在 Manage Certificates 中创建。"
  exit 2
fi

xcodebuild \
  -project "${ROOT}/WorkPulse.xcodeproj" \
  -scheme WorkPulse \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA}" \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${TEAM}" \
  WORKPULSE_APP_GROUP="${APP_GROUP}" \
  CODE_SIGN_STYLE=Automatic \
  clean build

APP="${DERIVED_DATA}/Build/Products/Release/WorkPulse.app"
WIDGET="${APP}/Contents/PlugIns/WorkPulseWidget.appex"

[[ -d "${APP}" ]] || { print -u2 "未生成 WorkPulse.app"; exit 1; }
[[ -d "${WIDGET}" ]] || { print -u2 "WorkPulse.app 未嵌入 WorkPulseWidget.appex"; exit 1; }

codesign --verify --deep --strict --verbose=2 "${APP}"
codesign --verify --strict --verbose=2 "${WIDGET}"

SIGNED_TEAM="$(codesign -dv --verbose=4 "${WIDGET}" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
[[ "${SIGNED_TEAM}" == "${TEAM}" ]] \
  || { print -u2 "Widget TeamIdentifier 不匹配：期望 ${TEAM}，实际 ${SIGNED_TEAM:-none}"; exit 1; }

HOST_ENTITLEMENTS="$(mktemp /tmp/workpulse-host-entitlements.XXXXXX.plist)"
WIDGET_ENTITLEMENTS="$(mktemp /tmp/workpulse-widget-entitlements.XXXXXX.plist)"
codesign -d --entitlements - "${APP}" > "${HOST_ENTITLEMENTS}" 2>/dev/null
codesign -d --entitlements - "${WIDGET}" > "${WIDGET_ENTITLEMENTS}" 2>/dev/null

for entitlement_file in "${HOST_ENTITLEMENTS}" "${WIDGET_ENTITLEMENTS}"; do
  rg -q --fixed-strings "${APP_GROUP}" "${entitlement_file}" \
    || { print -u2 "签名产物缺少共享 WorkPulse App Group"; exit 1; }
done

[[ "$(/usr/libexec/PlistBuddy -c 'Print :WorkPulseWidgetRuntimeEnabled' "${APP}/Contents/Info.plist")" == true ]] \
  || { print -u2 "团队签名宿主未开启 Widget runtime"; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :WorkPulseAppGroupIdentifier' "${APP}/Contents/Info.plist")" == "${APP_GROUP}" ]] \
  || { print -u2 "宿主 Info.plist 的 App Group 与签名配置不一致"; exit 1; }

mkdir -p "${OUTPUT_DIR}"
ARCHIVE="${OUTPUT_DIR}/WorkPulse-full-product.zip"
rm -f "${ARCHIVE}"
ditto -c -k --keepParent "${APP}" "${ARCHIVE}"
shasum -a 256 "${ARCHIVE}"
print "完整 WorkPulse.app 已构建并验证：${ARCHIVE}"
