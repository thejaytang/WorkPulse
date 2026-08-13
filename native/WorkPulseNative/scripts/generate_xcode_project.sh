#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
if ! command -v xcodegen >/dev/null 2>&1; then
  print -u2 "XcodeGen is required. Install the official release, then rerun this script."
  exit 1
fi

cd "${ROOT}"
xcodegen generate --spec project.yml --project . --project-root .
print "Generated ${ROOT}/WorkPulse.xcodeproj"
