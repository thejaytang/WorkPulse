# WorkPulse V7：Needs You 最小可审计事件契约

> 日期：2026-08-11  
> 范围：只定义当前可在 `WorkPulseCore` 实现和测试的 source-agnostic primitives  
> 明确不包含：真实 Codex / ChatGPT source adapter、跨客户端可见性、真实 Needs You 产品承诺

## 1. 结论

当前可以安全实现：

1. 经过 allowlist 的 normalized event envelope；
2. 不允许倒退或自动重开的 monotonic lifecycle reducer；
3. acknowledgment、resolution、delivery 三轴分离；
4. append-only delivery ledger 与单一主动表面 ownership；
5. ingress、transition、delivery、callback 四层 dedupe；
6. fixture 驱动的 deterministic tests 与审计导出。

当前不能实现或宣称：

- 从任意 ChatGPT / Codex Desktop task 发现真实 approval、needs input、failure 或 quota pause；
- 判断 raw App Server notification 的完整业务语义；
- 为跨客户端事件生成可靠 source object / cycle / transition identity；
- 在 reconnect 后证明历史重放和新事件的边界；
- 声称用户能精确返回 source context。

以上真实来源能力仍需 Gate A。精确返回另需 Gate B，App Server 长驻可靠性另需 Gate C。在 Gate A 通过前，event engine 只允许 fixture / controlled test 输入，不得驱动面向用户的真实 Needs You 数量、Alert 或 Notification。

## 2. 核心原则

### 2.1 三条状态轴必须分离

```text
source lifecycle:  active -> resolved | invalidated
acknowledgment:    unseen -> acknowledged
delivery:          unowned -> claimed -> scheduled/presented -> terminal
```

- `acknowledged` 只表示用户确实采取了可证明的查看动作，不等于 source 问题已解决。
- `resolved` 只能来自 source-explicit terminal transition；本地“打开”“稍后”“关闭通知”均不能写 resolved。
- `UNUserNotificationCenter.add` 成功只表示 request accepted / scheduled，不表示 presented。
- `NSWorkspace.open` 成功只表示系统接受打开请求，不表示 acknowledged、resolved 或 exact return。
- source disconnect、stale、`notLoaded` 只改变 monitoring / freshness，不得把 event 改写为 failure 或 resolved。

### 2.2 active alert 必须满足 truth gate

主动提醒只有在以下条件全部成立时才 eligible：

- provenance 为 `sourceExplicit`；
- observation mode 为 `liveTransition`；
- capability evidence 当前有效；
- lifecycle 为 `active`；
- freshness 为 `fresh`；
- event type 在 P0 allowlist；
- identity 含稳定的 source object、resolution cycle 与 transition key；
- source 不处于 conflict / degraded / unsupported；
- 不是 `fixture`、demo 或 derived guess。

任一条件不满足时，reducer 可以保存审计记录，但 delivery decision 必须是 `withheld` 或 passive-only。

## 3. Normalized event envelope

这是 WorkPulse domain envelope，不是 raw App Server DTO，也不是 analytics envelope。UI、Widget、Notification 与 DeliveryPolicy 都只能读取该结构，不能读取 raw source payload。

建议新增 `EventContract.swift`：

```swift
public enum EventProvenance: String, Codable, Sendable {
    case sourceExplicit
    case fixture
}

public enum SourceObservationMode: String, Codable, Sendable {
    case initialReconcile
    case liveTransition
}

public enum WorkEventLifecycle: String, Codable, Sendable {
    case active
    case resolved
    case invalidated
}

public enum SourceAdapterKind: String, Codable, Sendable {
    case codexAppServer
    case controlledFixture
}

public struct Digest32: Codable, Hashable, Sendable {
    public let bytes: Data

    public init(bytes: Data) throws {
        guard bytes.count == 32 else { throw EventValidationError.invalidDigest }
        self.bytes = bytes
    }

    // init(from:) 也必须读取 Data 后调用上面的 validating initializer；
    // 不能使用会绕过长度检查的 synthesized Decodable。
}

public struct SourceScope: Codable, Hashable, Sendable {
    // WorkPulse 本地随机 ID；账号或 principal 改变时必须轮换。
    public let sourceScopeID: UUID
    public let adapterKind: SourceAdapterKind
    public let capabilityEvidenceID: UUID
}

public struct EventIdentityMaterial: Codable, Hashable, Sendable {
    public let sourceScopeID: UUID
    public let sourceObjectDigest: Digest32
    public let resolutionCycleDigest: Digest32
    public let eventType: WorkEventType
}

public struct SourceCursor: Codable, Hashable, Sendable {
    // 只有 source 能证明同一 epoch 内单调时才提供。
    public let epoch: UUID
    public let sequence: UInt64
}

public struct WorkEventEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let identity: EventIdentityMaterial
    public let transitionDigest: Digest32
    public let source: SourceScope
    public let provenance: EventProvenance
    public let observationMode: SourceObservationMode
    public let lifecycle: WorkEventLifecycle
    public let sourceCursor: SourceCursor?
    public let sourceOccurredAt: Date?
    public let observedAt: Date
    public let freshUntil: Date?
    public let openTargetID: UUID?
}
```

### 3.1 ID 与隐私规则

- `eventID: UUID` 由 EventStore 在首次接受 `EventIdentityMaterial` 时本地分配；adapter 不能指定 WorkPulse event ID。
- source raw ID 不进入 envelope、ledger、Widget、Notification 或 telemetry。
- `sourceObjectDigest`、`resolutionCycleDigest`、`transitionDigest` 使用本机 Keychain secret 做 HMAC-SHA256；不能使用 title、prompt、message、path、URL 或 email content 生成。
- `sourceScopeID` 是 WorkPulse 本地随机 scope，不是账号、邮箱或 token 的 hash；认证 principal 改变时必须创建新 scope。
- `adapterKind` 是固定 enum；不能接收任意字符串。
- `openTargetID` 只是 WorkPulse 本地 target reference。envelope 不携带 URL、thread title、prompt 或 command。
- app 启动和 reconnect 的枚举结果必须标 `initialReconcile`；只有 source 明确标定的新变化才可标 `liveTransition`。

### 3.2 Resolution cycle 是强制字段

同一 source object 可能多次进入 Needs You。每次从正常状态进入新的 action-needed 状态必须有新的 `resolutionCycleDigest`。

```text
object A / cycle 1: active -> resolved
object A / cycle 2: active -> resolved
```

如果 source 无法区分 cycle 1 与 cycle 2，WorkPulse 无法同时做到 reconnect 去重与再次提醒，Gate A 必须判 fail。不得用本机观察时间猜测新 cycle。

### 3.3 Capability evidence registry

`capabilityEvidenceID` 不能由 adapter 自我声明为可信。Core 可以先实现一个本地 registry contract：

```swift
public struct CapabilityEvidenceRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceScopeID: UUID
    public let supportedEventTypes: Set<WorkEventType>
    public let validFrom: Date
    public let validUntil: Date
    public let gateRevision: UInt32
    public let testedSchemaDigest: Digest32
}
```

- Production registry 默认为空，因此当前所有真实 active delivery 都被 withheld。
- 只有完成并记录 Gate A controlled suite 后，受控配置流程才能写入 evidence record。
- adapter 的 handshake、method presence 或一次成功 notification 只能算 capability observation，不能自动升级为 Gate A evidence。
- evidence 过期、source scope 改变或 schema revision 改变时，对应 active delivery 立即关闭；已有 event 不伪造 resolved。

### 3.4 Envelope validation

`EventEnvelopeValidator` 至少执行：

1. schema version 必须受支持；
2. 三个 digest 必须恰好 32 bytes；
3. `source.sourceScopeID == identity.sourceScopeID`；
4. `sourceExplicit` 必须有已注册且未过期的 capability evidence；
5. `fixture` 永远返回 `activeDeliveryEligible=false`；
6. `initialReconcile` 可以建立 passive aggregate / terminal tombstone，但不能直接产生主动提醒；
7. `observedAt` 必填，`sourceOccurredAt` 可空；不能用本地时间伪造 source time；
8. `freshUntil == nil` 时 active alert 不 eligible；
9. unknown type/schema/capability 被隔离，不降级映射成 approval 或 failure；
10. terminal transition 不允许缺少 source-explicit evidence；
11. envelope 的 Codable 字段固定 allowlist；无自由文本字段。

P0 active-alert allowlist 仅包含 `needsApproval`、`needsInput`、`workLossRiskFailure`、`quotaPaused`。其他现有 `WorkEventType` 即使 source-explicit，也只能进入 passive policy，除非后续 PRD 和测试 gate 明确升级。

## 4. Monotonic event aggregate

建议新增 `EventReducer.swift`：

```swift
public enum AcknowledgmentState: Equatable, Codable, Sendable {
    case unseen
    case acknowledged(at: Date, method: AcknowledgmentMethod)
}

public enum EventIntegrityState: String, Codable, Sendable {
    case valid
    case sourceConflict
}

public struct WorkEventAggregate: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let identity: EventIdentityMaterial
    public private(set) var lifecycle: WorkEventLifecycle
    public private(set) var acknowledgment: AcknowledgmentState
    public private(set) var integrity: EventIntegrityState
    public private(set) var lastAcceptedCursor: SourceCursor?
    public private(set) var recordVersion: UInt64
    public private(set) var deliveryGeneration: UInt32
    public private(set) var snoozedUntil: Date?
    public private(set) var updatedAt: Date
}
```

### 4.1 Lifecycle transition table

| Current | Incoming | Result |
|---|---|---|
| none | active | create active aggregate |
| none | resolved / invalidated | create terminal tombstone；不 delivery |
| active | active duplicate | no-op |
| active | resolved | accept terminal |
| active | invalidated | accept terminal |
| resolved | resolved replay | no-op |
| invalidated | invalidated replay | no-op |
| resolved / invalidated | active replay | ignore as regression；保留 audit reason |
| resolved | invalidated，或反向 | 标记 `sourceConflict`；不覆盖首个 terminal |
| 任意 | same cursor but different transition digest | 标记 `sourceConflict`，停止 active delivery |
| 任意 | lower sequence in same epoch | ignore as out-of-order replay |

关键不变量：

- 同一 identity 一旦 terminal，永不重新 active。
- 新 action-needed occurrence 必须使用新的 resolution cycle，进而得到新的 WorkPulse event ID。
- `recordVersion` 只在接受有效 mutation 时加一；duplicate/no-op 不增加。
- acknowledgment 只允许 `unseen -> acknowledged`，不能回退。
- acknowledged 不改变 lifecycle。
- snooze 不改变 lifecycle 或 acknowledgment；到期后只增加 `deliveryGeneration`。
- source disconnect 不向 reducer 发送 resolved/invalidated；它属于 SourceHealthStore。
- source conflict 后事件保留在 passive diagnostics，不产生新主动提醒。
- `initialReconcile` 生成的 active aggregate 默认 passive；不能伪装成刚刚发生的新提醒。

### 4.2 可接受的 acknowledgment evidence

P0 只允许：

- 用户在 WorkPulse 中显式打开 event detail；
- 用户点击已经实际呈现的 Notification action；
- 用户在已呈现的 Overlay 上执行明确 action。

`AcknowledgmentMethod` 应是固定 enum：`eventDetailOpened`、`notificationAction`、`overlayAction`。不得以任意字符串或 raw callback payload 表示。

以下不能自动 acknowledged：

- notification request 被系统接受；
- notification 出现在 delivered query；
- overlay `show()` 被调用但没有 presentation confirmation；
- `NSWorkspace.open` 返回 `true`；
- MenuBar badge 更新；
- event 被 Widget snapshot 包含。

## 5. Dedupe contract

去重不是一个 key，而是四层 idempotency：

| 层 | 唯一键 | 作用 |
|---|---|---|
| Event identity | canonical `EventIdentityMaterial` | reconnect 后把同一 resolution cycle 映射到同一 WorkPulse event ID |
| Source transition | `(eventID, transitionDigest)` | 相同 raw transition 重放只处理一次 |
| Active delivery | `(eventID, deliveryGeneration)` | Overlay 与 Notification 竞争同一个主动提醒 owner |
| User callback | `(platformRequestID, actionID)` | 系统重复 callback 不产生重复 ack/snooze/open |

### 5.1 Canonicalization

- HMAC 输入使用固定字段顺序、长度前缀与 contract version，不拼接不定界字符串。
- Date、title、summary、freshness 不参与 identity key。
- process ID、connection ID 和 reconnect attempt 不参与 identity key。
- `sourceCursor` 用于排序，不参与 event identity。
- event type 参与 identity，防止同一 object/cycle 的 approval 与 failure 被错误合并。

### 5.2 无稳定 source ID 时的规则

如果 adapter 不能提供足以生成稳定 object、cycle、transition digest 的非内容标识：

- 可以保存一条 `state_withheld(.unstableIdentity)` 诊断；
- 不得创建 active-delivery-eligible event；
- 不得用时间窗口、标题相似度或 prompt hash 猜测 dedupe；
- 不得显示真实 Needs You count。

## 6. Delivery ownership 与 append-only ledger

`DeliveryPolicy` 当前只返回 surface set，不足以证明单一主动 owner。建议保留它作为纯 policy，再新增 `DeliveryCoordinator` 与 storage protocol。

### 6.1 Surface 分类

```swift
public enum DeliveryRole: String, Codable, Sendable {
    case passive       // MenuBar、Inbox、Widget，可同时存在
    case activeOwner   // Overlay Alert 或 Notification，同 generation 只能一个
}
```

MenuBar / Inbox 的 unresolved 列表和 badge 不计作重复主动提醒。Widget 永远是 passive，不承担实时 Needs You delivery SLA。

### 6.2 Ledger entry

```swift
public enum DeliveryLedgerAction: String, Codable, Sendable {
    case decisionMade
    case suppressed
    case ownerClaimed
    case requestSubmitted
    case requestAccepted
    case presented
    case opened
    case snoozed
    case dismissed
    case failed
    case canceled
    case ownerReleased
}

public struct DeliveryLedgerEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let eventID: UUID
    public let eventRecordVersion: UInt64
    public let deliveryGeneration: UInt32
    public let surface: DeliverySurface
    public let action: DeliveryLedgerAction
    public let occurredAt: Date
    public let attemptID: UUID
    public let platformRequestID: String? // WorkPulse 生成的 generic stable ID
    public let reason: DeliveryReason     // enum，不存 raw error text
}
```

Ledger 只追加，不更新和删除。当前 owner、attempt 状态与指标由 ledger projection 派生；产品数据清除时按 retention policy 删除整个 event/cycle，而不是改写历史行。

### 6.3 Owner projection

```swift
public enum ActiveOwnerState: Equatable, Sendable {
    case unowned
    case claimed(surface: DeliverySurface, attemptID: UUID)
    case scheduled(surface: DeliverySurface, attemptID: UUID)
    case presented(surface: DeliverySurface, attemptID: UUID)
    case terminal
}
```

需要 storage-level unique constraint：同一 `(eventID, deliveryGeneration)` 最多一条非 terminal active-owner claim。仅靠 actor 内存锁不足以覆盖 crash/relaunch。

### 6.4 最小执行顺序

```text
1. transaction: re-read event -> check active/fresh/valid/unmuted
2. transaction: insert unique owner claim + append ownerClaimed
3. commit
4. execute external side effect
5. transaction: append requestAccepted / presented / failed
6. on failure before presentation: release owner, then policy may claim fallback
```

- Overlay 可达时先 claim Overlay；成功 presented 后不得再补 Notification。
- Overlay 在 presented 前失败，才允许释放 owner 并 claim Notification。
- Notification `add` 成功记录 `requestAccepted`，不能记录 `presented`。
- Notification presented 只能由 delegate 或 delivered-state reconciliation 确认，并必须区分“系统列为 delivered”和“用户看见”。
- 事件 terminal 时取消 pending Notification、关闭 Overlay，并追加 `canceled`；ledger 不删除。
- ack 后事件仍留在 Inbox，直到 source-explicit terminal。
- snooze 到期创建下一 `deliveryGeneration`；旧 generation 永不重用。

### 6.5 Crash recovery

跨系统 side effect 无法只靠本地 transaction 保证 exactly-once。P0 应承诺“idempotent request + at-most-one active owner”，而不是虚假的 exactly-once delivery。

- Notification request ID 固定为 `workpulse.event.<eventID>.<generation>`。
- 重启后对 `claimed/scheduled` attempt 查询 pending / delivered notification 并 reconcile。
- 若 ledger 为 claimed 但系统无对应 request，记录 `failed(.recoveryMissingRequest)` 后释放。
- Overlay 属于进程内表面；进程重启后旧 Overlay 必然不存在，可把未 presented claim 记录为 interrupted 后释放。
- 已记录 presented 的 generation 不自动重播；只有用户明确 snooze 或 policy-defined escalation 才生成新 generation。

## 7. 建议的 WorkPulseCore 文件边界

```text
Sources/WorkPulseCore/
├── EventContract.swift          # envelope、digest、validation
├── EventReducer.swift           # monotonic aggregate + pure transitions
├── EventEligibility.swift       # truth/freshness/capability gate
├── EventRepository.swift        # storage protocol；先提供 in-memory test actor
├── DeliveryLedger.swift         # append-only entries + projection
├── DeliveryCoordinator.swift    # claim/commit/reconcile orchestration
└── DeliveryPolicy.swift         # 现有纯 surface policy，补 role/decision reason
```

P0 第一阶段不需要先引入真实 App Server DTO，也不需要把 SQLite 放进 pure reducer。先用 deterministic in-memory repository 验证不变量；Xcode host 建立后，再实现 SQLite repository 与唯一索引。

建议 repository contract：

```swift
public protocol EventRepository: Sendable {
    func ingest(_ envelope: WorkEventEnvelope) async throws -> IngestResult
    func acknowledge(eventID: UUID, evidence: AcknowledgmentEvidence) async throws
    func snooze(eventID: UUID, until: Date) async throws
    func claimActiveOwner(_ claim: DeliveryClaim) async throws -> ClaimResult
    func appendLedger(_ entry: DeliveryLedgerEntry) async throws
    func unresolvedEvents() async throws -> [WorkEventAggregate]
}
```

任何 API 都不接受 raw payload、自由文本 title、URL 或 App Server JSON。

## 8. WorkPulseCore 测试用例

以下测试全部可在没有真实 adapter 的情况下用 `controlledFixture` 完成。fixture provenance 必须被 eligibility gate 阻止进入生产主动表面。DeliveryCoordinator 单元测试直接在 test module 中构造 internal `EligibleDeliveryCandidate`；不要给生产 validator 增加可运行时开启的 bypass flag。

### 8.1 Envelope 与隐私

| ID | Case | Expected |
|---|---|---|
| E01 | current schema + 三个合法 digest | accepted |
| E02 | future schema | quarantined / unsupported，不 crash |
| E03 | digest 31/33 bytes | rejected |
| E04 | identity/source scope 不一致 | rejected |
| E05 | fixture 事件请求 active delivery | withheld |
| E06 | sourceExplicit 但 evidence 缺失/过期 | withheld |
| E07 | freshUntil nil/stale | passive-only，不 alert |
| E08 | Codable JSON 扫描 title/prompt/path/url/token/message key | 0 matches |
| E09 | unknown event type | unsupported，不映射成 failure |
| E10 | terminal transition 无 source evidence | rejected |
| E11 | initialReconcile active event | aggregate 可保存；active delivery withheld |

### 8.2 Monotonic reducer

| ID | Sequence | Expected |
|---|---|---|
| M01 | active, same active replay ×100 | 一个 event；recordVersion 不增加 100 次 |
| M02 | active -> resolved -> active replay | 保持 resolved |
| M03 | active -> invalidated -> active replay | 保持 invalidated |
| M04 | resolved -> conflicting invalidated | 首个 terminal 保留；integrity=sourceConflict |
| M05 | cursor seq 10 -> 9 | seq 9 ignored |
| M06 | same cursor + different transition digest | sourceConflict；停止 delivery |
| M07 | unseen -> acknowledged -> duplicate ack | 一次 ack；不 resolved |
| M08 | open request accepted | lifecycle/ack 均不变 |
| M09 | source disconnect | lifecycle 不变；SourceHealth 单独 offline |
| M10 | same object, new cycle digest | 新 event ID，可形成新 action cycle |
| M11 | terminal event snooze | rejected/no-op |
| M12 | snooze active event 到期 | generation +1；lifecycle 仍 active |
| M13 | none -> terminal -> active replay | terminal tombstone 保留；不产生提醒 |

### 8.3 Delivery ledger 与 ownership

| ID | Case | Expected |
|---|---|---|
| D01 | 100 concurrent Overlay/Notification claims | 恰好一个 active owner |
| D02 | Overlay claim + presented + Notification request | Notification blocked |
| D03 | Overlay 在 presented 前失败 | owner released；Notification 可 claim |
| D04 | Notification add accepted | ledger=schedule/requestAccepted，不是 presented |
| D05 | callback 重放 ×100 | ack/snooze/open side effect 各一次 |
| D06 | MenuBar + Inbox +一个 active owner | 合法；不计主动重复 |
| D07 | resolved 与 claim race | transaction 后无新 active delivery；pending 被 canceled |
| D08 | stale 与 claim race | stale winning 时 claim withheld |
| D09 | crash after claim before side effect | recovery 记录 interrupted/failed 后安全 release |
| D10 | crash after Notification accepted before ledger result | stable request ID reconcile，不重复 schedule |
| D11 | presented generation 重启 | 不自动重播 |
| D12 | snooze 到期 | 仅新 generation 可再次 claim |
| D13 | permission denied | Notification suppressed；Inbox/MenuBar 可达 |
| D14 | Overlay reachable | active owner=Overlay，Notification 不同时发 |
| D15 | event terminal | Overlay close + pending notification cancel + ledger retained |

### 8.4 Property / soak tests

- 对每种 lifecycle transition 排列做 property test：terminal 从不回到 active。
- 随机重排同一 cycle 的 1,000 个 duplicate/replay：最终 aggregate 唯一且 deterministic。
- 100 actors 并发 claim 1,000 轮：每轮 active owner 数量 ≤1。
- ledger replay 任意次数：projection 相同。
- 模拟 crash point 位于执行顺序每一步前后：没有 overlay + notification 双 owner。
- 10,000 个 envelope 编码后执行敏感 key/value fixture scan：泄漏数 0。

### 8.5 当前阶段量化验收

| 指标 | Pass |
|---|---:|
| deterministic event identity | 同 fixture 重放 1,000 次，event count=1 |
| lifecycle regression | 0 |
| false terminal from disconnect/stale | 0 |
| duplicate active owner | 0 / 1,000 concurrency rounds |
| premature acknowledgment | 0 |
| scheduled-as-presented misclassification | 0 |
| callback non-idempotency | 0 / 100 repeats per action |
| privacy allowlist leak | 0 |
| fixture escaping active eligibility | 0 |

这些指标只验证 engine correctness，不计入真实 Critical event recall，因为没有真实 source ground truth。

## 9. Gate A 仍必须证明什么

完成上述 primitives 后，Gate A 仍必须用真实 source 证明：

1. 独立 WorkPulse process 能在不 `thread/resume`、不改变 ownership、无 metadata write 的情况下看到目标 Desktop / CLI task。
2. source 对 approval、needs input、work-loss-risk failure、quota pause、resolved/invalidated 提供 machine-readable、source-explicit 语义。
3. source 提供或允许可靠生成稳定 object ID、resolution cycle ID、transition ID；不能依赖 title 或时间猜测。
4. source 的 cursor/replay/initial snapshot 语义足以区分历史状态、当前 active 与 reconnect replay。
5. source disconnect 能在 ≤2 秒降级 monitoring state，但不会制造 task failure/resolution。
6. controlled suite 中关键 transition recall ≥95%，approval 与重大 failure 不得漏报，false high-risk alert=0。
7. 初始同步与 reconnect 的历史 completion/old approval 主动提醒=0。
8. `notLoaded` 被标成 running 或 Needs You 的次数=0。

Gate A 未通过时：

- `EventProvenance.sourceExplicit` capability 不注册；
- Release build 的 active eligibility 永远 false；
- MenuBar 只能显示“实时 Needs You 不支持 / 未连接”，不能显示 0 项来暗示已监控；
- demo 可继续展示未来交互，但必须标 `fixture`，且不得写 Widget snapshot 或安排 Notification。

Gate A 通过只允许开启真实事件发现。Primary CTA 的 `verifiedExact`、错误目标率与 safe fallback 仍需 Gate B；长驻 transport、reconnect 与 schema 兼容仍需 Gate C。

## 10. 推荐实现顺序

1. 实现 `Digest32`、envelope、validator 与 fixture-only tests。
2. 实现 pure monotonic reducer 和 property tests。
3. 实现 in-memory repository、四层 dedupe 与并发 claim tests。
4. 实现 append-only ledger projection 和 crash-point simulation。
5. 将现有 `DeliveryPolicy` 改为输出带 reason 的 decision，但暂不调用 macOS Notification / NSPanel。
6. Xcode host 可用后实现 SQLite unique constraints 与 `UNUserNotificationCenter` reconciliation。
7. 最后接真实 adapter 做 Gate A；Gate A 通过前不把任何真实 Needs You 表面打开给用户。

一句话边界：

> V7 可以先把“事件如何被安全表示、怎样不倒退、如何不重复提醒、如何留下审计证据”做对；但在 Gate A 证明 source truth 之前，它仍只是经过严格测试的事件引擎，不是一个真实工作的 Needs You companion。
