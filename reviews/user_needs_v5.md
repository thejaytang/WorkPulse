# WorkPulse V5 用户 Pilot、埋点与真实性文案规范

> 角色：用户研究与产品洞察  
> 日期：2026-08-11  
> 输入：[PRD_V3](../PRD_V3.md)、[V4 用户需求](./user_needs_v4.md)、[V4 UI/UX 评审](./uiux_v4.md)、[V4 技术评审](./technical_v4.md)、当前原生代码只读检查  
> 范围：P0 Codex Needs You、精确返回、手动固定例程、隐私安全；Gmail / Scheduled 条件性需求  
> 本文不修改实现。

## 0. Pilot 的唯一判断问题

Pilot 不应先问“用户喜欢小组件还是刘海”，而应回答两个更严格的问题：

1. **Truth Gate**：WorkPulse 能否只展示来源确实证明的状态，不把断连、缓存、未载入、手动设置或打开请求写成任务事实？
2. **Value Gate**：在 Truth Gate 通过后，用户是否因此减少状态轮询，更快处理真正需要自己的事件，同时没有增加隐私风险和提醒疲劳？

先过 Truth Gate，再计算 Value Gate。任何会诱导错误高风险操作的虚假状态，不能用满意度或留存意愿抵消。

## 1. Pilot 范围与样本

### 1.1 样本

- 16 名参与者，10 天。
- Codex primary cohort：至少 10 人。每周至少 3 天同时运行 2 个以上 thread / agent，近两周遇到过 approval、needs input、failure 或 quota block。
- Routine cohort：至少 6 人。已经有每日或每周固定 ChatGPT routine；其中至少 4 人使用 Gmail / Calendar 类 Scheduled，至少 2 人来自 managed workspace。
- 允许 2–4 人同时属于两个 cohort，但同一行为不能重复计入两个指标分母。
- 至少 8 人使用外接显示器，至少 4 人经常屏幕共享或处理敏感项目。

### 1.2 Pilot 内允许出现的能力

| 能力 | Pilot 状态 | 允许宣称 | 禁止宣称 |
|---|---|---|---|
| Codex Needs You | Gate A/B/C 通过后开启 | 来自已验证 source 的 approval、input、重大 failure、turn quota block | 对 unsupported / notLoaded source 的实时监控 |
| 精确返回 | 仅 `verifiedExact` target | “打开对应审批 / 任务” | `NSWorkspace.open` accepted 即“已打开正确线程” |
| 手动固定例程 | P0 | 用户保存的名称、URL、用户自定提醒 | last run、next run、已完成、健康、邮件数 |
| Privacy | P0 | generic snapshot、显式 Privacy Mode、item-level title opt-in | 自动识别所有屏幕共享 |
| Codex quota | 仅可信 snapshot | source、window、remaining、reset、freshness | ChatGPT 总额度、足够完成某任务 |
| Gmail / Scheduled Health | 条件性研究 | 只有 adapter truth test 通过后显示已验证状态 | 通过时间推断 missed run；读取 Gmail 内容 |

### 1.3 研究数据边界

Pilot telemetry 不收集：prompt、assistant response、thread title、项目名、文件路径、shell command、URL、Gmail sender、subject、snippet、body、附件名、Scheduled prompt、Google account identifier。

可以收集：本地生成的 participant ID、event ID、target ID、source class、normalized state、freshness class、surface、时间戳、动作结果、错误类别、是否 generic、用户评分。ID 必须是 Pilot 内随机值，不从标题、URL 或账号哈希生成。

原始 Pilot 日志默认保留 14 天，之后只保留去标识化聚合指标；participant 可要求提前删除。日志导出前运行一次敏感字段 allowlist 检查，任何未声明 key 均阻止导出。

## 2. 10 天 Pilot 日程

### Day 1：入组、隐私边界与基线

- 完成设备、显示器、通知习惯、Codex 使用强度和 routine 类型筛选。
- 不开启 WorkPulse 主动提醒。
- 参与者记录每次“只为了看状态而打开 Codex / Scheduled”的行为。
- 让参与者复述：WorkPulse 是否读取 prompt、Gmail 和 Scheduled 状态。此时只记录基线，不教学纠正。
- 记录近 7 天最常错过的事件与后果，不问抽象功能偏好。

### Day 2：自然基线

- 正常工作，无 WorkPulse active alert。
- 记录 `manual_status_check`、检查目标、原因、是否真的需要动作。
- Codex cohort 记录并行任务数、任务大致时长分档，不记录任务内容。
- Routine cohort 记录今天是否打开 Scheduled 页、目的为确认运行还是阅读结果。

### Day 3：自然基线与阈值采样

- 继续记录手动轮询。
- 每次长任务结束后询问一次：“你从第几秒开始觉得值得被提醒？”记录区间 `<30s`、`30–60s`、`1–3m`、`3–10m`、`>10m`。
- 记录用户当时是否仍在 source app，避免把“任务很长”等同于“提醒有用”。

### Day 4：Onboarding 与手动固定例程

- 安装 Pilot build，展示数据边界和 generic 默认值。
- 用户手动添加一个固定入口，只输入自定义名称、HTTPS URL 和可选的“用户提醒时间”。
- 任务：打开、编辑名称、隐藏标题、修改提醒、移除后重新添加。
- 测试理解：要求参与者判断卡片是否知道例程已运行、是否知道下次真实运行时间、是否读取 Gmail。
- Privacy Mode 开启前后进行一次录屏或观察测试，确认所有即时表面 1 秒内泛化且无闪现。

### Day 5：Needs You controlled suite

- 每名 Codex participant 完成 8 个 scripted transitions：2 次 approval、1 次 needs input、1 次 work-loss-risk failure、1 次 recoverable failure、1 次 quota block、1 次 long completion、1 次 source disconnect。
- 至少一次 approval 来自 child / subagent，至少一次在用户切到其他 app 后发生。
- 检查事件排序、surface ownership、去重、acknowledged / resolved 区分。
- `source_disconnect` 必须只显示 monitoring lost，不能生成 task failure。

### Day 6：精确返回与失败回退

- 每名 Codex participant 测试 3 个 `verifiedExact` target、2 个 manual HTTPS target、1 个 unsupported / unverified target。
- 研究员使用 ground-truth target sheet 判断是否到达正确 thread / turn / approval。
- 测试目标不存在、Codex 未启动、URL 打开被系统拒绝、App Server 重连四种失败。
- 只有 target-specific confirmation 或研究员确认后才记录 `open_confirmed_exact`；系统接受打开请求仅记录 `open_request_accepted`。

### Day 7：Freshness 与虚假状态压力测试

- 依次注入或触发 `fresh`、`cached`、`stale`、`offline`、`unsupported`、`notLoaded`、`source_conflict`。
- 对 task、quota、manual routine 分别测试一次。
- 让参与者解释每张卡片能证明什么、不能证明什么，并选择是否愿意据此启动长任务或处理 reset。
- 验证 stale / unsupported / notLoaded 不产生 threshold alert。

### Day 8：多屏、全屏、通知与隐私

- 覆盖内建屏、外接主屏、双外屏、clamshell、普通全屏、屏幕共享。
- Privacy Mode 关闭时，Widget 与 Notification 仍只能使用 generic snapshot；item-level opt-in 只允许指定桌面表面显示名称。
- 同一事件在 Alert、Notification、MenuBar、Widget 间只允许一个主动 owner。
- 测试 notification permission denied、Focus、Overlay disabled；所有 unresolved 状态仍能从 MenuBar 找到。

### Day 9：自然工作与提醒疲劳

- 按默认路由自然使用一天。
- 每次 active alert 只问一个两秒问题：“现在有用吗？”选 `有用`、`太早`、`太晚`、`不该提醒`。
- 同一 20 秒窗口内制造 3 个 completion 和 1 个 failure，验证 completion 聚合且 failure 优先。
- Routine 成功且无需动作时不得主动提醒。
- 记录 participant 是否 mute 单个事件、单类事件或全部通知，以及原因。

### Day 10：条件性 Scheduled 测试与退出访谈

分两条路径：

- 无可信 Scheduled adapter：只测试 Manual 卡和 truth copy，不展示任何 live run state。
- adapter 已通过独立 truth test：使用 test routine 验证 fresh success、new result、paused、permission required、failure、stale、unknown；不使用真实邮件正文。

完成退出任务：

- 区分 Codex quota 与 ChatGPT Scheduled。
- 区分“打开请求已发送”与“已到达正确任务”。
- 区分“监控断开”与“任务失败”。
- 区分“用户设置 09:00 提醒”与“Scheduled 下次 09:00 运行”。
- 选择愿意保留的表面和事件类型，并说明最近一次真实使用价值。

最后收集保留意愿，但只作为 Value Gate 的一项，不覆盖 Truth Gate。

## 3. 事件埋点规范

### 3.1 通用 envelope

所有事件使用同一最小结构：

```text
event_name
occurred_at
participant_id        // 随机 Pilot ID
session_id            // 随机本地会话 ID
build_id
pilot_day
cohort                // codex | routine | both
source_class          // codex_app_server | manual_link | scheduled_adapter | fixture
source_capability     // live_verified | snapshot_only | manual_only | unsupported
work_event_id         // 随机或来自 source 的非内容 ID
surface               // menu_bar | widget | alert | notification | app
privacy_mode          // on | off
content_class         // generic | user_approved_title
```

禁止加入 `title`、`summary`、`url`、`prompt`、`message`、`path`、`email_*` 或任意自由文本。错误使用枚举 `error_class`，不上传原始错误正文。

### 3.2 Source truth 与状态归一化

| 事件名 | 触发时机 | 必要属性 | 主要指标 |
|---|---|---|---|
| `source_connection_changed` | source 连接、断开、重连 | `from_state`、`to_state`、`reason_class` | monitoring loss detection |
| `source_snapshot_received` | 收到一次 task / quota snapshot | `snapshot_kind`、`source_generated_at`、`fresh_until`、`schema_version` | snapshot fidelity |
| `source_event_observed` | source 提供 lifecycle transition | `raw_state_class`、`source_event_at` | event recall denominator join |
| `work_event_normalized` | 原始状态被映射为 P0 event | `normalized_type`、`confidence_class` | normalization accuracy |
| `state_withheld` | 因能力、freshness 或冲突不允许显示结论 | `withheld_reason` | truth protection rate |
| `freshness_changed` | fresh 转 cached / stale / offline | `from_freshness`、`to_freshness` | stale alert violations |
| `source_conflict_detected` | 两来源或 enforcement / meter 冲突 | `conflict_class`、`affected_domain` | source-conflict handling |

`confidence_class` 只允许 `source_explicit`、`derived_safe`、`unknown`。P0 active alert 只能来自 `source_explicit`；`derived_safe` 仅可用于非行动性表达，例如本地倒计时，并明确标注 Derived。

### 3.3 Delivery、提醒与去重

| 事件名 | 触发时机 | 必要属性 | 主要指标 |
|---|---|---|---|
| `delivery_decision_made` | policy 决定 owner 或 suppress | `normalized_type`、`owner_surface`、`decision_reason` | policy correctness |
| `surface_presented` | 用户可见表面实际呈现 | `surface`、`presented_at`、`copy_variant` | event-to-surface latency |
| `active_alert_suppressed` | 因前台、quiet hours、stale、duplicate 等抑制 | `suppression_reason` | false alert prevention |
| `duplicate_delivery_blocked` | event ID 已由另一表面拥有 | `existing_owner`、`blocked_surface` | deduplication rate |
| `notification_permission_prompted` | 仅用户选定提醒类型后请求 | `trigger_context` | permission timing |
| `notification_permission_result` | 系统返回结果 | `result` | fallback reachability |
| `alert_helpfulness_rated` | Pilot 微型反馈 | `rating` | useful alert rate |
| `mute_changed` | mute 某事件、类别或全局 | `scope`、`enabled`、`reason_enum` | fatigue signal |

`surface_presented` 必须是实际渲染完成，不是“计划展示”。同一 `work_event_id` 同一时刻最多一个 `owner_surface`；MenuBar / Inbox 的持久状态不算第二次主动提醒。

### 3.4 精确返回与处理闭环

| 事件名 | 触发时机 | 必要属性 | 主要指标 |
|---|---|---|---|
| `open_target_requested` | 用户点击 CTA | `target_id`、`target_capability`、`origin_surface` | action initiation |
| `open_request_accepted` | 操作系统接受打开请求 | `target_id` | 只作诊断，不算成功 |
| `open_confirmed_exact` | target-specific confirmation 或研究员 ground truth 证明正确 | `target_id`、`confirmation_method`、`latency_ms` | exact return rate |
| `open_failed` | 拒绝、超时、目标缺失或错误目标 | `target_id`、`error_class` | return failure rate |
| `fallback_presented` | 打开失败后显示 WorkPulse detail / manual instructions | `fallback_type`、`latency_ms` | safe fallback rate |
| `event_acknowledged` | 用户确实看见事件或打开详情 | `ack_method` | seen，不等于 solved |
| `event_resolved` | source 明确解除或用户在 source 完成处理 | `resolution_source` | resolution time |

`open_request_accepted` 不能自动触发 `event_acknowledged`；`event_acknowledged` 也不能自动触发 `event_resolved`。

### 3.5 Manual routine

| 事件名 | 触发时机 | 必要属性 | 主要指标 |
|---|---|---|---|
| `manual_routine_added` | 用户保存入口 | `routine_id`、`has_user_reminder`、`content_class` | setup completion |
| `manual_routine_opened` | 用户点击固定入口 | `routine_id`、`open_result` | entry utility |
| `manual_routine_edited` | 编辑名称、提醒或隐私 | `changed_field_enum` | control discoverability |
| `manual_routine_removed` | 用户删除本地入口 | `routine_id`、`reason_enum` | abandonment |
| `manual_reminder_fired` | 到用户设定提醒时间 | `routine_id`、`scheduled_locally_at` | 文案真实性 |
| `manual_sync_misunderstanding` | 研究任务中用户误认为卡片知道真实运行状态 | `misunderstanding_type` | false-state comprehension |

Manual routine 埋点不得出现 `last_run`、`next_run`、`completed`、`failed` 或 `attention_count`。若当前 domain model 仍含这些字段，Pilot analytics 必须将 Manual source 与它们隔离，避免 fixture 数据进入产品指标。

### 3.6 Privacy 与敏感信息 guardrail

| 事件名 | 触发时机 | 必要属性 | 主要指标 |
|---|---|---|---|
| `privacy_mode_changed` | 用户显式切换 | `enabled`、`origin_surface`、`apply_latency_ms` | privacy reaction time |
| `title_visibility_changed` | 单个 item 允许 / 禁止显示名称 | `item_id`、`enabled`、`surface_scope` | informed opt-in |
| `generic_snapshot_generated` | 写入 Widget / Notification snapshot | `field_allowlist_version` | generic coverage |
| `sensitive_field_blocked` | allowlist 阻止敏感字段写入或导出 | `field_class`、`destination` | prevention count |
| `privacy_exposure_incident` | 研究员确认出现未授权信息 | `surface`、`exposure_class`、`severity` | hard No-Go |

Pilot 不依赖自动屏幕共享检测。用户开启 Privacy Mode 是显式动作；Widget 和 Notification 无论该开关是否开启都默认 generic。

### 3.7 Conditional Scheduled adapter

只有 adapter 通过独立 capability test 后才启用：

| 事件名 | 触发时机 | 必要属性 |
|---|---|---|
| `scheduled_snapshot_received` | 收到可信 task snapshot | `task_id`、`run_state`、`source_generated_at`、`fresh_until` |
| `scheduled_state_presented` | 实际展示已验证状态 | `run_state`、`freshness`、`copy_variant` |
| `scheduled_result_opened` | 打开 latest result | `task_id`、`open_result` |
| `scheduled_manage_opened` | 打开官方管理表面 | `task_id`、`open_result` |
| `scheduled_active_alerted` | paused / permission / failure 等行动事件 | `reason_class`、`owner_surface` |

仍然禁止 Gmail 内容字段。`permission_required` 只能在 source 明确提供该原因时使用；“到了运行时间但没新记录”不能推导为 permission failure 或 missed run。

## 4. Ground truth 与指标计算

### 4.1 Ground truth 记录

受控任务使用独立 `research_ground_truth` 表，不由 WorkPulse 自己生成：

```text
scenario_id
participant_id
expected_event_type
expected_target_id
source_transition_at
expected_active_alert      // true | false
expected_copy_class
observer_result
```

自然使用期没有完整 ground truth，因此只能计算用户确认和 source-supported 指标，不能用未观测事件推断 recall。

### 4.2 核心公式

- **Critical event recall** = 正确呈现的 approval / needs input / work-loss-risk failure / turn quota block ÷ ground-truth critical events。
- **False active alert rate** = 无 ground truth 支持的 active alerts ÷ 全部 active alerts。
- **Event-to-surface latency** = `surface_presented.occurred_at - source_event_observed.source_event_at`。
- **Exact return rate** = `open_confirmed_exact` ÷ `open_target_requested`，按 target capability 分层。
- **Wrong-target rate** = 打开错误 thread / turn / approval ÷ open attempts。
- **Safe fallback rate** = 1 秒内显示 fallback 的 open failures ÷ 全部 open failures。
- **Premature acknowledgment rate** = 没有实际可见或确认打开却写 acknowledged 的事件 ÷ acknowledgments。
- **Resolution time** = `event_resolved - source_event_observed`，与 acknowledged time 分开。
- **Polling reduction** = `(baseline 日均手动状态检查 - Pilot 日均检查) ÷ baseline 日均检查`，先按 participant 计算，再取 median。
- **Useful alert rate** = `有用` ÷ 所有已评分 active alerts；未评分单独报告，不能默认有用。
- **Duplicate active rate** = 同 event ID 在一个 resolution cycle 中被两个以上主动表面呈现的事件 ÷ active events。
- **Truth comprehension** = 无提示正确区分 source / freshness / manual / confirmed open 的题目数 ÷ 总题目数。
- **Manual routine reuse** = 7 天测试窗口中打开入口的 distinct days。
- **Privacy exposure count** = 研究员确认的未授权 title、路径、邮件或正文暴露次数。

## 5. Go / Iterate / No-Go 阈值

### 5.1 Truth Gate，硬门槛

| 指标 | Go | Iterate | No-Go |
|---|---:|---:|---:|
| Critical transition recall，controlled | approval 与重大 failure 100%；全部 critical ≥95% | 95–99% 且没有漏 approval /重大 failure | <95%，或任一 approval /重大 failure 漏报 |
| False approval / failure active alert | 0 | 不适用，发现即修复重测 | 任一未修复 false high-risk alert |
| Wrong-target rate | 0 | 不适用 | 任一 `verifiedExact` 打开错误目标 |
| `verifiedExact` exact return | 100% controlled；overall ≥95% | overall 90–94%，降级部分 target | <90%，或仍把 unverified 写成 exact |
| Safe fallback | 100% open failure 在 1 秒内给出 fallback | 95–99% | <95% |
| Source disconnect 误标 task failure | 0 | 不适用 | 任一实例 |
| notLoaded / unsupported 误标 running | 0 | 不适用 | 任一实例 |
| stale / cached threshold alert | 0 | 不适用 | 任一实例 |
| Duplicate active delivery | 0 controlled；natural ≤1% | natural 1–3% | >3% 或重复高风险提醒 |
| Premature acknowledgment / resolution | 0 controlled | natural 可诊断个案 | 任一系统性自动 ack / resolve |
| Privacy exposure | 0 | 不适用 | 任一默认表面暴露敏感 title、路径或 Gmail 内容 |
| Telemetry allowlist | 100% 导出无敏感字段 | 不适用 | 任一原始内容或稳定账号标识被导出 |

任一硬 No-Go 发生后，暂停相关 capability，修复并完整重跑受控 suite；不能只排除该 participant 或该场景。

### 5.2 P0 Value Gate

| 指标 | Go | Iterate | No-Go / 降级 |
|---|---:|---:|---:|
| participant-level median polling reduction | ≥30% | 15–29% | <15% 或增加 |
| action-needed resolution time 改善 | median ≥30% | 10–29% | <10% |
| useful active alert rate | ≥80%，未评分率 <20% | 65–79% | <65% |
| 全局通知关闭 | <25% participant 在 Day 9 关闭全部通知 | 25–39% | ≥40% |
| Truth comprehension | ≥90%；且 0 人把 disconnect 当 task failure | 80–89% | <80% |
| Manual routine setup | ≥90% 无帮助完成，median ≤3 分钟 | 75–89% | <75% |
| Manual routine reuse | Routine cohort ≥4/6 在 7 天窗口至少使用 4 天 | 3/6 | ≤2/6 |
| 保留意愿 | Codex cohort ≥7/10 保留 MenuBar；≥6/10 能给出重复 JTBD | 5–6/10 | ≤4/10 |

如果 Truth Gate 通过但 polling reduction 未达到 15%，说明产品忠实但没有足够增量价值，不应扩大 Widget / Overlay 范围。先回到事件选择和目标用户密度，而不是增加 Daily Brief 或更多 dashboard。

### 5.3 Manual routine Gate

| 指标 | Go | No-Go |
|---|---:|---:|
| 用户知道这是手动入口，不是同步状态 | 6/6 无提示答对 | 任意 2 人以上误解为实时同步 |
| 打开入口成功 | ≥95% | <90% |
| 删除本地入口的理解 | 6/6 知道不会删除 ChatGPT task | 任意隐私或数据删除误解未被文案纠正 |
| 默认敏感信息暴露 | 0 | 任一实例 |
| 重复使用 | ≥4/6 在 7 天中使用 ≥4 天 | ≤2/6 |

Manual routine 价值不足不会阻止 Codex P0 发布；它应从默认 Widget 降为用户主动添加的快捷入口。

### 5.4 Conditional Gmail / Scheduled Gate

在用户价值测试前先过 adapter truth gate：

| 指标 | Go | No-Go / 降级 |
|---|---:|---:|
| task state 与 source snapshot 一致 | 100% controlled fixtures + test tasks | 任一状态映射错误 |
| Freshness 正确 | 100% | stale 仍显示绿色成功 |
| 成功无动作 active notification | 0 | 任一实例 |
| paused / permission / failure 检测 | 100% controlled；natural supported events ≥95% | <90% 或靠时间推断原因 |
| latest result return | ≥90%，其余有 manage fallback | <80% |
| Gmail content collected / exposed | 0 | 任一实例 |
| 数据边界理解 | 6/6 知道 WorkPulse 不访问 Gmail，不管理 Google scopes | ≤4/6 |
| Scheduled 页确认检查减少 | participant median ≥30% | <15% |

没有可信 adapter、只能根据用户自定时间计算“可能该运行了”时，结论必须是 **Scheduled Health No-Go**。保留 Manual entry，不能把 `userScheduleNote` 改名为 next run。

## 6. 避免虚假状态的文案合同

### 6.1 总规则

1. 事实动词只用于 source 明确事件：“Codex 报告需要审批”“来源确认任务已完成”。
2. 本地行为使用本地动词：“已发送打开请求”“你设置的提醒时间”。
3. 缺少证据时表达知识边界：“当前无法确认”，不猜测最可能原因。
4. `freshness` 必须与状态同屏；过期数据不能继续使用绿色 healthy 语义。
5. “已看”与“已解决”分开；打开卡片不等于任务问题解决。
6. 通知与 Widget 始终 generic；真实 title 只能经 item-level opt-in 出现在明确允许的桌面表面。
7. 不使用“实时”，除非 source subscription 与 latency Gate 已通过；优先写“刚刚更新”。

### 6.2 Source 与任务状态

| 条件 | 推荐文案 | 禁止文案 |
|---|---|---|
| fresh live source | `Codex 状态已更新 · 刚刚` | `永远实时` |
| cached | `显示上次已知状态 · 更新于 12:40` | `当前状态正常` |
| stale | `状态可能已过期 · 上次更新 12:40` | `仍在运行`、`已完成` |
| offline / disconnected | `已失去实时监控 · 任务本身可能仍在运行` | `任务失败`、`任务已停止` |
| unsupported | `此来源不支持实时状态` | `暂无任务` |
| notLoaded | `尚未载入，无法判断任务状态` | `正在运行`、`空闲` |
| source conflict | `状态来源不一致 · 请在 Codex 中确认` | 选择一个数值后写 `当前` |
| source-explicit approval | `有一项 Codex 任务需要你确认` | 含 thread title 的默认通知 |
| source-explicit failure | `Codex 报告一项任务失败` | `你的工作已丢失`，除非 source 证明 work-loss risk |
| completion | `Codex 报告任务已完成 · 2 分钟前` | 仅因进程安静写 `已完成` |

### 6.3 精确返回

| 阶段 | 推荐文案 | 禁止文案 |
|---|---|---|
| `verifiedExact` CTA | `打开审批` / `打开对应任务` | `查看` |
| 系统接受请求 | `已发送打开请求` | `已打开对应任务` |
| 已确认正确目标 | `已打开对应任务` | 无需变化 |
| 无法确认 | `未能确认是否到达对应任务` | `打开成功` |
| 打开失败 | `未能打开目标 · 查看 WorkPulse 详情` | 静默写 acknowledged |
| unverified target | `打开链接` / `在 Codex 中查找` | `精确返回` |

### 6.4 手动固定例程

| 条件 | 推荐文案 | 禁止文案 |
|---|---|---|
| 卡片标签 | `固定例程 · 手动` | `Scheduled · 已连接` |
| 无同步能力 | `WorkPulse 不会读取此例程的运行状态` | `状态正常` |
| 用户设定时间 | `你设置的提醒：今天 09:00` | `下次运行：09:00` |
| 打开动作 | `打开固定入口` | `打开最新结果`，除非 adapter 可证明 target |
| 打开后 | `已发送打开请求` | `已回到同一对话` |
| 删除入口 | `只移除 WorkPulse 中的入口，不会删除 ChatGPT 内容或任务` | `删除例程` |
| 无 title 授权 | `每日例程` | `每日 Gmail 审查` |

### 6.5 Conditional Scheduled

| 条件 | 推荐文案 | 禁止文案 |
|---|---|---|
| fresh verified run | `来源确认：今天 08:00 已运行` | `一切健康` |
| fresh result | `有一个新的已验证结果` | 展示邮件数或摘要 |
| paused，source explicit | `ChatGPT 报告此例程已暂停` | `Gmail 连接失败`，除非 source 明确 |
| permission required，source explicit | `ChatGPT 报告此例程需要检查权限` | `请在 WorkPulse 重新授权 Gmail` |
| 到点但无新记录 | `尚未收到新的已验证运行记录` | `错过运行`、`运行失败` |
| stale | `上次确认：昨天 08:00 · 当前状态未知` | 绿色 `已完成` |
| adapter unavailable | `当前无法同步 Scheduled 状态` | 沿用最后成功状态且不标时间 |
| CTA | `打开最新结果` + `管理例程`，仅 target verified | `返回同一对话` |

### 6.6 Codex quota

| 条件 | 推荐文案 | 禁止文案 |
|---|---|---|
| fresh | `Codex 5 小时窗口 · 64% 剩余 · 刚刚更新` | `ChatGPT 剩余额度 64%` |
| derived remaining | `64% 剩余 · 由来源用量换算` | 不标 Derived |
| cached | `上次记录 64% · 12:40 更新` | `当前剩余 64%` |
| stale | `Codex 额度状态可能已过期 · 不用于提醒` | `额度不足` |
| unsupported | `当前来源不提供 Codex 额度` | `0%` 或 `100%` 占位 |
| source conflict | `额度来源不一致 · 请在 Codex 中确认` | `建议使用一次 reset` |
| reset timestamp | `来源显示 12:40 重置` | `保证 12:40 恢复` |
| decision support | `查看 headroom 后由你决定是否开始` | `额度足够完成此任务` |

### 6.7 Privacy

| 条件 | 推荐文案 | 禁止文案 |
|---|---|---|
| Onboarding | `WorkPulse 不读取 prompt 或 Gmail 内容；它只显示已验证状态和你保存的入口。` | 泛化的 `隐私优先` 口号 |
| Privacy Mode on | `隐私模式已开启 · 即时表面仅显示泛化信息` | `已自动识别屏幕共享` |
| title opt-in | `允许在桌面显示此名称` | 默认勾选 |
| Widget / Notification | `有一项任务需要处理` | thread / routine title |
| 清除本地 routine | `清除本地入口和缓存；不会删除 ChatGPT 内容或断开 Gmail` | `删除所有数据` |

## 7. Pilot 报告模板

最终报告必须按以下顺序呈现，不能先报满意度：

1. **Truth Gate**：每个硬门槛 Pass / Fail、失败场景、是否完整重测。
2. **Capability coverage**：哪些 source / target 是 live verified、snapshot only、manual only、unsupported。
3. **Value Gate**：polling reduction、resolution time、useful alert、manual routine reuse、保留意愿。
4. **Privacy**：暴露事件、allowlist 阻止、数据边界理解。
5. **Notification burden**：日均 active alerts、重复率、mute / disable、成功例程静默率。
6. **Conditional Scheduled**：adapter truth test 与用户价值分别报告；没有 adapter 时明确写 `Not tested`，不能写 `Passed`。
7. **发布结论**：Full P0、P0 without Overlay、Manual routine optional、Scheduled Health No-Go、或整体 No-Go。

## 8. 最终发布决策规则

- Gate A/B/C 和 Truth Gate 全部通过，Value Gate 达标：进入 P0 Pilot release。
- A/B/C 通过、Overlay Gate 失败：以 MenuBar + Widget + Notification 进入无 Overlay Pilot。
- Needs You truth 通过但 exact return 失败：不以“行动闭环”发布，只能继续内部研究。
- Manual routine truth 通过但复用不足：保留为非默认快捷入口，不阻止 Codex P0。
- Scheduled adapter 不存在或 truth test 未通过：Scheduled Health 与 Gmail 状态一律 No-Go；只保留 Manual。
- 任何 privacy exposure、错误 high-risk alert、错误 exact target、disconnect 误标 failure：相关能力立即 No-Go，修复后完整重测。
- 如果最终只剩 quota tracker，按 V3 决策不发布为完整 WorkPulse。

第五轮的产品底线是：**WorkPulse 可以少说，但不能把“我不知道”包装成“状态正常”，也不能把“我发出了打开请求”包装成“你已经回到正确任务”。**
