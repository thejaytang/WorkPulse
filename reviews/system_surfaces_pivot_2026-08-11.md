# WorkPulse 系统表面重构记录

日期：2026-08-11

## 产品边界

WorkPulse 不再提供独立 Dashboard。正式交互面只包括：

1. macOS 桌面 Widget：Small Quota、Small Pinned、Medium Now & Next、Large Daily Brief。
2. 顶部状态层：常驻状态胶囊，以及自动消失的一次性提醒。
3. macOS 系统通知：由用户显式授权，支持查看、稍后提醒和 deep link 回流。
4. 菜单栏弹层：只承担刷新、固定链接、Privacy、外观、顶部状态和通知设置。

## 已删除

- 独立 `Window` scene。
- Dashboard、Inbox/Detail 页面及其残留源码。
- Dock 常驻图标，宿主现在使用 `LSUIElement=true`。
- “实验性刘海状态层（占位）”开关。

## 已实现

- `WorkPulse.xcodeproj` 包含 macOS App target 和嵌入式 Widget Extension target。
- App 与 Widget 使用一致的 App Group entitlement。
- WidgetBundle 暴露四个桌面组件。
- `NSPanel` 顶部状态层支持 resident 和 alert 两种模式；alert 结束后恢复 resident。
- 无刘海屏幕使用相同顶部胶囊作为降级形态。
- `UNUserNotificationCenterDelegate`、授权状态、通知 action、稍后一小时和 deep link 已接入。
- 菜单栏配置区使用可滚动布局，避免小屏高度溢出。

## 已验证

- SwiftPM 全量 build：通过。
- WorkPulseCore：193 checks 通过。
- System-surface source gate：全部通过。
- Widget target、嵌入关系、extension point、App Group plist/entitlement：静态验证通过。
- Menu-bar-only 本地 ZIP：独立解包后 strict ad-hoc codesign 通过；SHA-256 为 `520f14ab240c6955f1978d9acb8f3251ae2a20ae24e690b949b10d2710a7d5ef`。

## 尚未通过的最终门槛

- 本机当前没有完整 Xcode，不能执行真正的 Widget `.appex` 构建、签名和系统组件库安装。
- Mac 当前锁屏，不能完成最新菜单栏、顶部状态层、通知授权、浅深色和 VoiceOver 的 GUI 运行验收。
- 当前 ZIP 是菜单栏宿主验证包，不包含 `.appex`，不能作为完整产品发布包。

因此当前结论是：系统表面架构与源码已完成重构；完整用户级安装包仍为 No-Go，直到完成 Xcode 签名构建和解锁后的原生 E2E。
