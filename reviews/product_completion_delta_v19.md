# WorkPulse build 19 最终产品闭环 Delta

日期：2026-08-13（Europe/Oslo）  
证据边界：当前 build 19 稳定源码、已安装 `0.3.1 (19)`、`reviews/final_acceptance_v19_2026-08-13.md`，以及本轮只读复核得到的签名、PlugInKit、运行进程、Widget snapshot、通知 diagnostic 和 verifier 结果。未把 build 18 画面当作 build 19 证据。

## 冻结结论

- **本机个人版**：**Go with one manual Gate**。产品源码与系统表面已经闭环；完成 1 次真实系统通知点击 Gate 后，可称“WorkPulse 本机个人版 1.0 完整验收”。
- **首发范围冻结**：只承诺 `额度 + 运行任务状态 + 一个固定对话入口 + 顶部 Resident/Alert/Expanded + 系统通知兜底 + 菜单栏控制中心`。不再加入新表面或新 adapter。
- **对外一次买断版**：**No-Go**。它是独立商业化项目，不阻止用户本人继续使用，也不要求本机版上架 App Store。

## 已闭环

| 核心链路 | 当前真实证据 | 冻结判断 |
|---|---|---|
| quota-first Resident | 主标题固定为额度窗口与剩余比例；detail 固定为重置时间，有任务时仅追加 `● N`。当前运行记录为 `7 天 · 89% 剩余｜周四 05:34 重置 · ● 2` | **Closed**。任务状态点不再遮蔽额度 |
| 任务状态点与 Expanded | 当前有 2 个活动任务；Resident 显示 `● 2`，Expanded 展示两组额度和任务 A/B；明确终态区分完成、取消、失败和中止，多任务同轮终态不再漏掉 | **Closed** |
| 单任务终态 Alert | 单任务 Alert 已传入专属 `Codex 任务结果` Expanded，包含隐私门控任务名、outcome、运行时长和本机生命周期来源 | **Closed**。点击不再回退到额度 Expanded |
| 隐私 | 新安装默认开启 Privacy Mode；它硬性覆盖任务名和固定入口名，也不提供临时显示旁路；当前 Widget snapshot 为 generic privacy | **Closed** |
| Small Quota / Small Pinned | build 19 的 Widget Extension、App Group、唯一 PlugInKit 记录与 Widget 进程均在运行；当前 schema 5 snapshot 含两组 live quota、2 个任务摘要和 Manual Pin；Small Pinned 当前渲染已验收 | **Closed**。首发桌面只强调这两个 Small，Medium/Large 保留能力但不作为首发叙事重点 |
| 菜单栏控制中心 | 无独立 Dashboard；额度窗口、任务、隐私、顶部层、通知、固定入口、主题与启动设置均集中于 MenuBarExtra | **Closed**。符合“伴生应用而非独立页面” |
| 通知 transport | authorization、Alert、Notification Center、Sound 均 enabled；真实 delivered 列表中已有 task-terminal request | **Closed with system constraints**。Focus 和 macOS 决定是否出现横幅与声音 |

补充技术证据：安装包为 `0.3.1 (19)`；Host 与 Widget 严格验签通过；PlugInKit 仅 1 条 canonical 注册；Swift build 通过；`WorkPulseCoreVerify` 250 checks 通过；`verify_system_surfaces.sh` 通过；当前 Host 与 Widget 进程均运行；最终签名 ZIP SHA-256 为 `c39ceb015978dd9d57fa56632b8c85ccc850baf5b678bbf2ccb6f0db5bd39a71`。

## 本机闭环前仅保留一项

### 真实通知点击仍是手工 Gate

源码已经把 task ID、outcome 和通知内容送入专用 task route，点击设计会回到 WorkPulse 的该任务结果，而不是 Needs You 或额度。真实 task-terminal 通知也已 delivered。

但当前 `workpulse.lastNotificationOpenAt` 不存在，和 final acceptance 一致，说明还没有完成真实系统通知点击。因此不能把“点击回具体任务”写成已实证。

**唯一运行 Gate**：从 macOS 通知中心点击一条 build 19 task-terminal 通知，确认回到 `Codex 任务结果`、outcome 一致、Privacy Mode 下名称隐藏，并留下 notification-open receipt/time。

这里的“回具体任务”冻结定义为：回到 WorkPulse 中该通知对应的任务结果。它**不承诺**打开 Codex 客户端中的原任务；`exact return` 继续明确为不支持。

## 首发明确收缩

- Small Quota 与 Small Pinned 是首发 Widget；Medium/Large 不删除，但不作为首发核心卖点。
- 固定 Gmail 对话只是用户保存的 HTTPS Manual Pin，不读取 Gmail 邮件或执行状态。
- Needs You、Scheduled、Daily Brief 没有可信 production adapter，不进入本机 1.0。
- 顶部岛是受控 `NSPanel`，不是 Apple 向第三方开放的系统 Dynamic Island。
- WidgetKit 是 snapshot/timeline，不承诺秒级实时；通知不承诺绕过 Focus 或系统策略。

以上均为边界冻结，不再转化为 build 19 新需求。

## 对外买断边界

控制中心当前写明“本机开发版”及“正式发布计划采用一次买断”，没有把计划伪装成已实现购买能力。当前安装包是 Personal Team Apple Development 构建；严格验签可用于本机 dogfood，但 Gatekeeper 对外分发评估仍为 rejected。

因此对外买断继续 **No-Go**，直到另一个商业化里程碑完成：

1. Developer ID Application 签名、notarization、stapling 和无 Xcode 干净 Mac 验收；
2. 稳定生产 bundle ID 与签名更新/回滚；
3. 购买、激活、恢复购买、离线与退款/撤销处理；
4. 隐私说明、支持入口和本地数据删除路径。

推荐优先走 **Developer ID direct distribution**。当前 Host 需要读取本机 Codex state/rollout；若改走 Mac App Store，会引入 sandbox 与用户授权目录的架构改造。

## 最终放行语句

在真实 task-terminal 通知点击 Gate 通过后，可宣布：

> WorkPulse build 19 已完成本机个人版首发闭环：以剩余额度和重置时间为主信息，补充运行任务状态，提供 Small Quota、Small Pinned、顶部三态、系统通知兜底和菜单栏控制中心；不承诺真实 Gmail/Scheduled/Daily Brief、打开原 Codex 任务或对外买断分发。
