# WorkPulse build 21 质疑审查：极简 Delta

> 角色：质疑智能体  
> 复审时间：2026-08-13（Europe/Oslo）  
> 对象：build 21 源码、最终 ZIP 与已安装 `~/Applications/WorkPulse.app`  
> 边界：只读复核；本轮不修改产品源码或用户设置

## 结论

- **已确认 P0/P1 源码缺陷：0。**
- build 21 源码核心与当前 Mac dogfood：**Go**。
- build 20 留下的两项隐私 **P2** 已在 build 21 **source closed**。
- 本机个人版完整验收仍为 **Conditional Go**，原因没有变化：真实通知 click/open 和同一 build 的 GUI/Accessibility smoke 尚缺运行证据。
- 对外一次买断分发仍为 **No-Go**，缺 Developer ID、notarization、购买恢复、更新与支持链。这不是 build 21 功能回归。

## 产物身份与回归验证

| 项目 | 本轮只读证据 | 判定 |
|---|---|---|
| 已安装版本 | `0.3.1 (21)` | Pass |
| 最终 ZIP | `native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip` | Pass |
| ZIP SHA-256 | `a427ed893527f54c8ba4057a1de842e8e45dc1269465c48fada3a6c848ca0f2c` | Pass |
| ZIP Host / Widget build | 均为 build 21 | Pass |
| ZIP 与已安装 Host | executable byte-for-byte identical | Pass |
| ZIP 与已安装 Widget | executable byte-for-byte identical | Pass |
| 系统信任环境严格验签 | Host 与 Widget 均 valid on disk，并满足 Designated Requirement | Pass |
| Widget runtime | 已嵌入、关联宿主、Team `<APPLE_TEAM_ID>` | Pass |
| System surface contract | 全部通过 | Pass |
| Widget type-check | 通过；仅出现沙箱内 SwiftPM cache 不可写提示，无 Swift 源码 warning | Pass |
| CoreVerify | 253 checks | Pass |

## Source closed：build 20 的两项 P2

### 1. 通知隐私迁移完成标记

`NotificationCoordinator.removeLegacyTaskNotificationsIfNeeded` 现在：

1. 以 migration `< 21` 为执行条件；
2. 分别进入 delivered 与 pending 两个异步查询；
3. 两个 callback 内发出对应旧 `workpulse.task-terminal.*` 移除请求后才 `leave()`；
4. 仅在 `DispatchGroup.notify` 中写入 migration `21`。

这关闭了“清理 callback 尚未完成就永久写入迁移成功”的异常终止窗口。当前本机 defaults 中 migration 值也已为 `21`。

**判定：P2 Closed。**

### 2. 启动时任务名称缓存不变式

宿主初始化现在先从 defaults 解码 `recentTaskTerminalResults`，随后立即执行：

```swift
if privacyMode || !showTaskNamesInNotch {
    scrubPersistedTaskNames()
}
```

因此，即使旧版本、异常退出或外部 defaults 修改留下 displayName，只要 Privacy Mode 开启或名称未获授权，启动路径就会把名称从持久化结果中擦除，而不只是显示层临时隐藏。

当前本机状态为 Privacy Mode 开启、名称授权不存在，`workpulse.recentTaskTerminalResults` 也不存在。

**判定：P2 Closed。**

## Runtime pending：仍不是源码 blocker

### R1. 真实系统通知 click/open

当前仍没有 `workpulse.lastNotificationOpenReceipt` 或 `workpulse.lastNotificationOpenAt`。这证明“尚未取证”，不能推导为通知路由失败。

最小验收：在 App 后台和退出两种状态各点击一次真实 task-terminal 通知，核对 `request/action/route/result/openedAt`，并确认顶部 Expanded 恢复同一 opaque task ID 的结果；Privacy Mode 下所有外部文案保持 generic。

### R2. 同一 build 21 的 GUI 与 Accessibility smoke

仍需在解锁状态验证 Control Center、Resident、Alert、Expanded 的：

- hover 内保持、移出后收回；
- Full Keyboard Access 的焦点顺序、动作触发与 Esc；
- VoiceOver / Switch Control 交互期间不自动收回；
- Light / Dark / System、大字号与 Increase Contrast 不裁切。

本轮是源码与产物 Delta，不复用旧 build 截图冒充 build 21 运行证据。

### R3. 独立发布质量 Gate

- 长期低能耗声明仍需 30 分钟 Energy Log 或更长 dogfood；现有 adaptive polling 与锁屏短样本只支持机制已生效。
- Medium/Large Widget 可保留为用户明确要求的可选尺寸，但“全尺寸完成”仍需 Gate W；首发核心仍是 Small Quota 与 Small Pinned。
- 对外销售需 Developer ID、notarization、购买/恢复、更新和支持流程。

这些项目不应重新包装为 build 21 的源码回归。

## 剩余非产品阻断项

`PRD_V5_FINAL.md` 内容已同步到 V6/build 21，先前“状态漂移”已关闭。仓库内仍同时存在正式根 `WorkPulse.xcodeproj` build 21 与 `Xcode/WorkPulse.xcodeproj` build 19 遗留副本。README 已以根项目和 `project.yml` 为构建入口，但人工误开旧副本的风险仍在。

**判定：P2 repository hygiene，非运行 blocker。** 最小收口是删除、归档或显著标记旧 project 为 legacy，并让正式构建入口保持唯一。

## 最终分层放行

| 范围 | 判定 | 剩余条件 |
|---|---|---|
| build 21 源码核心 | **Go** | 两项隐私 P2 已关闭；未发现 P0/P1 |
| 当前 Mac dogfood | **Go** | 已安装产物与冻结 ZIP 同源 |
| 本机个人版完整闭环 | **Conditional Go** | 通知真实 click/open + 同 build GUI/AX smoke |
| 全尺寸 Widget | **Conditional Go** | Medium/Large Gate W |
| 长期低能耗声明 | **Pending** | Energy Log / 长时 dogfood |
| 对外一次买断 | **No-Go** | Developer ID/notarization/购买恢复/更新/支持 |

## 最终质疑

build 21 已把 build 20 最后两项可直接修复的隐私防御缺口关闭。当前没有证据支持继续开发新的修复型功能，也没有证据支持把两项人工 Gate 写成已通过。最短完成路径是解锁后只做通知点击与 GUI/Accessibility 两组运行验收；通过后即可把“本机个人版完整闭环”从 Conditional Go 升为 Go。
