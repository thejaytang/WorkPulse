# WorkPulse build 23 最终技术 Delta

> 复核时间：2026-08-13（Europe/Oslo）  
> 方式：只读源码、脚本、可执行验证器与新候选 archive；未修改产品源码、签名或用户设置  
> 放行状态：**No remaining source P0/P1; final archive frozen; product acceptance gates remain**

## 1. 结论

本轮指定的四个 Delta 中，业务源码层面已全部收敛：

1. Pinned Widget 的 empty/corrupt/unsupported 已进入专用 `workpulse://routine/setup` 恢复路由，Host 会给出可执行的菜单栏设置指引。
2. Expanded 键盘保护已从永久 latch 改为最后一次键盘交互后 15 秒到期，可续期，且关闭/隐藏/停止监视时清零。
3. installer after-open rollback 状态机已具备 TERM、stubborn PID `kill -9`、归零确认、旧版恢复与 exactly-one Host/runtime 验收。
4. schema v6 与 corrupt snapshot self-heal/quarantine 均有可执行 fixture，I/O 错误仍 fail closed。

可执行验证结果：

```text
WorkPulseCore verification passed: 260 checks
WorkPulse system-surface verification passed
WorkPulse Widget source type-check passed
install_signed_product.sh: zsh syntax Pass
```

上轮发现的 **P1 installer compatibility defect** 已关闭：build/install 脚本均改用当前 `codesign -d --entitlements -` 接口，Host/Widget 实测都能提取 `<APPLE_TEAM_ID>.com.workpulse.shared`；verifier 会明确拒绝旧 `--entitlements :-` 写法。安装后 Host/Widget 二进制与新 archive 也完全同源。

先前观测到的启动短暂 0 buckets 已关闭。宿主现在等待首次 App Server 尝试得到明确成功或失败后才允许首次外发；后续刷新期间保留上一份 live quota。重装时每 250ms 连续采样 15 秒，revision 22→23 期间 quota buckets 始终为 2，没有空额度覆盖。

| 分类 | 判定 |
|---|---|
| routine/setup recovery | **Supported at source** |
| Expanded keyboard protection reset | **Supported at source** |
| rollback state machine / exit 92 | **Supported at source + prior runtime evidence** |
| schema v6 / corrupt self-heal | **Supported + executable fixture** |
| App Group entitlement extraction | **Supported; P1 Closed** |
| 最终 archive | **Frozen and installed; SHA verified** |
| 真实 Gallery / Notification / multi-display | **Constrained; runtime gates pending** |

## 2. Supported：routine/setup recovery route

恢复链路现在是一致且有类型的：

- `WorkPulseWidget.swift:575-598` 允许 unavailable view 接收不同 `recoveryURL`；
- Pinned Widget 的 empty/corrupt/unsupported 在 `:711-716` 均使用 `workpulse://routine/setup`；
- `Models.swift:268-299` 定义 `.routineSetup` 并严格解析无 query/fragment 的路由；
- `WorkPulseMenuBarApp.swift:1603-1609` 处理该路由，明确指引用户打开菜单栏 WorkPulse 的“控制 → 固定入口”；
- `WorkPulseCoreVerify/main.swift:406-410` 执行专用 route fixture。

判定：先前“Pinned 错误态跳到 quota”的 P1 已关闭。当前实现是顶部引导，而不是程序化强制展开菜单；这是受 macOS 菜单栏交互形态限制的可接受约束，不是 P1。仍需在真实 Widget Gallery 安装后验证点按能唤起 Host 并显示该指引。

## 3. Supported：Expanded keyboard protection reset

`NotchOverlayController.swift:412-471` 的最新状态机为：

- 非 Esc `keyDown` 调用 `protectExpandedKeyboardInteraction()`；
- 保护时间为最后一次键盘交互后 15 秒，新按键会 cancel 旧 task 并续期；
- 到期后将 `expandedKeyboardInteractionActive` 设为 false；如果鼠标不在面板内，重新进入 300ms 离开收起流程；
- Esc、外部点击、`dismissExpanded()`、`hide()` 以及 `stopExpandedEventMonitors()` 均能结束交互；
- VoiceOver/Switch Control 仍保持不自动打断的无障碍保护。

`verify_system_surfaces.sh:181` 已覆盖 15s 有界保护；260 checks 包含“可续期且不会永久阻止收回”。先前永久 latch P1 已关闭。

约束：15s 是行为近似，不是对 first responder 生命周期的精确建模。它能防止永久卡住，但 Full Keyboard Access、VoiceOver 与 Switch Control 的最终判定仍必须来自实机。

## 4. Supported：installer rollback

`install_signed_product.sh:16-87, 160-185` 已形成完整的回滚状态机：

1. 启动新 Host 后可用 `WORKPULSE_INSTALL_TEST_FAIL_AFTER_OPEN=1` 注入 exit 92；
2. 先 TERM 失败的新 Host，等待后重新获取 stubborn PID；
3. 必要时 `kill -9`，再等待并断言新 Host 归零；
4. 无法归零时停止自动恢复，避免新旧双实例；
5. 归零后才注销/移走失败 App，将 backup 恢复到 canonical path；
6. 恢复后重新验签、注册、打开，并严格要求 `restored_host_count == 1`，再运行 Widget runtime verifier。

已有的 exit 92 故障注入证据为：exit 92，输出“安装失败，已验证恢复上一版”；失败副本保留于 `/tmp/WorkPulse-failed-install-20260813-125549.app`；协调验收记录恢复后 `host_processes=1`、`widget_processes=1`，PlugInKit 只有 canonical provider。

判定：回滚控制流本身 **Supported**，entitlement 预检 P1 也已关闭。安装器将启动入口收敛为 `launch_installed_app()`，并使用 `env -i` 只保留 HOME/USER/LOGNAME/系统 PATH/LANG/TMPDIR，防止代理、CI、sandbox 或 QA 标记泄漏给 WorkPulse 与其 App Server 子进程。最终 normal `env -i` install 已通过，验收记录为 strict codesign Pass、Host=1、Widget=1、PlugInKit=1。

## 5. Supported：schema v6 / self-heal / quarantine

`Models.swift:320-321` 定义 `WidgetSnapshot.currentSchemaVersion = 6`，Host 与 Extension 共用该常量。

`SnapshotStore.swift:48-91` 的 `writeNext()`：

- unsupported old schema 从 revision 1 重建；
- 仅 `DecodingError` 进入 corrupt recovery；
- 先使用 `copyItem` 保留 `widget.json.corrupt-<UUID>` 原始字节，再原子写回 canonical snapshot；
- 权限、磁盘与其他 I/O 错误不会被误吞。

`WorkPulseCoreVerify/main.swift:881-899` 真实写入损坏 JSON，验证 repair revision 1、canonical 立即可读、恣好一份 quarantine 副本、且副本字节与损坏原文完全相同。此项不再是纯静态断言。

剩余约束：quarantine 副本尚无 retention policy，长期可能形成小量诊断文件积累，属 P2 运维卫生，不是当前 P0/P1。

## 6. Closed P1：entitlement extraction 兼容性

最终 archive 于 13:10:47 冻结；Sources、WidgetExtension、scripts 与 Xcode product input 没有比它更新。冻结信息：

```text
WorkPulse-full-product.zip
version/build: 0.3.1 (23)
SHA-256: 41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa
Host TeamIdentifier: <APPLE_TEAM_ID>
Widget TeamIdentifier: <APPLE_TEAM_ID>
Info App Group: <APPLE_TEAM_ID>.com.workpulse.shared
Widget runtime enabled: true
```

解包后使用当前写法读取 Host/Widget：

```text
codesign -d --entitlements -  <bundle>  -> <APPLE_TEAM_ID>.com.workpulse.shared
```

`build_full_product.sh:77-82` 与 `install_signed_product.sh:126-133` 都已使用新接口。`verify_system_surfaces.sh:15-22` 会扫描 build/install 两个脚本，发现 `--entitlements :-` 即失败。system verifier 实跑通过。

新 archive 与已安装产物的二进制同源证据：

```text
Host SHA-256 (archive = installed):
20057bcd522aff597ae27f6264d74bdeb5e86fff9d3c8678d4e49f0c10353e78
Widget SHA-256 (archive = installed):
b1fa708b7f19f4aa588284b27e0a8ea8c93e9669bd91686b08c01a72a342308b
```

判定：上轮 entitlement extraction **P1 Closed**。

补充：本受限审查会话的 `codesign --verify --deep --strict` 仍返回 `CSSMERR_TP_NOT_TRUSTED`，无法独立完成证书链 trust 验收；正常登录会话的成功安装证据是此项的主要产物 Gate。

## 7. Supported / Constrained / Unsupported 矩阵

| 能力 | 判定 | 证据边界 |
|---|---|---|
| Widget 缺失/损坏后恢复 | **Supported** | 专用 route + Host guidance + fixture |
| Expanded 悬停和键盘保护 | **Supported at source** | 有界 15s reset；实机 assistive tech 待验 |
| corrupt snapshot self-heal | **Supported** | 真实 corrupt fixture 通过 |
| schema v5 → v6 | **Supported at store level** | 旧 schema fixture 通过；真实 App Group 待验 |
| rollback after new Host open | **Supported by control flow and prior exit 92 run** | normal `env -i` install 已验证；冻结包的 exit 92 证据应留档 |
| 当前 archive 的 installer preflight | **Supported** | 新接口可读取 Host/Widget App Group，P1 Closed |
| Widget 启动额度连续性 | **Supported** | 15s / 250ms 连续采样始终为 2 buckets，revision 22→23 原位更新 |
| Notification click receipt | **Constrained** | 源码/自动化存在，最终冷启动实机回流待验 |
| Widget Gallery 可见性/点按 | **Constrained** | 需最终安装包和唯一 PlugInKit provider |
| multi-display / notch placement | **Constrained** | 策略代码已覆盖，需内建+外接屏实机 |
| 隐私任务名隐藏 | **Supported at source** | 仍需最终 archive 通知和 Widget 肉眼检查 |

## 8. Remaining gates

### 必须先完成

1. 将冻结 archive 的 strict signing、normal install、Host=1、Widget=1、PlugInKit=1 完整输出留档。
2. 如果要将 rollback 也纳入每个冻结包的必经 Gate，还应对 `d53a0b...` 记录一次 after-open exit 92 输出；先前版本已实测该控制流。

`d53a0b...` archive 内的 App 与当前安装 App 已验证同源。最终 App Group snapshot 为 schema v6 revision 21，包含 2 个 quota buckets、2 个 running tasks，且 routine title 为 generic `每日例程`。

### 最终产品 Gate

1. 真实 App Group 完成 v5 → v6 与 corrupt → quarantine → repair → Widget reload。
2. Gallery 搜索/添加 Quota 和 Pinned，点按 usage/setup 恢复路由。
3. Notification default/OPEN receipt，包括 Host terminated 冷启动。
4. VoiceOver、Switch Control、Full Keyboard Access、最大字号、鼠标悬停/移出。
5. 内建屏+外接屏下 Resident、Alert 与 Expanded 的归属与位置。

## 9. 最终放行语句

当前只能准确表述为：

> routine/setup recovery、Expanded 有界键盘保护、rollback 状态机、schema v6、corrupt self-heal 与启动 quota 连续性已收敛；entitlement extraction P1 已关闭。260 checks、system verifier 和 Widget typecheck 通过。当前 archive SHA 为 `41fafea9e4e6c069b90a18a5190d29a81e5709b3342a7830fd2ffe38629635aa`，normal `env -i` install 与 strict codesign 通过，Host=1、Widget=1、PlugInKit=1，archive/installed binary 同源；schema v6 revision 23 快照包含 2 quota buckets、2 running tasks 与 generic routine title。当前未发现剩余源码 P0/P1。真实 Gallery/Notification/multi-display/accessibility 仍是产品端最终验收 Gate。
