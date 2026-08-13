# WorkPulse build 18 产品完成度 Delta

日期：2026-08-13（Europe/Oslo）  
证据范围：仅审查当前 build 18 源码与 `reviews/final_acceptance_v18_2026-08-13.md`。本次未重新操作已安装应用，因此不把未在该验收文档中出现的运行结果视为已验证。

## 结论

- **本机个人使用**：build 18 已是 **Release Candidate / dogfood 可用**，但还不能称为“完全完成”。Widget、固定对话、额度 Resident、任务身份 Expanded、主题、外接屏定位和通知 transport 已过本机验收；仍有 2 个必须本轮修复的交互闭环 P0，以及 1 个必须补证的通知 P0 Gate。
- **对外一次买断**：仍为 **No-Go**。这不是把本机版再打一个 ZIP 就能完成；当前 `Personal Team`、`com.workpulse.prototype`、无 notarization、无购买/恢复购买/授权、无正式更新通道。必须先决定分发架构。
- 产品命名应继续是“Codex 本地伴生应用”，而不是“官方 Dynamic Island 应用”或“ChatGPT 实时额度官方客户端”。顶部岛是自定义 `NSPanel`，Widget 是最近快照。

## 已完成，不应重复扩范围

| 原始范围 | build 18 状态 | 产品判断 |
|---|---|---|
| Small / Medium / Large Widget | 四种 Widget 均在 Gallery 暴露；Small Quota、Small Pinned 常驻，Medium/Large 已完成临时真机验收后移除 | 本机范围完成；移除桌面实例不等于删除组件能力 |
| 固定某个对话 | Small Pinned 已打开指定 Gmail 每日审查对话 | 单一 Manual Pin 完成，不承诺读取 Gmail 状态 |
| 刘海 Resident / Alert / Expanded | 额度常驻优先，Alert 一次性出现，Expanded 展示额度窗口与运行任务 | 主信息架构完成 |
| 运行任务具体身份 | Privacy 默认显示任务 A/B；Expanded 可显示具体名称与 elapsed time | 能力存在，但隐私语义仍有 P0 冲突 |
| 菜单栏控制中心 | 无独立主窗口，设置、诊断和固定入口集中在 MenuBarExtra | 符合“伴生表面，不要单独页面” |
| 主题 / 强调色 | Light / Dark / System 与强调色已接入；物理刘海强制深色融合 | 功能完成，完整组合的视觉/无障碍补证列为 P1 |
| 通知 | 授权、Alert、通知中心、声音、delivered 已验证 | transport 完成；生产形态的点击闭环未完成 |

## 本轮可直接实现的 P0

### P0-1 Privacy Mode 必须真正“强制隐藏”

**现状冲突**：控制中心文案写着“隐私模式已强制隐藏任务名称”，但 Expanded 在 Privacy Mode 下仍提供“显示名称 10 秒”。临时显示状态只靠 10 秒计时器恢复；收起 Expanded、锁屏或 session inactive 时没有同步取消该状态。

**用户风险**：用户在投屏或他人可见的环境开启 Privacy Mode，会合理预期任何操作都不会泄露任务名；当前行为违反这个承诺。

**本轮调整**：

1. Privacy Mode 开启时删除“显示名称 10 秒”，任务名始终使用 A/B。
2. 真实名称只能在关闭 Privacy Mode 后，再通过独立的“显示任务名称”选择显式开启。
3. 若保留任何临时显示机制，收起、锁屏、session inactive、切回 Privacy Mode 都必须立即清零，不等待倒计时。

**Gate**：Privacy Mode 下源码不存在可达的名称 reveal action；锁屏/收起/重启后 Expanded、控制中心、Widget 和通知均不出现真实任务名。

### P0-2 任务结束提醒必须回到“该任务”，不能回到无关 Needs You / 额度

**现状冲突**：任务完成/失败的顶部 Alert 没有自己的 `expandedContent`，点击后会展开常驻的额度内容；任务系统通知则固定 deep-link 到 `workpulse://inbox`，在尚无可信 Needs You adapter 时会显示“尚未连接可信事件来源”。通知文案却写“打开 WorkPulse 查看当前状态”。

**用户风险**：最需要处理的时刻，提醒丢失了任务身份和结果，点击后反而进入无关表面，闭环失败。

**本轮调整**：

1. 为 terminal task 建立专用顶部 Expanded：隐私安全名称、完成/失败/取消/中止、运行时长、观测时间。
2. 增加任务专用本机 route，例如 `workpulse://task/<id>`；顶部 Alert 点击和系统通知点击都进入同一个任务结果表面。
3. 若当前没有可靠的 Codex “打开该任务”接口，明确显示“仅本机观测，暂不支持直达任务”，不要伪装成可打开，也不要回流 Needs You。

**Gate**：四种 terminal outcome 均验证 Alert 点击与通知点击；目标内容、隐私处理和状态一致，不出现 generic inbox 或额度 Expanded。

### P0-3 补齐生产形态通知的可审计证据

**现状**：final acceptance 证明的是手动“本机预览”通知进入 delivered；它没有证明 quota threshold 与 task terminal 两种真实 category 的内容、去重和点击 route。

**本轮调整**：增加明确标为 QA 的确定性触发入口，分别走生产同构的 `WORKPULSE_QUOTA` 和 `WORKPULSE_TASK_TERMINAL` category，不伪造真实业务事件。

**Gate**：每类至少留存一次 `scheduled -> delivered -> clicked -> correct surface` 证据；验证同一周期 quota 不重复、同一 terminal task 不重复。Focus 阻止横幅不判失败，但 delivered 与点击 route 必须可证。

## 本轮可直接实现的 P1

1. **固定链接收口**：当前校验只要求任意 HTTPS host。若产品文案继续称“ChatGPT 对话”，应限制到明确允许的 ChatGPT/Codex host；否则改名为“HTTPS 固定入口”并显示外部域名。验收：非允许域不会在无提示下打开。
2. **登录启动补证**：源码已有 `SMAppService.mainApp`，但 v18 验收没有注销/重新登录后的自动启动证据。验收：冷登录后菜单栏、Resident、5 秒任务轮询、240 秒额度刷新均恢复，失败时控制中心显示可操作原因。
3. **主题与强调色矩阵**：补 Light/Dark/System × 关键强调色 × 物理刘海/无刘海的对比度、键盘焦点和 Reduce Motion 验收。物理刘海仍保持深色，不要求随主题变白。
4. **单一 Pin 的边界写清**：当前所有 Pinned Widget 实例共享一个 Manual Pin。若用户只要“每日 Gmail 审查”一个常驻入口，保持现状；若要多个 Widget 分别固定不同对话，再进入 per-widget configuration，不能把它描述成当前已完成。
5. **敏感本地配置说明**：固定对话 URL 和标题存于本机 preferences。控制中心应说明保存位置/用途，并提供一键清除；无需为本机个人版强行增加账号系统。

## 原始愿景中仍需用户决策的延期项

- `Scheduled`、`Daily Brief`、`Needs You` 的生产状态目前没有可信 adapter。它们不是 build 18 的隐藏“半完成功能”，而是正式延期项。
- 若 v1 定义为“额度 + 运行任务 + 一个固定对话入口”，可以明确排除上述 adapter 后发布本机版。
- 若用户坚持“完全完成”必须包含 Scheduled / Daily Brief，则当前产品不能宣称完成，但这不是本轮 P0：需要先取得稳定数据源、字段契约、freshness、deep link 与错误降级，再另立版本。

## 对外一次买断：独立 No-Go 清单

这些项目**不阻止本机个人使用**，但任何一项未完成都不能出售：

### 商业化 P0

1. **先选分发路线**：推荐 Developer ID 直接分发。Host 当前需要读取本机 Codex state / rollout 文件且没有 App Sandbox；改走 Mac App Store 会触发 sandbox、用户授权目录和安全作用域书签的架构重做。
2. **正式身份与供应链**：将 prototype bundle ID / Personal Team 切为稳定生产身份，完成 Developer ID Application 签名、hardened Release、notarization、stapling，并在一台无开发环境的干净 Mac 验证 Host + Widget 安装、升级和卸载。
3. **买断闭环**：当前没有 StoreKit 或直接授权实现。必须完成购买、激活、恢复购买、多设备规则、离线宽限、退款/撤销状态和授权失败降级；不得只保留“正式发布计划采用一次买断”的静态文案。
4. **更新与回滚**：提供签名更新通道、版本迁移、Widget extension 替换和失败回滚；当前本机安装脚本不能等同消费者更新方案。
5. **隐私与支持**：对读取哪些 Codex 本机元数据、保存哪些 preferences、是否出站网络作明确声明，并具备崩溃/诊断导出、支持入口和删除本地数据路径。

### 商业化 P1

- Apple Silicon / Intel（若承诺）与多个 macOS 版本兼容矩阵。
- 许可证服务器不可用、通知拒绝、Widget 未出现、Codex 数据结构变化时的客服可恢复流程。
- 定价、试用与退款策略；在购买基础设施确定前，不继续扩展 Daily Brief 等新功能。

## 下一轮顺序与放行门槛

1. 先修 P0-1 Privacy，不再让承诺与行为矛盾。
2. 再修 P0-2 task terminal 专用 Expanded / route。
3. 用 P0-3 同构 QA 完成两类通知端到端证据。
4. 完成登录启动与链接策略 P1；主题矩阵可并行补证。
5. 达成以上条件后，可称“WorkPulse 本机个人版 1.0 功能完成”。在商业化 P0 全部完成前，仍只能称“本机签名 dogfood build”，不可称“可购买正式版”。
