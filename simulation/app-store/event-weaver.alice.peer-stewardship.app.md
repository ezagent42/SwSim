# event-weaver.alice.peer-stewardship

> 状态: 已开发
> App-ID: event-weaver.alice.peer-stewardship
> 基于模板: peer-stewardship.socialware.md
> 开发者: alice:Alice@local

文件级事件溯源 App——基于 peer-stewardship 组织模式，记录一切文件变更事件，权限驱动自动分叉，支持线性与非线性事件消费。

---

## §1 Roles

| R-ID | 名称 | 能力 | 持有者 |
|------|------|------|--------|
| R1 | 管理员 | create, contribute, view, relate, unrelate, grant, revoke, diverge, accept, reject, force_resolve, audit, list_forks, query, archive | _待绑定_ |
| R2 | 参与者 | create, contribute, view, relate, unrelate, grant, revoke, diverge, accept, reject, audit, list_forks, query, archive | _待绑定_ |
| R3 | 审计者 | view, audit, list_forks, query | _待绑定_ |

**备注**：管家（steward）是运行时状态，不是 Role。创建产出物的人自动成为该产出物的管家。R1 比 R2 多 `force_resolve`。R2 之间的关系是对等的——每个人既是自己产出物的管家，又是他人产出物的潜在贡献者。

---

## §2 Flows

### F1: 分叉审查 (diverge-review)

同步检测到无授信的贡献时，系统自动创建分叉并触发此流程。

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|----------|------|----------|----------|----------|
| _none_ | diverge | pending | R2 | any |
| pending | accept | merged | R2 | any |
| pending | reject | discarded | R2 | any |
| pending | force_resolve | merged | R1 | any |

- `diverge`：同步时系统检测到贡献者无目标产出物的 grant → 自动创建分叉 → 归因于贡献者
- `accept`/`reject`：由父产出物的管家执行（工具内部验证所有权，非 CBAC 层）
- `force_resolve`：管理员强制合并（当管家超时未响应，触发 C2）
- 分叉本身是一个产出物，分叉创建者是其管家（递归适用同样的分叉逻辑）

### F2: 信任变更 (trust-change)

管家授予或撤销其他参与者对产出物的合并权限。

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|----------|------|----------|----------|----------|
| _none_ | grant | trusted | R2 | any |
| trusted | revoke | revoked | R2 | any |

- `grant`：管家授予某参与者对特定产出物的合并权限（未来该参与者的贡献可 auto-merge）
- `revoke`：管家撤销已授予的合并权限
- 工具内部验证：只有产出物的管家能 grant/revoke

### 直接工具操作（不经状态机）

| 操作 | 说明 | 所需 Role |
|------|------|-----------|
| create | 创建新产出物（调用者成为管家） | R2 |
| contribute | 向产出物贡献内容（有 grant→主线，无 grant→分叉） | R2 |
| view | 查看产出物当前状态 | R3 |
| relate | 添加产出物间的因果关系 | R2 |
| unrelate | 移除产出物间的因果关系 | R2 |
| audit | 查看产出物的完整事件历史 | R3 |
| list_forks | 查看产出物的所有分叉 | R3 |
| query | 结构化查询事件（按作者、时间、关系等） | R3 |
| archive | 归档产出物（管家-only，工具内部验证） | R2 |

---

## §3 Commitments

| C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限 |
|------|------|--------|--------|----------|------|
| C1 | 管家在分叉进入 pending 后 72h 内完成审查（accept 或 reject） | R2 | R2 | fork_review.pending | 触发后 72h |
| C2 | 若 C1 超时未履行，管理员在 24h 内 force_resolve 处理滞留分叉 | R1 | R2 | C1 violated | 触发后 24h |
| C3 | 所有事件记录持续对审计者可查询（工具层面保证） | R2 | R3 | 系统运行时 | 持续 |

---

## §4 Arena

- **最小参与者**: 1 人
- **进入策略**: 基于 Room 成员身份，R2 分配给参与者，R3 分配给审计者，R1 由 Room owner 或指定管理员持有

---

## §5 Context Bindings

### on: diverge
- 前置: R2
- 工具: mcp: ew-server/diverge
- 输入: block_id（目标产出物）、event_data（触发分叉的写入事件）
- 输出: fork_id（新分叉 ID）、fork_review flow instance ID
- 消息模板: "{author} 对 {block_name} 的贡献已自动分叉为 {fork_id}（无合并权限），请管家审查"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: accept
- 前置: R2 [+ 状态=pending]
- 工具: mcp: ew-server/accept
- 输入: fork_id（分叉 ID）、comment（可选审查意见）
- 输出: merge_result（合并结果）、event_id
- 消息模板: "{author} 接受了 {fork_id} 的分叉，已合入 {block_name} 主线"
- 依赖: _无_
- 委托: [ta:R2](同 Room) — 合并完成后通知关联任务的审批者
- 资源: [rp:arena.storage](同 Room) — 合并后更新 RePool 中的文件存储

### on: reject
- 前置: R2 [+ 状态=pending]
- 工具: mcp: ew-server/reject
- 输入: fork_id（分叉 ID）、reason（拒绝原因）
- 输出: event_id
- 消息模板: "{author} 拒绝了 {fork_id} 的分叉: {reason}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: force_resolve
- 前置: R1 [+ 状态=pending]
- 工具: mcp: ew-server/force_resolve
- 输入: fork_id（分叉 ID）、strategy（accept 或 reject）、reason（管理员说明）
- 输出: event_id、result（merged 或 discarded）
- 消息模板: "管理员 {author} 强制处理了 {fork_id}: {strategy}（{reason}）"
- 依赖: [ew:diverge-review.pending](同 Room) — 确认分叉仍在 pending 状态
- 委托: _无_
- 资源: [rp:arena.storage](同 Room) — 若 strategy=accept，更新 RePool 文件存储

### on: grant
- 前置: R2
- 工具: mcp: ew-server/grant
- 输入: block_id（目标产出物）、target_identity（被授权者）、capability（可选，默认 contribute）
- 输出: event_id、trust_change flow instance ID
- 消息模板: "{author} 授予 {target} 对 {block_name} 的合并权限"
- 依赖: [af:agent.active](同 Room) — 验证 target_identity 是有效的 Agent/身份
- 委托: _无_
- 资源: _无_

### on: revoke
- 前置: R2 [+ 状态=trusted]
- 工具: mcp: ew-server/revoke
- 输入: block_id（目标产出物）、target_identity（被撤权者）
- 输出: event_id
- 消息模板: "{author} 撤销了 {target} 对 {block_name} 的合并权限"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: create
- 前置: R2
- 工具: mcp: ew-server/create
- 输入: name（产出物名称）、block_type（document / session / ref）、content（可选初始内容）、description（可选描述）
- 输出: block_id、event_id
- 消息模板: "{author} 创建了产出物 {name} ({block_type})，已开始追踪"
- 依赖: [ta:task_lifecycle.submitted](同 Room) — 可选，关联到触发创建的任务
- 委托: _无_
- 资源: [rp:arena.storage](同 Room) — 为产出物分配存储空间

### on: contribute
- 前置: R2
- 工具: mcp: ew-server/contribute
- 输入: block_id（目标产出物）、content（贡献内容，格式由 plugin 定义）
- 输出: event_id、mode（delta/full/append/ref）、fork_id（如果产生分叉则非空）
- 消息模板: "{author} 向 {block_name} 贡献了内容 ({mode}, +{additions}-{deletions})"
- 依赖: _无_
- 委托: _无_
- 资源: [rp:arena.storage](同 Room) — 更新 RePool 中的文件内容

### on: view
- 前置: R3
- 工具: mcp: ew-server/view
- 输入: block_id（目标产出物）
- 输出: block 完整状态（内容、元数据、管家、grant 列表）
- 消息模板: _无_
- 依赖: _无_
- 委托: _无_
- 资源: [rp:arena.storage](同 Room) — 读取 RePool 中的文件内容

### on: relate
- 前置: R2
- 工具: mcp: ew-server/relate
- 输入: parent_id（父产出物）、child_id（子产出物）、relation（默认 implement）
- 输出: event_id
- 消息模板: "{author} 添加了因果关系: {parent_name} → {child_name} ({relation})"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: unrelate
- 前置: R2
- 工具: mcp: ew-server/unrelate
- 输入: parent_id（父产出物）、child_id（子产出物）、relation
- 输出: event_id
- 消息模板: "{author} 移除了因果关系: {parent_name} → {child_name}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: audit
- 前置: R3
- 工具: mcp: ew-server/audit
- 输入: block_id（目标产出物）、limit（可选返回条数）、from/to（可选事件范围）
- 输出: events（事件列表）、total（总数）
- 消息模板: _无_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: list_forks
- 前置: R3
- 工具: mcp: ew-server/list_forks
- 输入: block_id（目标产出物）
- 输出: forks（分叉列表：fork_id、作者、状态、事件数）
- 消息模板: _无_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: query
- 前置: R3
- 工具: mcp: ew-server/query
- 输入: filter（author、block_type、time_range、related_to、has_forks）、limit、offset
- 输出: results（匹配的 block 或 event 列表）、total
- 消息模板: _无_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: archive
- 前置: R2
- 工具: mcp: ew-server/archive
- 输入: block_id（目标产出物）
- 输出: event_id
- 消息模板: "{author} 归档了产出物 {block_name}"
- 依赖: _无_
- 委托: [rp:R1](同 Room) — 委托 RePool 管理员释放关联的存储资源
- 资源: _无_
