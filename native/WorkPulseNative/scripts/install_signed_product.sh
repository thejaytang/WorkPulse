#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
ARCHIVE="${1:-${ROOT}/build/full-product/WorkPulse-full-product.zip}"
INSTALL_ROOT="${WORKPULSE_INSTALL_ROOT:-${HOME}/Applications}"
INSTALL_APP="${INSTALL_ROOT}/WorkPulse.app"
STAGE="$(mktemp -d /tmp/workpulse-signed-install.XXXXXX)"
BACKUP=""
INSTALL_COMMITTED=0
REPLACEMENT_STARTED=0
OLD_UNREGISTERED=0
OLD_HOST_WAS_RUNNING=0
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

launch_installed_app() {
  # A build launched from Codex/CI must behave like one launched from Finder.
  # Start with a small login-like environment so no present or future Codex,
  # CI, sandbox, or QA marker can leak into WorkPulse or its App Server child.
  env -i \
    HOME="${HOME}" \
    USER="${USER}" \
    LOGNAME="${LOGNAME}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    LANG="${LANG:-en_US.UTF-8}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    /usr/bin/open "${INSTALL_APP}"
}

restore_installed_app() {
  [[ -d "${INSTALL_APP}" ]] || return 1
  codesign --verify --deep --strict "${INSTALL_APP}" >/dev/null 2>&1 || return 1
  "${LSREGISTER}" -f "${INSTALL_APP}" >/dev/null 2>&1 || return 1
  pluginkit -a "${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || return 1
  launch_installed_app >/dev/null 2>&1 || return 1
  for _ in {1..30}; do
    pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" >/dev/null && break
    sleep 0.1
  done
  local restored_host_count
  restored_host_count="$(pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" | wc -l | tr -d ' ')"
  [[ "${restored_host_count}" == 1 ]] || return 1
  "${ROOT}/scripts/verify_widget_runtime.sh" "${INSTALL_APP}" >/dev/null 2>&1 || return 1
}

cleanup_and_rollback() {
  local exit_code=$?
  trap - EXIT
  if (( exit_code != 0 && INSTALL_COMMITTED == 0 && REPLACEMENT_STARTED == 1 )); then
    local failed_host_pids="$(pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" || true)"
    if [[ -n "${failed_host_pids}" ]]; then
      print -l ${=failed_host_pids} | while read -r pid; do
        [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
      done
      for _ in {1..20}; do
        pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" >/dev/null || break
        sleep 0.1
      done
      local stubborn_host_pids="$(pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" || true)"
      if [[ -n "${stubborn_host_pids}" ]]; then
        print -l ${=stubborn_host_pids} | while read -r pid; do
          [[ -n "${pid}" ]] && kill -9 "${pid}" 2>/dev/null || true
        done
        for _ in {1..20}; do
          pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" >/dev/null || break
          sleep 0.1
        done
      fi
      if pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" >/dev/null; then
        print -u2 "严重错误：失败的新版本进程无法终止；已停止自动恢复以避免双实例"
        rm -rf "${STAGE}"
        exit ${exit_code}
      fi
    fi
    if [[ -e "${INSTALL_APP}" ]]; then
      local failed_app="/tmp/WorkPulse-failed-install-$(date +%Y%m%d-%H%M%S).app"
      pluginkit -r "${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || true
      "${LSREGISTER}" -u "${INSTALL_APP}" >/dev/null 2>&1 || true
      mv "${INSTALL_APP}" "${failed_app}" 2>/dev/null || true
      pluginkit -r "${failed_app}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || true
      "${LSREGISTER}" -u "${failed_app}" >/dev/null 2>&1 || true
      print -u2 "失败的新版本已保留用于诊断：${failed_app}"
    fi
    if [[ -n "${BACKUP}" && -d "${BACKUP}" ]]; then
      if mv "${BACKUP}" "${INSTALL_APP}" && restore_installed_app; then
        print -u2 "安装失败，已验证恢复上一版：${INSTALL_APP}"
      else
        print -u2 "严重错误：自动恢复未通过验收；旧版或失败版本仍保留在 /tmp"
      fi
    fi
  elif (( exit_code != 0 && INSTALL_COMMITTED == 0
      && (OLD_UNREGISTERED == 1 || OLD_HOST_WAS_RUNNING == 1) )); then
    if restore_installed_app; then
      print -u2 "升级在替换前中止，已验证恢复当前版本的系统注册"
    else
      print -u2 "严重错误：当前版本的系统注册恢复未通过验收"
    fi
  fi
  rm -rf "${STAGE}"
  exit ${exit_code}
}
trap cleanup_and_rollback EXIT

[[ -f "${ARCHIVE}" ]] || { print -u2 "未找到团队签名归档：${ARCHIVE}"; exit 2; }
ditto -x -k "${ARCHIVE}" "${STAGE}"
APP="${STAGE}/WorkPulse.app"
WIDGET="${APP}/Contents/PlugIns/WorkPulseWidget.appex"
[[ -d "${WIDGET}" ]] || { print -u2 "归档未嵌入 WorkPulseWidget.appex"; exit 1; }
codesign --verify --deep --strict "${APP}"

HOST_TEAM_ID="$(codesign -dv --verbose=4 "${APP}" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
WIDGET_TEAM_ID="$(codesign -dv --verbose=4 "${WIDGET}" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
[[ -n "${HOST_TEAM_ID}" && "${HOST_TEAM_ID}" != "not set" ]] \
  || { print -u2 "拒绝安装：Host 不是 Apple 团队签名产物"; exit 1; }
[[ -n "${WIDGET_TEAM_ID}" && "${WIDGET_TEAM_ID}" != "not set" ]] \
  || { print -u2 "拒绝安装：Widget 不是 Apple 团队签名产物"; exit 1; }
[[ "${HOST_TEAM_ID}" == "${WIDGET_TEAM_ID}" ]] \
  || { print -u2 "拒绝安装：Host 与 Widget 的 TeamIdentifier 不一致"; exit 1; }

HOST_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP}/Contents/Info.plist")"
WIDGET_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${WIDGET}/Contents/Info.plist")"
[[ "${HOST_BUILD}" == "${WIDGET_BUILD}" ]] \
  || { print -u2 "拒绝安装：Host build ${HOST_BUILD} 与 Widget build ${WIDGET_BUILD} 不一致"; exit 1; }

HOST_GROUPS="$(codesign -d --entitlements - "${APP}" 2>&1 \
  | rg -o '[A-Z0-9]+\.com\.workpulse\.shared' | sort -u)"
WIDGET_GROUPS="$(codesign -d --entitlements - "${WIDGET}" 2>&1 \
  | rg -o '[A-Z0-9]+\.com\.workpulse\.shared' | sort -u)"
[[ "${HOST_GROUPS}" == "${WIDGET_GROUPS}" ]] \
  || { print -u2 "拒绝安装：Host 与 Widget 的 App Group 不一致"; exit 1; }
print "${HOST_GROUPS}" | rg -q --fixed-strings "${HOST_TEAM_ID}.com.workpulse.shared" \
  || { print -u2 "拒绝安装：缺少团队作用域 WorkPulse App Group"; exit 1; }

mkdir -p "${INSTALL_ROOT}"
OLD_EXECUTABLE="${INSTALL_APP}/Contents/MacOS/WorkPulse"
OLD_WIDGET_EXECUTABLE="${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget"
OLD_WIDGET_BUNDLE="${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex"
OLD_PIDS="$(pgrep -f "^${OLD_EXECUTABLE}$" || true)"
if [[ -n "${OLD_PIDS}" ]]; then
  OLD_HOST_WAS_RUNNING=1
  print -l ${=OLD_PIDS} | while read -r pid; do
    [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  done
  for _ in {1..20}; do
    pgrep -f "^${OLD_EXECUTABLE}$" >/dev/null || break
    sleep 0.1
  done
  pgrep -f "^${OLD_EXECUTABLE}$" >/dev/null \
    && { print -u2 "旧 WorkPulse 宿主未退出，已取消替换"; exit 1; }
fi
if [[ -d "${OLD_WIDGET_BUNDLE}" ]]; then
  # A placed desktop Widget can immediately relaunch the old extension after
  # SIGTERM. Remove its registration first, then replace and register the new
  # embedded extension below. Widget placement preferences remain intact.
  if ! pluginkit -r "${OLD_WIDGET_BUNDLE}" >/dev/null 2>&1; then
    print -u2 "旧 WorkPulse Widget 无法安全注销；已保留当前安装并取消升级"
    exit 1
  fi
  OLD_UNREGISTERED=1
  "${LSREGISTER}" -u "${INSTALL_APP}" >/dev/null 2>&1 || true
fi
OLD_WIDGET_PIDS="$(pgrep -f "^${OLD_WIDGET_EXECUTABLE}( |$)" || true)"
if [[ -n "${OLD_WIDGET_PIDS}" ]]; then
  print -l ${=OLD_WIDGET_PIDS} | while read -r pid; do
    [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  done
  for _ in {1..20}; do
    pgrep -f "^${OLD_WIDGET_EXECUTABLE}( |$)" >/dev/null || break
    sleep 0.1
  done
  pgrep -f "^${OLD_WIDGET_EXECUTABLE}( |$)" >/dev/null \
    && { print -u2 "旧 WorkPulse Widget 扩展未退出，已取消替换"; exit 1; }
fi
REPLACEMENT_STARTED=1
if [[ -e "${INSTALL_APP}" ]]; then
  BACKUP="/tmp/WorkPulse-before-signed-$(date +%Y%m%d-%H%M%S).app"
  mv "${INSTALL_APP}" "${BACKUP}"
  pluginkit -r "${BACKUP}/Contents/PlugIns/WorkPulseWidget.appex" >/dev/null 2>&1 || true
  "${LSREGISTER}" -u "${BACKUP}" >/dev/null 2>&1 || true
  print "旧版本已移动到可恢复备份：${BACKUP}"
fi
ditto "${APP}" "${INSTALL_APP}"
if [[ "${WORKPULSE_INSTALL_TEST_FAIL_AFTER_COPY:-0}" == 1 ]]; then
  print -u2 "测试注入：复制后中止，用于验证自动回滚"
  exit 91
fi
codesign --verify --deep --strict "${INSTALL_APP}"
cmp -s "${APP}/Contents/MacOS/WorkPulse" "${INSTALL_APP}/Contents/MacOS/WorkPulse" \
  || { print -u2 "安装后 Host binary 与签名归档不一致"; exit 1; }
cmp -s "${WIDGET}/Contents/MacOS/WorkPulseWidget" \
  "${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex/Contents/MacOS/WorkPulseWidget" \
  || { print -u2 "安装后 Widget binary 与签名归档不一致"; exit 1; }

"${LSREGISTER}" -f "${INSTALL_APP}"
pluginkit -a "${INSTALL_APP}/Contents/PlugIns/WorkPulseWidget.appex"
launch_installed_app
if [[ "${WORKPULSE_INSTALL_TEST_FAIL_AFTER_OPEN:-0}" == 1 ]]; then
  print -u2 "测试注入：启动新版本后中止，用于验证运行态自动回滚"
  exit 92
fi

for _ in {1..30}; do
  HOST_PIDS="$(pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" || true)"
  [[ "$(print -l ${=HOST_PIDS} | sed '/^$/d' | wc -l | tr -d ' ')" == 1 ]] && break
  sleep 0.1
done
HOST_COUNT="$(pgrep -f "^${INSTALL_APP}/Contents/MacOS/WorkPulse$" | wc -l | tr -d ' ')"
[[ "${HOST_COUNT}" == 1 ]] \
  || { print -u2 "安装后宿主实例数不是 1：${HOST_COUNT}"; exit 1; }
"${ROOT}/scripts/verify_widget_runtime.sh" "${INSTALL_APP}"
INSTALL_COMMITTED=1
print "已安装并启动团队签名 WorkPulse：${INSTALL_APP}"
print "安装、同源二进制和 Widget runtime 验收均已通过"
