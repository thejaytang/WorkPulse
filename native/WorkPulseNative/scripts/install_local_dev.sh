#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
ARCHIVE="${1:-${ROOT}/build/WorkPulse-local-dev.zip}"
INSTALL_ROOT="${WORKPULSE_INSTALL_ROOT:-${HOME}/Applications}"
INSTALL_APP="${INSTALL_ROOT}/WorkPulse.app"
STAGE="$(mktemp -d /tmp/workpulse-local-install.XXXXXX)"
BACKUP=""
INSTALLED=false

cleanup() {
  rm -rf "${STAGE}"
  if [[ "${INSTALLED}" != true && -n "${BACKUP}" && -d "${BACKUP}" && ! -e "${INSTALL_APP}" ]]; then
    mv "${BACKUP}" "${INSTALL_APP}"
    print -u2 "安装失败，已恢复原 WorkPulse.app"
  fi
}
trap cleanup EXIT

[[ -f "${ARCHIVE}" ]] || { print -u2 "未找到本机开发归档：${ARCHIVE}"; exit 2; }
ditto -x -k "${ARCHIVE}" "${STAGE}"
APP="${STAGE}/WorkPulse.app"
WIDGET="${APP}/Contents/PlugIns/WorkPulseWidget.appex"

[[ -d "${WIDGET}" ]] || { print -u2 "归档未嵌入 WorkPulseWidget.appex"; exit 1; }
codesign --verify --deep --strict "${APP}"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :WorkPulseWidgetRuntimeEnabled' "${APP}/Contents/Info.plist")" == false ]] \
  || { print -u2 "本机开发包必须关闭无团队签名的 Widget 共享容器写入"; exit 1; }

# Stop only the currently installed WorkPulse executable before replacing its bundle.
killall WorkPulseMenuBar 2>/dev/null || true
mkdir -p "${INSTALL_ROOT}"
if [[ -e "${INSTALL_APP}" ]]; then
  BACKUP="/tmp/WorkPulse-before-local-$(date +%Y%m%d-%H%M%S).app"
  mv "${INSTALL_APP}" "${BACKUP}"
  print "旧版本已移动到可恢复备份：${BACKUP}"
fi

ditto "${APP}" "${INSTALL_APP}"
codesign --verify --deep --strict "${INSTALL_APP}"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"${LSREGISTER}" -f "${INSTALL_APP}"
open -n "${INSTALL_APP}"
INSTALLED=true

print "已安装并启动 WorkPulse 本机开发版：${INSTALL_APP}"
print "此版本的菜单栏、刘海和通知可测试；Widget Gallery 等待 Apple Development 团队签名。"
