# WorkPulse UI/UX V6.1 Delta Review

> 日期：2026-08-11  
> 范围：最新 Native 源码、`output/html-v6/manual-truth-dark.jpeg`、现有 `output/native`  
> 判定门槛：仅记录当前仍阻断 Native Shell 用户内测的 P0。

## 结论

**源码层的状态真实性 P0 已关闭；当前只剩 1 个 P0 验证 blocker：最新 Native 运行态证据尚未补齐。**

开发机上的工程 dogfood 可以继续，但在补齐最新 Native 截图和对应 smoke test 前，不给予面向用户的 UI/UX 内测签字。Widget、刘海 overlay、系统通知和跨设备分发仍属于后续平台 Gate，不包含在本次 Native Shell 放行中。

## 当前唯一 P0

### P0-01：最新 Native build 尚无对应运行态视觉证据

最新菜单栏源码时间为 13:11，最新本机开发归档时间为 13:12；`output/native` 四张截图仍为 12:35 的旧实现。Mac 锁屏可以解释证据缺失，但不能替代验证。当前无法从 artifact 直接确认以下修复在真实 Native UI 中没有布局、状态同步或回归问题：

- Manual 使用中性状态图标，并朗读“手动未同步”；
- Verified 演示明确写“未连接真实来源”，仅有 Needs You 时使用橙色；
- quota 演示、刷新中和失败均为中性状态，只有 fresh live quota 为绿色；
- 成功后再次读取失败时，旧 bucket、旧百分比和绿色健康状态全部消失；
- 多 bucket 列表不会裁切窗口或让主 CTA、反馈文案不可见；
- Privacy、无 URL、浅色和深色仍保持此前行为。

关闭标准：

- **AC-V6.1-01**：使用时间不早于最新 Swift 源码的 Native build，重新生成 Dark + Manual + Privacy、Dark + Verified + Privacy、Dark + Verified + title opt-in、Light + Verified + Privacy 四张截图。
- **AC-V6.1-02**：补充 quota live success、success 后 failure 两个运行态；failure 画面必须显示“额度不可用”，不显示旧 bucket、百分比或绿色状态。
- **AC-V6.1-03**：至少用 2-bucket 真实或确定性 fixture 验证 Dashboard 无裁切、无横向溢出，按钮和反馈仍可见。
- **AC-V6.1-04**：截图应在视图与状态动画完成后采集，文字与状态图标清晰可读；文件时间和 build 标识一并记录到 `native-qa.md`。
- **AC-V6.1-05**：VoiceOver smoke test 能分别读出“手动未同步”“需要处理 N 项”“额度演示数据”“额度已更新”“额度可能已过期”“额度不可用”。

## V6 P0 关闭确认

原 V6 的菜单栏状态真实性 P0 已在最新源码中关闭：

1. routine 状态图标由 `verifiedDemoEnabled && attentionCount > 0` 决定；Manual 为中性 `minus.circle`，不再无条件显示橙点。
2. quota 状态由 `QuotaConnectionState` 驱动；demo、refreshing、unavailable 为中性色，fresh live 为绿色，stale live 为琥珀色，并提供文字与 accessibility label。
3. quota probe 失败会清空 `rateLimitBuckets`、`selectedQuotaLimitID` 和 quota 数值，并切换到 unavailable，旧百分比不会继续显示。
4. Dashboard 会逐项显示多个 rate-limit bucket，不再只呈现一个无法解释的汇总值。
5. Widget snapshot 始终使用 `manualRoutine`；只有 `quotaConnectionState == .live` 才发布 quota，Verified 演示状态和 demo quota 不会进入外部表面。
6. HTML V6 持续显示“Design simulation · 非实时数据”；Manual 与 quota 演示均使用中性点；Verified 文案改为“交互演示 · 未连接真实来源”。
7. HTML 和 Native 的打开反馈均不再声称 exact return，只确认已发送打开/导航请求。

## 当前放行判断

- **开发机工程 dogfood：Go。** 可以继续验证 quota probe、Manual/Verified、Privacy、URL 与多 bucket。
- **面向用户的 Native Shell UI/UX 内测：Conditional No-Go。** 仅等待 P0-01 的 Native 运行态证据；源码层没有发现新的 P0 交互矛盾。
- **补齐 AC-V6.1-01 至 05 后：UI/UX 可转 Go。** 仍需单独满足分发签名和平台 Gate。

