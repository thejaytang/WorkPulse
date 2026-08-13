# WorkPulse build 15 验收记录

日期：2026-08-13（Europe/Oslo）

## 本轮结论

build 15 已通过本机开发验收并安装到 `~/Applications/WorkPulse.app`。物理刘海的 Resident 与 Expanded 在 Light、Dark 和 Follow System 模式下始终使用深色融合表面；主题选择仅影响控制中心、桌面组件和无物理刘海屏幕的顶部胶囊。

当前分类仍是 **Local Developer Preview**，不是可对外分发的完整商品版。

## 已通过

- SwiftPM 全量构建通过。
- `WorkPulseCoreVerify` 242 checks 通过。
- 系统表面静态验证通过。
- Xcode Release 构建通过，Host 和 Widget Extension 均由 Apple Development Personal Team `<APPLE_TEAM_ID>` 签名。
- Host 与 Widget Extension 的 `codesign --deep --strict` 验证通过。
- PlugInKit 仅登记一份已安装 WorkPulse Widget。
- 安装后宿主版本号为 15，并且只有一个 Host 实例。
- 浅色主题实机检查：控制中心为浅色，物理刘海 Resident/Expanded 保持深色。
- 深色主题实机检查：控制中心与刘海层级、对比度正常。
- 隐私模式下 Resident 不显示任务名，使用锁图标并明示“隐私模式”。
- 所有 `WORKPULSE_QA_` 模拟状态均被禁止写入系统 Widget 共享容器。

## 已交付产物

- 已安装 App：`~/Applications/WorkPulse.app`
- 签名 ZIP：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`b1f1e389faa5726bff76b1f1e65d6fb6743c3b0d2018ddd9e74943d6a060f497`
- 可恢复上一版：`/tmp/WorkPulse-before-signed-20260813-011210.app`

## 尚未通过的最终 Gate

1. 需要用户在 macOS 组件库实际搜索 WorkPulse，添加 Widget，并验证刷新与点击回流。当前自动化工具无法操作 Finder 桌面右键菜单或 Control Center 窗口。
2. 需要用户在 WorkPulse 控制中心点击“允许通知”，并在 macOS 授权对话框选择允许，才能执行真实横幅、声音、去重和点击回流验收。当前系统状态为 `notDetermined`。
3. 对外分发需要 Developer ID Application 签名与 notarization；Personal Team 构建只用于本机开发验证。

## 验收决策

- 本机 dogfood：Go。
- 用户 Widget/Notification 完整内测：Conditional No-Go，等待上述两个系统界面手动 Gate。
- 外部付费分发：No-Go，尚未完成 Developer ID/notarization 与购买流程。
