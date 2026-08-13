# WorkPulse build 15 Completion Delta Audit

> 日期：2026-08-13  
> 基线：`reviews/product_completion_audit_v2.md`  
> 目标：已安装的 `~/Applications/WorkPulse.app`，build 15 / 0.3.1  
> 对照：`reviews/final_acceptance_v15_2026-08-13.md`  
> 原则：分开“源码存在”、“系统表面可用”和“用户任务闭环”；不以 verifier 绿灯代替用户验收

## 1. 结论

**build 15 是有实质进展的 Local Developer Preview，但仍不是完整可交付产品。**

相对上一轮，它真正关闭了三个缺口：

1. Privacy Mode 已通过统一的 `PresentationPrivacyPolicy` 覆盖任务名偏好。本轮当前 Resident 显示“2 个任务运行中 / 隐私模式 · 共 2 个”，Expanded 中两个标题都显示“任务名称已隐藏”，未再复现 build 9 的泄漏。
2. 任务终态不再只用“任务消失”猜测完成；代码会回读 `task_complete`、`task_cancelled`、`task_failed` 或 `turn_aborted`，并区分完成、取消、失败和中止。
3. 主题作用域已比较明确：物理刘海屏始终使用深色融合表面；System/Light/Dark 影响控制中心、Widget 和无刘海屏的顶部胶囊。

但用户原始范围仍有八个 P0 或发布 P0：

- 四种 Widget 尚未完成 Gallery 搜索、添加、刷新和点击回流。
- 有运行任务时，Resident 仍完全取代“剩余额度 + 下次重置时间”。
- 运行任务虽有标题，但无法从 Resident、Expanded、Alert 或 Notification 打开对应任务/结果。
- 系统通知仍为 `notDetermined`，真实横幅、声音、去重和回流未验收。
- 当前 `targetURL` 为空，Small Pinned 没有与真实“每日 Gmail 审查对话”闭环。
- 控制中心作为唯一配置/恢复入口，尚未通过干净偏好的首设任务测试。
- Privacy 在 Resident/Expanded 的已知 bug 已修，但 Widget、Notification 和 VoiceOver 的跨表面零泄漏尚未证明。
- `final_acceptance_v15` 的签名结论在当前环境无法复现，因而 Widget 系统交付证据链未关闭。

## 2. 必须先说明的证据矛盾

`final_acceptance_v15` 记载 Host/Widget 严格签名验证通过，但本轮对同一安装包现场复查得到：

- `codesign --verify --deep --strict ~/Applications/WorkPulse.app` → `CSSMERR_TP_NOT_TRUSTED`。
- Widget Extension 的严格验证同样返回 `CSSMERR_TP_NOT_TRUSTED`。
- `security find-identity -v -p codesigning` → `0 valid identities found`。
- `verify_widget_runtime.sh` → `FAIL: 宿主或扩展签名无效`。
- `pluginkit` 当前查询返回 `Connection invalid`，因此本轮也无法重现“仅登记一份 Widget”。
- ZIP SHA-256 与验收文档一致：`b1f1e389faa5726bff76b1f1e65d6fb6743c3b0d2018ddd9e74943d6a060f497`。Host/Widget 也均含 Team ID `<APPLE_TEAM_ID>` 和同一 App Group，说明工程结构有进展，但当前签名信任不可复现。

这不证明 01:13 的记录必然为假，但证明它**不能作为当前交付 Gate**。完成条件必须是“交付时和干净环境仍可验证”，不是“构建当下曾短暂通过”。

## 3. 证据分级

| 证据 | 本轮结果 | 能证明 | 不能证明 |
|---|---|---|---|
| `WorkPulseCoreVerify` | 242 checks 通过 | 模型、privacy policy、终态解析和 quota 策略的确定性逻辑 | Widget 可添加、Alert/通知可见、对话实际到达 |
| `verify_system_surfaces.sh` | 通过 | 相关代码分支、target 和类型存在 | 产品优先级正确。它仍把“运行任务优先于剩余额度”当作 PASS |
| 当前 Resident/Expanded 实机读取 | Privacy On 时标题已隐藏，Resident 可进入 Expanded | 这两个表面的隐私覆盖生效 | Privacy Off 任务身份质量、Alert 闭环、多屏/全屏可靠性 |
| Bundle 结构 | Host + `.appex` 均为 build 15，Team/App Group 存在 | 工程结构比 build 9 完整 | 签名链可信、Gallery 可用、对外可分发 |
| Gallery | 无用户搜索/添加证据 | 自动化不能代替系统 UI Gate | 任何 Widget 已交付 |
| Notification | `notDetermined` | 用户尚未授权 | 横幅、声音、Focus、去重和回流成立 |

当前阶段仍是：

- Host + Notch 本机 dogfood：**Conditional Go**。
- 完整本地伴生应用：**No-Go**。
- 对外一次买断商品：**No-Go**。

## 4. 用户原始范围逐项 Delta

| 原始范围 | build 15 已有什么 | 仍然缺什么 | 当前判定 |
|---|---|---|---|
| 桌面 Widget 不同尺寸 | Small Quota、Small Pinned、Medium 额度+入口、Large 工作概览均在生产 `WidgetBundle` | 四种都没有当前用户 Gallery/桌面/refresh/deep-link 证据；签名也无法复现 | **P0**；若用户明确同意首发只两只 Small，Medium/Large 才可延期，且必须从 bundle 移出 |
| 固定某个对话 | 可保存一个 HTTPS URL + 标题；Widget 经 `workpulse://routine/<UUID>` 回宿主再打开 | 当前 URL 为空；无桌面点击到达证据；只是全局单例，多个 Widget 仍指向同一对话 | **P0** 闭环未成；“一个还是多个可配置入口”需用户决策 |
| 刘海 Resident | Resident 实机可见，可进入 Expanded；Privacy On 表现正确 | 任务运行时 quota + reset 完全消失；这与用户明确价值冲突 | **P0 信息架构未定稿** |
| 一次性 Alert | 有独立开关、6 秒、hover 暂停、点击 Expanded 与回 Resident 代码 | 无本轮真实 Alert 完整交互证据；任务终态 Alert 没有自己的 expanded content，点击后会展开当前 Resident 内容 | **P0** |
| 运行任务具体身份 | 只读本地 Codex 状态，排除 subagent，优先使用 task name/title；Privacy 可硬隐藏 | 无 Privacy Off 实机可读性矩阵；同名/长标题无唯一性；无任务级 deep link；wall-clock elapsed 不是进度 | **P0**，因为“看到名字”还没有成为可行动身份 |
| 系统通知 | `UNUserNotificationCenter`、quota/event/task-terminal categories、banner/sound、diagnostic snapshot 与 callback 存在 | 权限 `notDetermined`；无真实送达/声音/Focus/去重/回流矩阵；任务终态只回流通用 inbox | **P0** |
| 菜单栏控制中心 | 生产 Scene 只有 `MenuBarExtra`，没有独立 Dashboard；配置范围基本齐全 | 固定 URL 和通知仍未完成真实首设；Widget 快照写入与 Gallery 注册的语义需分开；“授权”印章会制造虚假完成感 | **P0 首设/恢复闭环**；视觉精修可后置 |
| 浅色/深色主题 | System/Light/Dark 持久化；物理刘海保持深色融合；验收文档记录了 Light/Dark/System 检查 | Widget 实际主题未验；无完整可访问性矩阵 | **Conditional Go / P1** |
| 强调色 | Ocean/Violet/Mint/Sunset/Rose 可选并写入 Widget snapshot | 5 accents×2 themes×normal/warning/critical 的对比度与无色区分未验 | **P1，可延期**；需用户决定是否保留这么多个性化 |
| 隐私 | Resident/Expanded 的原 P0 bug 已修；标题经统一 policy | Notification/Widget/VoiceOver 尚无真实外部表面证据；任务名首次默认仍为显示 | **已关闭已知 bug，完整隐私 Gate 仍为 P0** |
| 一次买断方向 | 只有“正式发布计划一次买断”文案 | 无 StoreKit、transaction、receipt、restore、license、activation、entitlement、Developer ID/notarization 商品闭环 | **本地/Pilot 可延期；对外付费产品则是发布 P0** |

## 5. 关键交互反例

### 5.1 Resident 仍在解决错的优先级

当前 `notchResidentTitle` 只要发现 active task 就进入任务分支，`notchResidentDetail` 则只显示 elapsed/任务数。这意味着用户最需要判断“现在是否还适合继续发起 Codex 任务”时，quota 恰好被隐藏。

下一轮必须在两种方案中做决定：

1. **推荐：quota 恒定 + 紧凑 task indicator。** Resident 始终显示 `window + remaining + reset`，另用小图标/数量表示运行任务；Expanded 同时显示 quota 和具体任务。
2. **可接受：用户手动选择 Quota Resident / Task Resident。** 不再根据运行状态自动抢占。

继续保留当前自动覆盖不是可放行选项。

### 5.2 任务 Alert 与 Notification 没有任务级回流

- `showTaskTerminalAlert` 调用 `showAlert` 时没有传入 `expandedContent`。用户点击任务终态 Alert，展开的会是当前 Resident 内容，不是该任务的结果或错误详情。
- `scheduleTaskTerminalAlert` 把 deep link 固定为 `workpulse://inbox`，不会打开对应 task/thread。
- 因此当前只完成“告诉用户一个名字”，没有完成“让用户处理这个任务”。

如果 Codex 当前没有可靠的任务级打开 API，产品必须明示“只能展示身份，无法直达”，而不是用通用 inbox 伪装任务回流。

### 5.3 固定对话的最后一公里仍为空

代码已能验证 HTTPS URL、保存标题、发起打开和处理过期 UUID，但用户本机尚未保存任何 URL。因此 Small Pinned 不是“只差一次测试”，而是对该用户尚未创造价值。

首发可只支持一个全局对话，但必须用真实 Gmail 审查 URL 完成桌面点击到达。若用户要求同时固定多个项目/线程，则需要每 Widget 实例可配置的 intent，属于 P1 扩展。

## 6. 当前仍未关闭的 P0

| 顺序 | P0 缺口 | 最小关闭证据 |
|---|---|---|
| 1 | **决定 Resident 中 quota 与 task 的共存规则** | 用户选定共存或手动模式；无/1/2+ 任务×Privacy On/Off×fresh/stale 的 3 秒扫读通过 |
| 2 | **恢复可复现签名并完成 Widget Gallery** | 同一构建环境连续两次产出可验 Host/Widget；全新账户能添加当前 bundle 暴露的每种尺寸 |
| 3 | **完成固定对话的真实桌面闭环** | 保存真实 Gmail 审查 URL；Small Pinned 连续 10 次到达正确对话；空/非 HTTPS/过期 UUID 可恢复 |
| 4 | **补上任务身份的打开/结果动作** | 任务级 deep link，或清晰的“当前平台不支持定位”降级；终态 Alert 有自己详情而非无关 Resident |
| 5 | **完成 Notification 授权、送达、去重和回流** | authorized/denied、banner/sound、Focus、前台、用户不活跃、fallback、重启去重和点击回流矩阵；普通 refresh 通知 0 |
| 6 | **完成控制中心首设与恢复任务** | 干净偏好下，quota 来源、固定 URL、通知、privacy、Widget 状态的无指导任务成功率 ≥90% |
| 7 | **完成 Privacy 的 Notification/Widget/VoiceOver 矩阵** | Privacy On 在 Resident/Expanded/Alert/Notification/控制中心/所有暴露 Widget/VoiceOver 中敏感标题数 = 0 |
| 8 | **建立单一、可复现的 Release 证据链** | 归一当前两份不一致的 Xcode project；唯一构建命令/产物 hash/签名/Gallery/截图/日志绑定同一 build |

## 7. 可延期，但需要用户决策

| 决策题 | 选项 A | 选项 B | 建议 |
|---|---|---|---|
| Widget 首发范围 | 四种全部保留，则四种都是 P0 E2E | 首发仅 Small Quota + Small Pinned，Medium/Large 从 bundle 移出并延期 | **B**，但必须由用户确认收缩原始范围 |
| Resident 的 quota/task 规则 | 恒定 quota + 紧凑 task indicator | 用户手动选 Quota/Task Resident | **A**，保留 remaining + reset 的首要价值 |
| 固定对话数量 | 一个全局入口 | 每个 Widget 实例可选不同对话 | **A** 可先闭环；若需多项目，B 进 P1 |
| 任务名首次默认 | 默认显示，Privacy Mode 再隐藏 | 默认隐藏，用户明确 opt-in | **B**，共享屏幕泄漏风险更不可逆 |
| 主题与强调色 | System/Light/Dark + 5 accents | Light/Dark + 1 品牌色 | 保留 System；5 accents 降为 P1，核心闭环前不继续扩展 |
| 是否对外卖 | 个人本地/Pilot，不实现购买 | 对外一次买断商品 | 先关闭 **A**；用户明确选 B 后，分发 + purchase/license 转为新商业 P0 |
| 买断通道 | Mac App Store + StoreKit | Developer ID 直销 + license/update | 仅在选择对外买断后决定；不由当前文案预设 |

### 买断方向

当前没有 StoreKit product、transaction、receipt、restore purchase、license key、activation、entitlement 或试用期，只有“正式发布计划采用一次买断”的文案。

- 个人本地/Pilot：购买可延期，且应移除“授权”勾选印章和一次买断承诺。
- 对外付费商品：Developer ID/notarization/update + 购买/license/restore 全部是发布 P0；Personal Team 开发签名不能承担这一目标。

## 8. 下一轮顺序与 Gate

### Gate A：先由用户定义范围

1. 首发 Widget 是 2 种 Small，还是 4 种全尺寸。
2. Resident 是“quota 恒定 + task indicator”，还是手动模式切换。
3. 目标是个人本地/Pilot，还是对外一次买断。

Gate A 之前不再增加 Widget 尺寸、强调色或购买文案。

### Gate B：恢复可复现构建

- 归一两份 Xcode project。
- 建立稳定的 Apple Development/Developer ID 签名环境。
- 对同一 ZIP 在构建机和安装机各执行严格验证。

**通过标准：** 连续两次构建/安装后 Host/Widget 严格验证都通过，App Group 一致，PlugInKit 只有一份当前注册。

### Gate C：Resident + task 动作

- 实现 Gate A 选定的 quota/task 共存方案。
- 任务 Expanded/Alert 增加对应任务的详情和动作，或明示平台不支持直达。
- 保留 Privacy Mode 对标题的硬覆盖。

**通过标准：** quota 不再因任务运行而无提示消失；任务身份可唯一理解；终态 Alert 不展开无关内容。

### Gate D：Widget + Pinned

- 只对 Gate A 选定的 Widget 范围做 Gallery 验收。
- 设置真实 Gmail 审查对话 URL。
- 验收 Widget 主题、accent、freshness 与 host 退出/重启。

**通过标准：** 承诺的每种 Widget 都能被搜索、添加、刷新、点击、移除和重新添加；固定对话到达率 100%。

### Gate E：Notification + 隐私

- 用户完成 macOS 通知授权。
- 执行 banner/sound/Focus/fallback/dedupe/deep-link 矩阵。
- 将 Widget 和 Notification 加入 Privacy On/Off 矩阵。

**通过标准：** 真实送达可证明，重复为 0，回流正确，Privacy On 外部标题泄漏为 0。

### Gate F：仅对外买断时启动

- 确定 Mac App Store 或 Developer ID 直销。
- 实现购买、恢复、license/entitlement、更新与支持边界。
- 完成 Developer ID/notarization/stapling 或 App Store 审核要求。

## 9. 放行决策

| 目标 | 决策 | 原因 |
|---|---|---|
| Host/Notch 继续本机 dogfood | **Conditional Go** | Privacy Resident/Expanded 有当前实机证据，但任务会遮蔽 quota |
| 宣称 Widget 已交付 | **No-Go** | Gallery 人工 Gate 未过，签名复查不可复现 |
| 宣称固定对话已可用 | **No-Go** | URL 为空，无桌面点击到达证据 |
| 宣称系统通知已可用 | **No-Go** | `notDetermined`，送达/去重/回流未验收 |
| 宣称完整本地伴生应用 | **No-Go** | Resident IA、Widget、Pinned、Notification 和证据链仍有 P0 |
| 宣称对外一次买断商品 | **No-Go** | 只有文案，无商业分发和购买闭环 |

**最终判断：build 15 已越过“顶部岛视觉原型”，但尚未越过“Widget、顶部岛和 Notification 可靠协作”的完整产品线。下一轮应先做 Gate A 的三个用户决策，再按 Gate B→E 闭环；不应继续用更多 Widget 尺寸、强调色或买断文案代替真实系统验收。**
