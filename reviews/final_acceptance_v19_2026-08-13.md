# WorkPulse build 19 最终本机验收

日期：2026-08-13（Europe/Oslo）

## 放行结论

- 本机个人 dogfood：**Go with constraints**。
- 顶部 Resident / Alert / Expanded：**Go**。它是受控 `NSPanel`，不是 Apple 提供给第三方的系统 Dynamic Island。
- macOS Widget：**Go**。签名、App Group、唯一 PlugInKit 注册和当前 WidgetKit 运行渲染均通过；首发产品仍以 Small Quota 与 Small Pinned 为主。
- macOS 通知 transport：**Go with system constraints**。授权、Alert、Notification Center、Sound 和 delivered 已验证；当前自动化环境无法点击系统通知中心，因此“点击通知回到具体任务”的真实 GUI 闭环仍是手工验收项。
- 对外买断分发：**No-Go**。当前是 Personal Team 的 Apple Development 构建，仍需 Developer ID、notarization、正式更新与购买恢复方案。

## build 19 完成的关键修复

1. Resident 永远以额度为主：`窗口身份 + 剩余额度 + 重置时间`；运行任务只显示次级 `● N`，不再遮蔽核心信息。
2. Expanded 同时展示全部额度窗口和具体任务。Privacy Mode 开启时强制隐藏任务名，也不再提供临时揭示旁路。
3. 任务结束会区分完成、取消、失败和中止；多个同轮终态不再只处理第一个。
4. 任务终态通知携带安全的本机任务 ID 与 outcome；点击设计回流该任务结果，而不是泛化的额度或 Needs You 表面。
5. 用户不活跃或顶部层不可达时优先使用系统通知；顶部展示失败时也会 fallback 到通知。
6. 任务生命周期读取加入缓存和增量尾部扫描，避免每 5 秒重复扫描大型 rollout。
7. Widget freshness 同时检查快照过期和额度 reset 边界；过期后不再突出旧百分比。
8. Widget timeline 对 freshness/reset 重复日期去重。
9. 修复主题渲染错位：深色偏好会把明确的 dark-surface 值传给 `containerBackground`。真实 WidgetKit 浅色桌面环境下已显示深色背景和可读白字，不再出现白字浅底。
10. 安装器若无法注销旧 Widget 会直接失败，不再静默继续并制造重复注册。

## 当前真实运行画面

- 顶部 Resident：`7 天 · 89% 剩余｜周四 05:34 重置 · ● 2`。
- 点击展开：显示两组额度以及任务 A、任务 B；隐私模式下未出现任务真实标题。
- Small Pinned Widget：深色背景，清晰显示 `固定入口 / 每日例程 / 点按打开保存的对话`。
- 物理刘海保持黑色融合外壳；Light/Dark/System 只作用于内容表面，不把刘海外壳改白。

## 验证证据

- 安装版本：`0.3.1 (19)`。
- 安装路径：`~/Applications/WorkPulse.app`。
- ZIP：`native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip`。
- SHA-256：`c39ceb015978dd9d57fa56632b8c85ccc850baf5b678bbf2ccb6f0db5bd39a71`。
- Apple Development Team：`<APPLE_TEAM_ID>`；Authority 链完整。
- Host + Widget：`codesign --deep --strict` 通过。
- PlugInKit：唯一注册指向 `~/Applications/WorkPulse.app/Contents/PlugIns/WorkPulseWidget.appex`。
- `WorkPulseCoreVerify`：250 checks 通过。
- `verify_system_surfaces.sh`：通过。
- `typecheck_widget.sh`：通过。
- `verify_widget_runtime.sh`：通过。
- 实时探针：2 个 quota bucket、2 个活动任务；数值与任务名脱敏。
- 任务读取 30 次：平均 15.52 ms，暖缓存 p95 4.75 ms；第一次冷扫描拉高平均值。
- 安装应用 30 秒 CPU 采样：CPU time `3.20s → 4.43s`，约单核 4.1%；RSS `262432 KB → 248736 KB`。
- 通知 QA：authorization/alert/notification-center/sound 均为 enabled，delivered request 可见。
- 最新可恢复备份：`/tmp/WorkPulse-before-signed-20260813-065008.app`。

## 仍然明确不承诺

- WidgetKit 是快照与 timeline 模型，不保证秒级实时刷新。
- Focus、系统通知样式与锁屏策略决定横幅、声音和呈现时间。
- Gmail 目前是用户手动固定的 HTTPS 对话入口，不读取 Gmail 邮箱状态。
- Needs You、Scheduled 和 Daily Brief 仍没有可信 production adapter，不进入首发承诺。
- Medium 与 Large 已有基于真实受支持数据的实现，但首发信息架构仍应优先 Small Quota + Small Pinned。
- 30 秒 CPU 采样不等于完整 Energy Log；若要面向外部用户发布，仍需长时能耗、VoiceOver、大字号、全屏、锁屏与通知点击矩阵。
