# WorkPulse build 18 技术完成度 Delta

> 审查时间：2026-08-13（Europe/Oslo）  
> 基线：`technical_completion_delta_v17.md`  
> 范围：只复核 v17 新发现的 Widget 写放大、升级注册顺序，以及 Small Pinned 真实闭环；未修改源码

## 1. 结论

build 18 已关闭 v17 新增的主要 P1：

1. **Widget snapshot/reload 写放大已关闭。** taskCount 不变的 15 秒实测中，revision 保持 `3422 → 3422`，`generatedAt` 同样未变化。
2. **升级脚本顺序已修正。** 旧 `.appex` 在应用 bundle 替换前先执行 `pluginkit -r` 和 LaunchServices unregister，再停止旧 Widget 进程、移动旧 App、安装并登记新版本。
3. **Small Pinned 已形成真实桌面闭环。** 已从真实 Widget Gallery 添加到桌面；点击后打开正确的 ChatGPT `Gmail 每日审查任务`，而不是示例页、WorkPulse 控制中心或错误对话。
4. **build 18 可追溯。** 已安装 Host/Widget 与 ZIP 内二进制 byte-for-byte identical，strict `codesign` 通过，唯一 PlugInKit 注册和单实例运行保持正常。

本机 WorkPulse、Small Quota、Small Pinned、顶部岛和通知 transport 可继续 **Go**。对外分发、生产 Needs You/Scheduled/Gmail 状态读取仍是 **No-Go**。

## 2. build 18 身份

| 项目 | 结果 |
|---|---|
| 安装版本 | `0.3.1 (18)` |
| 安装路径 | `~/Applications/WorkPulse.app` |
| ZIP | `native/WorkPulseNative/build/full-product/WorkPulse-full-product.zip` |
| ZIP SHA-256 | `f02fdc45a1f2834eddea51a8427f3e5a073e2a065b3141456b3fd9c1fa3929e5` |
| Team / App Group | `<APPLE_TEAM_ID>` / `<APPLE_TEAM_ID>.com.workpulse.shared` |
| ZIP 与 installed Host | identical |
| ZIP 与 installed Widget | identical |
| Host + nested Widget strict codesign | Pass |
| PlugInKit | 1 条，仅 installed path |
| 运行实例 | 1 Host + 1 Widget Extension |

## 3. v17 P1：Widget 写放大

### 3.1 修复方式

`refreshRunningTasks()` 不再用完整 `CodexRunningTaskSnapshot` equality 决定是否发布 Widget。它现在只在 Widget 可见语义变化时发布：

- task count 改变；或
- task source connection state 从非 live 变为 live；或
- source 转为 unavailable。

rollout 文件 `mtime` 造成的 `lastActivityAt` 变化只更新 Host 顶部任务状态，不再消耗 App Group 写入与 `WidgetCenter.reloadAllTimelines()` 预算。

任务轮询也从 2 秒调整为 5 秒，进一步降低 SQLite/rollout 读取频率。

### 3.2 实测

同一个 production App Group snapshot，taskCount 始终为 2：

```text
t0   revision=3422  generatedAt=2026-08-13T04:08:38Z  taskCount=2
t15  revision=3422  generatedAt=2026-08-13T04:08:38Z  taskCount=2
```

判定：**Pass。** v17 的“10 秒 revision 增加 4 次”不再复现。

### 3.3 仍需长期观察

- 本轮只证明稳定 taskCount 下 15 秒不写，不等于完成 Energy Log。
- quota 每 4 分钟刷新、theme/routine 用户修改、fresh/unavailable transition 仍应正常写入。
- 应在 30 分钟、多任务频繁启动/终止、睡眠唤醒和 Codex source 断连场景确认没有漏刷新。

## 4. v17 P1：升级时旧 Widget 被重新拉起

当前 `install_signed_product.sh` 顺序为：

1. 验证新 archive 与 Team 签名；
2. 停止旧 Host；
3. 对旧 Widget bundle 执行 `pluginkit -r`；
4. 对旧 Host 执行 LaunchServices unregister；
5. 停止仍存活的旧 Widget Extension；
6. 移动旧 App 到可恢复 `/tmp` backup；
7. 复制新 App；
8. `lsregister -f` + `pluginkit -a` 登记新版本；
9. 普通 `open` 启动，并断言 canonical Host 数量为 1。

关键顺序证据：`pluginkit -r` 位于旧 App `mv` 与新 App `ditto` 之前。

安装后的运行证据：

- PlugInKit 仅 1 条 `com.workpulse.prototype.widgets`；
- 路径为 `~/Applications/WorkPulse.app/.../WorkPulseWidget.appex`；
- 没有 `/tmp` 或 DerivedData 历史注册；
- 1 个 Host、1 个当前 Widget Extension。

判定：**Pass。** 升级过程中旧 extension 重新竞争同 bundle ID 的问题已关闭。

仍有边界：脚本使用 `pluginkit -r ... || true`，注销失败会被忽略。当前 post-install 唯一注册 Gate 能发现结果异常，但更稳妥的正式安装器应在旧记录仍存在时明确失败并恢复旧版本。

## 5. Small Pinned 真实闭环

### 5.1 已验证

- 真实 macOS Widget Gallery 已添加一个 Small Pinned 桌面实例。
- 用户保存的是人工指定的 HTTPS ChatGPT 对话入口。
- 点击后 Chrome 当前窗口为：

```text
Title: Gmail 每日审查任务
URL: https://chatgpt.com/c/<REDACTED_CONVERSATION_ID>
```

- 页面可访问性树同时确认标题 `Gmail 每日审查任务 · 工作`，并显示该任务的 Scheduled 区域。

判定：**Pass。** Small Pinned 已从“代码支持的快捷入口”升级为本机真实桌面 Job To Be Done：一次点击回到每日 Gmail 审查对话。

### 5.2 必须保留的产品边界

Small Pinned 只证明入口导航，不证明 WorkPulse：

- 读取 Gmail 内容；
- 知道 Scheduled task 是否执行成功；
- 知道 last run / next run / attention；
- 自动生成 Daily Brief；
- 验证浏览器最终页面已完成特定任务动作。

因此 Widget 文案仍应是“固定入口 / 点按打开”，不能升级成“Gmail 已审查”“日报完成”或“下次 10:00”状态卡。

隐私状态下 App Group 当前发布 generic `routineTitle=每日例程`，没有将具体 Gmail 标题写入系统 Widget 快照；这与默认 Privacy Mode 一致。

## 6. v17 其他结论是否变化

| 范围 | build 18 Delta |
|---|---|
| quota-first Resident | 无回归，**Go** |
| Small Quota Gallery/桌面/点击 | 无回归，**Go** |
| Small Pinned Gallery/桌面/点击 | 从 Conditional 升为 **Go** |
| Medium / Large Widget | 技术可发现；逐尺寸 Light/Dark、大字号、点击与长期价值仍未完整验证 |
| Widget freshness | future stale entry 与“已同步/需更新”仍在；系统调度仍受 WidgetKit 控制 |
| 物理刘海深色 | 无回归；仍是自绘 `NSPanel`，不是系统 Dynamic Island API |
| 系统通知 | authorized + delivered 已验证；点击回流、Focus/锁屏完整矩阵仍未补齐 |
| Codex quota/task reader | 当前 live probe 可用；仍是依赖内部 method/schema 的 Technical Preview |
| Personal Team 本机使用 | **Go** |
| 外部免费/收费分发 | **No-Go**；无 Developer ID/notarization/干净机 Gate |

## 7. 仍未关闭的真实边界

### 本机质量与长期稳定性

1. 30 分钟以上 Energy Log 与大 rollout 文件压力测试尚未完成。
2. clamshell、全屏、Stage Manager、菜单栏自动隐藏和显示器热插拔矩阵仍不完整。
3. 通知点击回流、Focus、锁屏、Alert off、Sound off 仍缺完整 E2E。
4. Medium / Large 的产品价值和逐尺寸 QA 尚未证明，建议不把“存在四种 Widget”当成功指标。
5. 更新脚本的 `pluginkit -r` 失败被容忍，正式分发安装器需更强 rollback Gate。

### 数据能力

1. `account/rateLimits/read` 没有 WorkPulse 可控制的公开长期兼容契约。
2. task reader 仍依赖 `state_5.sqlite`、`threads` schema 和 rollout event types。
3. production Needs You adapter 不存在；approval/input 仍只有 fixture。
4. Gmail/Scheduled/Daily Brief 没有 production status adapter；当前只是固定入口。

### 外部分发

1. 当前为 Apple Development Personal Team，含 `get-task-allow=true`。
2. 无 Developer ID Application、secure timestamp、notarization、staple。
3. `spctl`/Gatekeeper 外部分发 Gate 未通过。
4. 无干净 Mac 安装、升级、登录启动、Widget Gallery、卸载验证。
5. 若收费，尚未选择并实现 Mac App Store 或 Developer ID 直销的 purchase/license/update/restore 闭环。

## 8. 最终放行

| 范围 | 判定 |
|---|---|
| 当前 Mac WorkPulse 伴生应用 | **Go** |
| quota-first 顶部岛 | **Go** |
| Small Quota | **Go** |
| Small Pinned → Gmail 每日审查任务 | **Go** |
| Widget snapshot 写放大修复 | **Pass** |
| build 18 升级注册流程 | **Pass** |
| Medium / Large | **Conditional Go** |
| 通知 transport | **Go with system constraints** |
| Codex quota / task status | **Technical Preview** |
| Gmail/Scheduled 状态读取 | **No-Go / 未实现** |
| 外部分发 | **No-Go** |
