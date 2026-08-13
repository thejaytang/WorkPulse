# WorkPulse build 22 本机验收

> 冻结时间：2026-08-13 07:39 CEST  
> 版本：0.3.1 (22)  
> 结论：本机 dogfood **Go**；个人版完整验收 **Conditional Go**；对外买断 **No-Go**

## 冻结产物

- 归档：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`b40efb1829f859243d03f9e5fb217438cb6d3e6c225bdafdb09d9356d47c0ab3`
- 安装：`~/Applications/WorkPulse.app`
- Apple Development Team：`<APPLE_TEAM_ID>`
- Host/Widget：build 22，Universal Binary，同 TeamIdentifier/App Group，严格签名与 Widget runtime Pass。
- 源码无晚于冻结归档的文件。

## 自动验收

- SwiftPM 无警告编译：Pass。
- `WorkPulseCoreVerify`：253 checks Pass。
- Widget typecheck：Pass。
- System surface verifier：Pass。
- Xcode Release build/embed/codesign：Pass。
- 签名安装、单 Host 进程、Widget 系统注册与 runtime：Pass。
- 安装故障注入与自动回滚：已在未变更的安装器上完成。
- 任务通知 generic、启动隐私清洗、通知迁移 callback 顺序：Pass。
- 仓库仅有一个正式 `WorkPulse.xcodeproj`：Pass。旧 build 19 重复工程已移至可恢复的 `/tmp/WorkPulse-obsolete-build19.xcodeproj`。
- 控制中心从七组收敛为五组：顶部显示、隐私、外观与启动、固定入口、系统通知。低额度阈值并入顶部显示，删除无操作价值的“本机开发版/未来买断”卡片。

## 待解锁手工 Gate

1. 点击真实 task-terminal macOS 通知，验证 `request/action/route/result/openedAt` 回执和同一任务结果 Expanded。
2. 在同一 build 22 上验证五组控制中心、Resident、Alert、Expanded、键盘、VoiceOver 和 Switch Control。

Mac 当前锁屏，这两项仍不得写成已完成。

## 发布边界

- 本机个人 dogfood：**Go**。
- 个人版完整闭环：**Conditional Go**，待上述两项解锁 Gate。
- 对外一次买断：**No-Go**，尚需 Developer ID、notarization、购买/恢复、更新和支持链。
