#!/bin/zsh
set -euo pipefail

APP_PATH="${1:-${HOME}/Applications/WorkPulse.app}"
WIDGET_PATH="${APP_PATH}/Contents/PlugIns/WorkPulseWidget.appex"
WIDGET_ID="com.workpulse.prototype.widgets"

fail() {
  print -u2 "FAIL: $1"
  exit 1
}

[[ -d "${APP_PATH}" ]] || fail "未找到宿主应用 ${APP_PATH}"
[[ -x "${WIDGET_PATH}/Contents/MacOS/WorkPulseWidget" ]] || fail "宿主未嵌入可执行 Widget Extension"
codesign --verify --deep --strict "${APP_PATH}" || fail "宿主或扩展签名无效"

if ! PLUGIN_RECORD="$(pluginkit -m -A -D -vvv -i "${WIDGET_ID}" 2>&1)"; then
  fail "无法查询 PlugInKit：${PLUGIN_RECORD}"
fi
print "${PLUGIN_RECORD}" | rg -q --fixed-strings "Path = ${WIDGET_PATH}" \
  || fail "PlugInKit 没有把 Widget 关联到已安装宿主"
PLUGIN_COUNT="$(print "${PLUGIN_RECORD}" | rg -c '^\s+com\.workpulse\.prototype\.widgets\(')"
[[ "${PLUGIN_COUNT}" == 1 ]] \
  || fail "PlugInKit 同时登记了 ${PLUGIN_COUNT} 份 WorkPulse Widget；请注销 DerivedData 或 /tmp 中的历史宿主"

SIGNING_DETAILS="$(codesign -dv --verbose=4 "${WIDGET_PATH}" 2>&1)"
TEAM_ID="$(print "${SIGNING_DETAILS}" | sed -n 's/^TeamIdentifier=//p' | head -1)"
[[ -n "${TEAM_ID}" && "${TEAM_ID}" != "not set" ]] \
  || fail "Widget 仍是 ad-hoc 签名，缺少 TeamIdentifier；这只能证明包结构，不能通过 Widget Gallery 运行门禁"

print "PASS: Widget 已嵌入、严格验签、关联宿主，并具有团队签名 (${TEAM_ID})"
print "NEXT: 仍需在 macOS 组件库中搜索、添加、刷新并点击验证后才能宣布完成"
