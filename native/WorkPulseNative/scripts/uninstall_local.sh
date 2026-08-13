#!/bin/zsh
set -euo pipefail

USER_ROOT="${WORKPULSE_USER_ROOT:-${HOME}}"
INSTALL_ROOT="${WORKPULSE_INSTALL_ROOT:-${USER_ROOT}/Applications}"
APP="${INSTALL_ROOT}/WorkPulse.app"
STAMP="$(date +%Y%m%d-%H%M%S)"
TRASH_DIR="${USER_ROOT}/.Trash/WorkPulse-uninstalled-${STAMP}"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[[ -n "${USER_ROOT}" && "${USER_ROOT}" != "/" ]] || {
  print -u2 "拒绝卸载：用户目录无效"
  exit 1
}
[[ "${APP}" == */Applications/WorkPulse.app ]] || {
  print -u2 "拒绝卸载：应用路径不符合预期：${APP}"
  exit 1
}

mkdir -p "${TRASH_DIR}"

host_pids="$(pgrep -f "^${APP}/Contents/MacOS/WorkPulse$" || true)"
widget_pids="$(pgrep -f "^${APP}/Contents/PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget" || true)"
for pid in ${=host_pids} ${=widget_pids}; do
  [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
done
for _ in {1..20}; do
  pgrep -f "^${APP}/Contents/(MacOS/WorkPulse|PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget)" >/dev/null || break
  sleep 0.1
done
stubborn_pids="$(pgrep -f "^${APP}/Contents/(MacOS/WorkPulse|PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget)" || true)"
for pid in ${=stubborn_pids}; do
  [[ -n "${pid}" ]] && kill -9 "${pid}" 2>/dev/null || true
done

if [[ -d "${APP}/Contents/PlugIns/WorkPulseWidget.appex" ]]; then
  pluginkit -r "${APP}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || true
fi
if [[ -d "${APP}" ]]; then
  "${LSREGISTER}" -u "${APP}" >/dev/null 2>&1 || true
  mv "${APP}" "${TRASH_DIR}/WorkPulse.app"
fi

# Preserve a recoverable copy before clearing cached preferences.
defaults export com.workpulse.prototype "${TRASH_DIR}/com.workpulse.prototype.export.plist" >/dev/null 2>&1 || true
defaults delete com.workpulse.prototype >/dev/null 2>&1 || true

items=(
  "${USER_ROOT}/Library/Preferences/WorkPulseMenuBar.plist"
  "${USER_ROOT}/Library/Preferences/com.workpulse.prototype.plist"
  "${USER_ROOT}/Library/Group Containers/.com.workpulse.shared"
  "${USER_ROOT}/Library/Group Containers/group.com.workpulse.prototype"
  "${USER_ROOT}/Library/Application Support/WorkPulse"
  "${USER_ROOT}/Library/Application Support/CrashReporter/WorkPulseMenuBar_5E9FA8BE-76C5-500A-B7CE-23C5368B867A.plist"
  "${USER_ROOT}/Library/Application Support/CrashReporter/WorkPulseAppServerProbe_5E9FA8BE-76C5-500A-B7CE-23C5368B867A.plist"
  "${USER_ROOT}/Library/Application Support/CrashReporter/WorkPulseCoreVerify_5E9FA8BE-76C5-500A-B7CE-23C5368B867A.plist"
  "${USER_ROOT}/Library/Application Support/CrashReporter/WorkPulse_5E9FA8BE-76C5-500A-B7CE-23C5368B867A.plist"
)

while IFS= read -r team_container; do
  [[ -n "${team_container}" ]] && items+=("${team_container}")
done < <(find "${USER_ROOT}/Library/Group Containers" -maxdepth 1 -type d -name '*.com.workpulse.shared' -print 2>/dev/null)

for item in "${items[@]}"; do
  if [[ -e "${item}" ]]; then
    safe_name="${item#${USER_ROOT}/}"
    safe_name="${safe_name//\//__}"
    mv "${item}" "${TRASH_DIR}/${safe_name}"
  fi
done

remaining_processes="$(pgrep -f "^${APP}/Contents/(MacOS/WorkPulse|PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget)" | wc -l | tr -d ' ')"
[[ "${remaining_processes}" == 0 ]] || {
  print -u2 "卸载未完成：仍有 ${remaining_processes} 个 WorkPulse 进程"
  exit 1
}
[[ ! -e "${APP}" ]] || {
  print -u2 "卸载未完成：应用仍存在于 ${APP}"
  exit 1
}

print "WorkPulse 已终止并卸载。"
print "可恢复备份：${TRASH_DIR}"
