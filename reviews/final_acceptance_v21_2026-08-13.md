# WorkPulse build 21 最终本机验收

> 冻结时间：2026-08-13 07:30 CEST  
> 版本：0.3.1 (21)  
> 结论：本机 dogfood **Go**；个人版完整验收 **Conditional Go**；对外买断 **No-Go**

## 冻结产物

- 归档：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`
- SHA-256：`a427ed893527f54c8ba4057a1de842e8e45dc1269465c48fada3a6c848ca0f2c`
- 安装路径：`~/Applications/WorkPulse.app`
- Apple Development Team：`<APPLE_TEAM_ID>`
- Host 与 Widget：build 21，Universal Binary，同 TeamIdentifier，同 App Group，严格签名 Pass。
- 安装后：唯一 Host 进程，Widget Extension 嵌入与 runtime 验收 Pass，源码无晚于冻结归档的文件。

## 验收结果

- SwiftPM 无警告编译：Pass。
- `WorkPulseCoreVerify`：253 checks Pass。
- Widget typecheck：Pass。
- System surface contract：Pass。
- Xcode Release build + embed + codesign：Pass。
- build 20 已完成 after-copy 故障注入并验证自动回滚；build 21 沿用同一未变更安装器。
- 实时 App Group snapshot：schema 5、2 个 quota bucket、generic 任务计数、不写入未连接 Needs You。
- 锁屏稳定性：20 秒 revision 不变，CPU 样本 0.0%，任务监测退避至 120 秒。

## build 21 相对 build 20 的收口

1. 旧任务通知的 privacy migration 只在 delivered 和 pending 两个清理回调完成后写入标记。
2. 宿主启动从磁盘读取历史任务结果后，会立即重新执行 `Privacy Mode || !showTaskNamesInNotch` 不变式并擦除任务名。
3. 安装运行后 migration 值为 21，Privacy Mode 为开，任务名显示未授权，本机历史任务名缓存不存在。

## 剩余两项解锁后手工 Gate

1. 点击一条真实 task-terminal macOS 通知，确认 `request/action/route/result/openedAt` 回执与同一任务结果顶部 Expanded。
2. 在同一 build 21 上采集 Control Center、Resident、Expanded 的 GUI/Accessibility 证据，并确认键盘、VoiceOver、Switch Control 交互期间不自动收回。

Mac 当前锁屏，因此这两项未写成已通过。

## 对外发布边界

对外一次买断仍为 **No-Go**：Personal Team 开发签名不是客户分发身份，还需 Developer ID、notarization、购买/恢复、更新与支持机制。
