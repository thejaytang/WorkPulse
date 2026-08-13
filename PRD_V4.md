# WorkPulse for macOS 产品需求文档 V4

> 日期：2026-08-11  
> 阶段：MenuBar-only local developer MVP + Phase 0 **Technical Preview**  
> 负责人：产品经理（综合 UI/UX、Apple 技术、用户研究第五轮审查）

## 1. 产品结论

WorkPulse 不是 ChatGPT 的替代客户端，而是 macOS 上的 **AI 工作连续性层**：用户离开 ChatGPT / Codex 后，仍能低成本知道“什么正在进行、什么需要我、还能用多少、如何安全返回”。

V4 将产品拆为两层：

1. **稳定原生壳**：主窗口、Menu Bar、浅色 / 深色、Privacy Mode、手动固定入口、WorkPulse 自有 deep link、本地脱敏快照、WidgetKit 与通知骨架。
2. **实验数据源**：Codex `app-server` 事件与 quota、精确上下文返回、Scheduled 健康状态、刘海浮层。

稳定壳可以独立成为本地伴侣应用，不要求先上架 App Store。实验能力只有通过真实性 Gate 后才能进入 Pilot。

## 2. V4 相比 V3 的关键变化

- “每日 Gmail 审查”默认是 **Manual Pin**，不再伪装成已连接的 Scheduled 自动化。
- 只有 `verifiedAdapter` 才能展示 last run、next run、attention 和 freshness。
- Widget 与系统通知在 P0 永远使用通用标题；应用内标题授权不得外溢。
- Privacy Mode 不只换标题，还泛化图标、单位、来源、CTA 和辅助功能摘要。
- “系统接受打开请求”不等于“精确返回成功”；精确返回必须被来源或受控测试确认。
- Codex quota 与 Scheduled routine 分开呈现，禁止合并成“今日总额度”。
- 刘海能力明确称为 **Notch Overlay**，本质是 `NSPanel` 浮层，不称 Apple Dynamic Island 或 Live Activity。
- 成功且无需动作的 Scheduled 运行保持安静；暂停、权限异常、重复失败才进入 Needs You。

## 3. 用户与核心任务

### 3.1 P0 用户

- 同时运行多个 Codex task / agent，需要离开窗口继续其他工作的人。
- 会错过 approval、needs input、重大 failure 或 quota block 的人。
- 有固定 ChatGPT routine，希望在桌面保留稳定入口的人。
- 经常外接显示器、屏幕共享或处理敏感项目的人。

### 3.2 核心 JTBD

1. 当 AI 工作需要我时，我能在不持续轮询的情况下及时知道。
2. 当我决定处理时，我能回到正确上下文，或明确知道只能安全降级。
3. 当我规划长任务时，我能看到有来源、有窗口、有 freshness 的 Codex quota。
4. 当我每天进入固定对话时，我能从桌面一键打开，而不会被误导为 WorkPulse 已同步 Gmail 或 Scheduled 状态。

## 4. 产品范围

### 4.1 P0

- SwiftUI 主窗口与 `MenuBarExtra`。
- Light / Dark / System 三档外观，用户可选并持久化。
- Privacy Mode 与应用内 item title opt-in。
- Manual Pinned Routine：用户保存名称和 HTTPS 目标地址。
- Small Quota Widget 和 Medium Now & Next Widget 的 Xcode target 规范与 snapshot contract。
- WorkPulse-owned deep link：`workpulse://inbox`、`workpulse://usage`、`workpulse://routine/{id}`。
- bounded JSONL framing、重连退避、capability gate。
- 本地通知的 generic copy 与单一主动表面 ownership。

### 4.2 条件性 P0 / Pilot

- Codex `app-server` approval、needs input、重大 failure、turn quota block。
- Codex rate-limit / usage snapshot。
- `verifiedExact` 的任务或审批返回。

前提：Gate A（可观察）、Gate B（可返回）、Gate C（版本兼容）全部通过。

### 4.3 P1

- Pinned Routine Widget。
- Daily Brief Large Widget。
- Notch Resident / Alert / Expanded overlay。
- verified connection detail、诊断页、外接显示器放置策略。

### 4.4 暂不承诺

- 自动枚举任意 ChatGPT Projects / Chats。
- 读取或复用 ChatGPT Gmail connector OAuth。
- 自动读取 Scheduled 列表、真实运行健康或邮件数量。
- 秒级 Widget 刷新。
- Focus 下保证通知必达。
- 任意 ChatGPT / Codex Desktop thread 的通用精确 deep link。
- Mac-only ActivityKit Dynamic Island。
- 自动识别全部屏幕共享场景。

## 5. 形态与职责

| 形态 | 生命周期 | 核心职责 | 主交互 | P0 隐私 |
|---|---|---|---|---|
| Small Widget | 长期被动 | Codex quota headroom、reset、freshness | 打开 Usage | 永远 generic |
| Medium Widget | 长期被动 | Now、Next、Needs You 摘要 | 当前项 / 下一项各自打开 | 永远 generic |
| Large Widget | 日次摘要 | Daily Brief，且每项可追溯 | 打开条目 | 永远 generic |
| Pinned Routine | 长期入口 | Manual 或 Verified routine | 打开入口 / 最新结果 | 默认 generic |
| Menu Bar | 长期常驻 | 全局状态、Needs You、source health | 打开 popover / settings | 可受控显示名称 |
| Notch Resident | 可选常驻 | 一项正在进行的低密度状态 | 展开详情 | 默认 generic |
| Notch Alert | 一次弹出 | approval / input / work-loss risk / quota block | 由事件类型生成“处理审批 / 补充输入 / 查看失败 / 查看额度”，或“稍后” | 默认 generic |
| Notch Expanded | 用户主动展开 | 解释状态、来源、freshness、fallback | 打开来源或详情 | 默认 generic |
| macOS Notification | 一次升级 | Overlay 不可达时的行动提醒 | 打开 WorkPulse / 稍后 | 永远 generic |

原则：Widget 提供环境感知；Menu Bar 提供可靠入口；Alert 只处理需要行动的事件；Notification 是 fallback，不与 Alert 同时重复提醒。

## 6. Source truth 与状态模型

### 6.1 Routine capability

| Capability | 可展示 | 禁止展示 | CTA |
|---|---|---|---|
| `manualPin` | 用户保存名称、URL、用户本地提醒 | 自动 last / next / completed / failed / 邮件数 | 打开固定入口 |
| `verifiedAdapter` | 来源明确提供的状态、时间、计数、freshness | 推断的健康、Gmail 内容 | 打开来源上下文 |
| `unavailable` | 最后可信值、断连时间、诊断说明 | 继续显示 fresh / healthy | 检查连接 |

### 6.2 Freshness

- `fresh`：刚刚更新。
- `cached`：显示上次已知状态与更新时间。
- `stale`：状态可能已过期，不触发主动提醒。
- `offline`：失去实时监控，不能写“任务失败”。
- `unsupported`：当前来源不支持，不显示 0 或空闲占位。
- `notLoaded`：尚未载入，不能写“正在运行”。
- `sourceConflict`：状态来源不一致，要求用户回到官方表面确认。

### 6.3 事件优先级

P0 主动事件：

1. Approval。
2. Needs input。
3. Work-loss-risk failure。
4. Turn quota block / paused。

被动事件：普通完成、recoverable failure、quota critical、source disconnected。普通成功不弹出主动提醒。

## 7. 关键交互

### 7.1 手动固定对话

1. 用户在主应用粘贴 HTTPS 对话地址。
2. WorkPulse 只校验 URL 结构并本地保存，不枚举账号内容。
3. 没有有效 URL 时，CTA 显示“请先设置 HTTPS 链接”并禁用。
4. 有效但未验证时，CTA 显示“交给系统打开”。
5. 系统接受打开请求后只写“已发送打开请求”，不写“已返回同一对话”。
6. 删除入口只删除 WorkPulse 本地记录，不删除 ChatGPT 内容或 Scheduled task。

### 7.2 Needs You

1. Adapter 提供 source-explicit 事件。
2. Normalizer 映射为 P0 event。
3. Delivery policy 选定唯一主动 owner。
4. Source 前台时不重复提醒；Overlay 可达时用 Alert，否则在授权后用通知。
5. Primary CTA 由 normalized event type 生成，并一步直达对应 fallback；不把 needs input、failure 或 quota block 统称为“审批”。
6. 打开失败在 1 秒内进入 WorkPulse detail fallback，事件不自动 acknowledged 或 resolved。

### 7.3 Notch 两类形态

- **Resident**：用户主动开启，长期显示一项运行状态；鼠标 / 键盘展开；全屏默认 suppress。
- **Alert**：由高价值事件触发，短时弹出；Primary CTA 由事件类型生成，并提供“稍后”；事件仍保留在 Needs You。
- **Expanded**：是前两者的详情态，不是第三类独立通知系统。

无刘海 Mac、外接显示器、clamshell、Stage Manager 和全屏属于真机 Gate D；Gate D 失败时关闭 overlay，不影响 Menu Bar / Widget / Notification。

## 8. UI/UX 规范

- 使用系统字体、SF Symbols、system material 和原生控件。
- 视觉语言：Graphite + Mint，Light 使用 Pearl surface，Dark 使用 Graphite surface。
- 最小 hit area 44pt；文字不低于 11pt，重要状态不低于 12pt。
- 状态不能只靠颜色，必须同时有文字和图标。
- 130% 字号下不得重叠；空间不足时改纵向或省略低优先级 detail。
- 装饰图标对 VoiceOver 隐藏；每组 metric 合并为完整短句。
- Menu Bar、Dashboard、Widget、Overlay 与通知必须消费同一 presentation contract。

## 9. 隐私合同

### 9.1 默认

- Widget 与 Notification 永远 generic。
- 应用内标题默认 generic；用户可对单项显式授权。
- Privacy Mode 开启后，主应用、Menu Bar、Overlay 立即泛化标题、图标、单位、来源和 CTA。

### 9.2 不采集

不采集 prompt、assistant response、thread title、项目名、文件路径、shell command、URL、Gmail sender / subject / snippet / body、附件名、Scheduled prompt、Google account identifier。

### 9.3 Pilot telemetry

只允许随机 participant / session / event / target ID、source class、normalized state、freshness、surface、时间戳、动作结果、错误枚举和 generic flag。所有未知字段默认拒绝导出。

## 10. 技术架构

```text
Codex App Server / Manual Link / Fixture
                 ↓
       Capability Probe + Adapter
                 ↓
  JSONL Framer → Normalizer → Event Store
                 ↓
      Delivery Policy + DeepLink Router
          ↓          ↓          ↓
      Menu Bar    Snapshot     Notification
                    ↓
                 WidgetKit
```

### 10.1 当前本机开发版

- `WorkPulseCore`：domain model、privacy-safe snapshot、event evidence ledger、单一 active owner、allowlisted telemetry、Safety Stop、delivery policy、deep-link router、JSONL framer、reconnect policy。
- `WorkPulseMenuBar`：主窗口、Menu Bar、Settings、主题、Privacy、Manual / Verified Demo、HTTPS target，以及不会主动投递的 deterministic Needs You Inbox / Detail fixture。
- `WorkPulseWidgetCompile`：Small Quota、Small Pinned Routine、Medium Now & Next、Large Daily Brief 四个 scaffold 已通过 SwiftPM 编译链接与独立 source-level type-check，但尚未成为 Xcode App Extension target 或安装进 Widget Gallery。
- `WorkPulseCoreVerify`：本地确定性验证，当前 189 checks。

### 10.2 数据与进程边界

- Host 独占写 SQLite WAL；Widget 不直接打开数据库。
- Host 生成最小 generic JSON snapshot，通过 App Group 原子替换。
- JSONL 单行最大 4 MiB、buffer 最大 8 MiB；超限清空并进入诊断。
- 重连使用 0.5 秒起步、30 秒封顶的指数退避；恢复后先 capability probe。
- `workpulse://` 仅处理只读导航，不能触发审批、删除或配置写入。

### 10.3 当前环境边界

当前 Mac 只有 Xcode Command Line Tools，没有完整 Xcode，因此可以编译 Swift Package 和 ad-hoc signed `.app` 壳，但不能完成 Widget Extension target、App Group entitlement、Developer ID 签名、公证和 Widget Gallery 安装验证。

## 11. 测试与验收

### 11.1 自动验证

- Quota clamp 与 freshness。
- Widget snapshot 永远 generic。
- Manual capability 不制造运行时间。
- Delivery surface ownership 与去重。
- `workpulse://` 路由白名单。
- JSONL partial / CRLF / oversize。
- Snapshot 原子 round-trip。
- Reconnect delay cap。

### 11.2 视觉与交互矩阵

- Light / Dark / System。
- Privacy on / off。
- Manual / Verified / Stale / Offline。
- URL missing / valid / open failed。
- Widget Small Quota / Small Pinned / Medium Now & Next / Large Daily Brief。
- 100% / 130% 字号、Increase Contrast、Differentiate Without Color。
- 刘海 / 无刘海、内屏 / 外接屏、clamshell、Stage Manager、全屏。

### 11.3 Truth Gate，任一失败即 No-Go

- 虚假 approval / failure 主动提醒：0。
- `verifiedExact` 打开错误目标：0。
- Privacy exposure：0。
- 断连误标 task failure：0。
- stale / cached 触发主动提醒：0。
- Widget / Notification 敏感标题：0。
- 受控 critical recall：approval 与重大 failure 100%，全部 critical ≥95%。

### 11.4 Value Gate

- participant median polling reduction ≥30%。
- action-needed resolution time median 改善 ≥30%。
- useful active alert rate ≥80%。
- Manual setup 无帮助完成率 ≥90%，median ≤3 分钟。
- Truth comprehension ≥90%。

## 12. 10 天 Pilot

- 16 人：至少 10 人 Codex cohort，至少 6 人 routine cohort。
- Day 1：同意、基线、隐私边界。
- Day 2：source truth 与 capability 理解。
- Day 3：断连 / stale / conflict。
- Day 4：Needs You 召回与去重。
- Day 5：精确返回与 fallback。
- Day 6：Manual routine 建立、编辑、删除、理解测试。
- Day 7：Privacy / screen-share 情境。
- Day 8：quota source 与 freshness 理解。
- Day 9：提醒疲劳、聚合与 mute。
- Day 10：条件性 Scheduled 测试和退出访谈。

Scheduled adapter 不可信时，Day 10 只测试 Manual card，不显示 live run state。

## 13. 发布路线

### Milestone A：Native Shell

- 主窗口、Menu Bar、主题、Privacy、Manual Pin、deep link、核心验证。
- 状态：已形成可运行本地 `.app`，继续视觉与辅助功能修订。

### Milestone B：Xcode Host + Widget

- 创建 Xcode app / Widget Extension targets、App Group、Small Quota、Medium Now & Next。
- 前置：安装完整 Xcode，配置签名 Team。

### Milestone C：Codex Adapter Spike

- capability probe、fixtures、contract tests、quota 与 critical event 观察。
- 前置：Gate A / B / C。

### Milestone D：Pilot

- 只启用已通过 Truth Gate 的 capability。
- Gmail / Scheduled health 默认关闭。

### Milestone E：Notch Overlay

- 在 Gate D 真机矩阵通过后作为可选体验，不阻塞无刘海版本。

## 14. 参考审查

- `reviews/uiux_v4.md`、`reviews/uiux_v5.md`
- `reviews/technical_v4.md`、`reviews/technical_v5.md`
- `reviews/user_needs_v4.md`、`reviews/user_needs_v5.md`
- Apple：WidgetKit、MenuBarExtra、UserNotifications、App Groups、Custom URL Schemes。
- OpenAI：Codex App Server、notifications、Scheduled tasks。
