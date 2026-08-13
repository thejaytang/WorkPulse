#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SCRATCH_PATH="${WORKPULSE_SCRATCH_PATH:-/tmp/workpulse-native-build}"
MODULES_PATH="${SCRATCH_PATH}/arm64-apple-macosx/debug/Modules"

# Never type-check against a stale WorkPulseCore module left by an earlier schema.
# Build the Widget product in the same scratch path before the independent check.
CLANG_MODULE_CACHE_PATH=/tmp/workpulse-widget-clang-cache \
SWIFT_MODULE_CACHE_PATH=/tmp/workpulse-widget-swift-cache \
swift build \
  --package-path "${PROJECT_DIR}" \
  --product WorkPulseWidgetCompile \
  --disable-sandbox \
  --scratch-path "${SCRATCH_PATH}"

CLANG_MODULE_CACHE_PATH=/tmp/workpulse-widget-clang-cache \
SWIFT_MODULE_CACHE_PATH=/tmp/workpulse-widget-swift-cache \
xcrun swiftc \
  -typecheck \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -I "${MODULES_PATH}" \
  "${PROJECT_DIR}/WidgetExtension/WorkPulseWidget.swift"

echo "WorkPulse Widget source type-check passed"
