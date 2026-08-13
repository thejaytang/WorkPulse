#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
NATIVE_DIR="${ROOT_DIR}/native/WorkPulseNative"
SCRATCH_PATH="${WORKPULSE_SCRATCH_PATH:-/tmp/workpulse-native-build}"
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

CLANG_MODULE_CACHE_PATH=/tmp/workpulse-clang-cache \
SWIFT_MODULE_CACHE_PATH=/tmp/workpulse-swift-cache \
swift build \
  --package-path "${NATIVE_DIR}" \
  --disable-sandbox \
  --scratch-path "${SCRATCH_PATH}"

CLANG_MODULE_CACHE_PATH=/tmp/workpulse-clang-cache \
SWIFT_MODULE_CACHE_PATH=/tmp/workpulse-swift-cache \
swift run \
  --package-path "${NATIVE_DIR}" \
  --disable-sandbox \
  --scratch-path "${SCRATCH_PATH}" \
  WorkPulseCoreVerify

"${NATIVE_DIR}/scripts/typecheck_widget.sh"
"${NATIVE_DIR}/scripts/verify_system_surfaces.sh"
"${NATIVE_DIR}/scripts/package_app.sh"
plutil -lint "${NATIVE_DIR}/AppBundle/Info.plist"
node "${ROOT_DIR}/scripts/verify_html_demo.mjs"

if [[ "${1:-}" == "--live-probe" ]]; then
  "${SCRATCH_PATH}/arm64-apple-macosx/debug/WorkPulseAppServerProbe"
else
  echo "Skipped live Codex probe; rerun with --live-probe when local App Server access is intended"
fi

echo "WorkPulse local preview gate passed"
