# WorkPulse build 20 本机验收记录

> 冻结时间：2026-08-13 07:21 CEST  
> 版本：0.3.1 (20)  
> 结论：本机 personal dogfood **Go with constraints**；对外发布 **No-Go**

## 冻结产物

- 归档：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`ef94a3d2078545506f0a53f522fdd9812683a0213e5f40b60c83d8a51142444e`
- 安装：`~/Applications/WorkPulse.app`
- Host bundle：`com.workpulse.prototype`
- Widget bundle：`com.workpulse.prototype.widgets`
- TeamIdentifier：`<APPLE_TEAM_ID>`
- Host 与 Widget 均为 arm64 + x86_64 Universal Binary。
- 归档后无源码文件更新；已安装 Host/Widget 与归档同源并通过 `codesign --deep --strict`。

## 自动验收

- SwiftPM 全量编译：Pass。
- `WorkPulseCoreVerify`：253 checks Pass。
- Widget source compile/typecheck：Pass。
- System surface contract：Pass。
- 真实 Xcode Release build：Pass。
- Host/Widget 同 TeamIdentifier、同 App Group、同 build 20：Pass。
- Widget Extension 嵌入、系统注册、单一宿主进程：Pass。
- 安装故障注入：复制新版后故意中断，旧版自动恢复并通过签名、注册、启动和 Widget runtime 验收。
- 锁屏 20 秒快照稳定性：revision `3455 -> 3455`，任务数不变时无重复 Widget 写入。
- App Group snapshot schema 5：实时 Codex App Server provenance，2 个 quota bucket，2 个 generic 运行任务计数，不外发未连接 Needs You。
- 锁屏运行样本：CPU 0.0%，RSS 约 60 MB；锁屏任务轮询退避至 120 秒。

## build 20 关键收口

1. Resident 始终 quota-first：保留剩余额度、窗口与 reset，任务只作为 `●N` 次级指示。
2. 系统任务通知永远 generic，不使用“刘海和菜单栏显示任务名称”授权。
3. 通知点击后才从本机缓存恢复结果；只有明确授权时才保存名称。开启 Privacy Mode 或撤销名称授权会立即清除已缓存名称。
4. 通知不再提供无法保证重投的“稍后”假动作；仅默认点击和明确查看动作可打开路由。
5. Alert hover、Expanded hover、键盘交互、VoiceOver 与 Switch Control 都会保护交互期间不自动收回。
6. TaskReader 缓存绑定 device/inode，文件截断或路径替换后 fail closed，不复用旧任务生命周期。
7. 任务轮询根据 active/idle/locked 在 5、10、30、60、120 秒之间自适应，解锁立即刷新。

## 仍需人工真机验收

- Mac 当前锁屏，因此本轮尚未采集同一最终 build 20 的 Control Center、Resident、Expanded 新截图。
- 需在解锁后从真实 macOS 通知点击一次，确认 `request/action/route/result/openedAt` 回执出现，并在 WorkPulse 顶部层显示对应任务结果。
- 需在解锁后用键盘和 VoiceOver 完成 Expanded 焦点与不自动收回的运行态验收。
- 多屏、clamshell、全屏与 Focus 模式仍需最终矩阵。

## 发布边界

- 本机个人使用：**Go with constraints**。
- 对外一次买断销售：**No-Go**。当前为 Personal Team Apple Development 签名，还需 Developer ID、notarization、发布更新与购买/恢复机制。
- ChatGPT/Codex 真实 approval/needs-input、Gmail/Scheduled 自动状态和 exact return 仍为 gated，不在当前能力中冒充实现。
