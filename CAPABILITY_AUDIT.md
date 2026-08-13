# WorkPulse 本机 Capability Audit

> 检查时间：2026-08-11  
> 范围：只读检查本机 Codex CLI、App Server schema 与初始化 / quota handshake；不读取 prompt、对话标题、文件内容或 Gmail 内容。

## 结论

- 本机 Codex 路径：ChatGPT.app 内嵌 executable。
- 版本：`codex-cli 0.147.0-alpha.6.5`。
- `codex app-server` 明确标记为 `[experimental]`。
- 默认 transport：`stdio://`；本轮只测试 stdio，不开放 WebSocket / Unix listener。
- 当前 reader 显式使用 `codex app-server --listen stdio://`，并按当前 schema 发送带空 `params` 的 `initialized` notification。
- `initialize` 在 `experimentalApi=false` 下成功。
- `account/rateLimits/read` 成功，并返回多个 limit bucket。
- Reader 先等待 `initialize` 成功，再发送 `initialized` 与 rate-limit read；不再把握手请求一次性预写入 stdin。
- Parser 同时支持 `rateLimitsByLimitId` 多 bucket 与 schema 标注的 backward-compatible `rateLimits` 单 bucket 视图。
- 实际 quota 数值、plan、credit 和账号信息未写入项目文件；验证输出只记录 bucket 数量。
- 当前 schema 包含 `account/rateLimits/read`、`account/usage/read`、`account/rateLimits/updated`、`thread/status/changed` 和 approval / input request 结构。
- 未发现可据此承诺“自动枚举 ChatGPT Scheduled / Gmail 运行状态”的公开 companion method；schema 内 `scheduledTasks` 字段属于 plugin metadata，不等于 ChatGPT Scheduled 管理 API。

## Schema evidence

- 非 experimental schema SHA-256：`98a02e7ed08e78a1b1b878eb3b6d5a82e723cff8218fa30b337f120b5e855d87`
- V2 schema SHA-256：`7d79fe309dd7520843459070f3884ecf0e39cee2620c1c49aad6efb4eca76ecb`
- 生成命令：`codex app-server generate-json-schema --out <temporary-directory>`。
- 临时 schema 未复制进产品仓库，避免把版本生成物当稳定 API source of truth。

## 产品判定

| Capability | 本机 probe | 产品状态 |
|---|---|---|
| App Server initialize | Pass | Technical Preview |
| Codex rate limits read | Pass | 可在用户主动触发后展示，必须带 source、window、reset、freshness |
| Multiple limit buckets | Pass | UI 不得假定只有一个 5 小时窗口 |
| Account usage | Schema present，未读取 | Capability-gated |
| Thread status events | Schema present，跨客户端 visibility 未验证 | Gate A |
| Approval / user input | Schema present，ownership 未验证 | Gate A / B |
| External exact return | 未验证 | 不承诺；使用 WorkPulse detail / manual URL fallback |
| ChatGPT Scheduled health | 无可信 public companion method | Unsupported，保留 Manual Pin |
| Gmail count/content | 无数据源且无授权 | Unsupported |

## 安全边界

- Probe 使用 `Process.executableURL` 与 arguments array，不通过 shell 拼接。
- 不执行 login、logout、credit consume、approval、thread resume 或任何写方法。
- App Server stderr 被持续 drain 以避免 pipe backpressure，但不持久化；quota probe 只解析允许字段。
- UI 明确标记 **Technical Preview**。
- 生产接入前仍需 current + previous version fixture、Gate A/B/C 与版本 schema hash 审核。
