# EventWeaver — 文件级事件溯源

> 状态: 模板
> 开发者: allen:Allen@local

基于 P2P 自动分支的文件级事件溯源系统——记录一切文件事件，权限驱动自动分支，支持线性与非线性事件消费。

核心原则：
- 所有写操作本地成功，同步时按权限决定主线或分支
- 分支创建者即分支 block 的 owner（递归适用）
- 一切变更记录为不可变事件（EAVT 模型）
- 状态可从事件完整重建

## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 管理员 | track, write, read, link, unlink, grant, revoke, diverge, accept, reject, force_resolve, history, branches, query, archive | _待绑定_ |
| R2 | 参与者 | track, write, read, link, unlink, grant, revoke, diverge, accept, reject, history, branches, query, archive | _待绑定_ |
| R3 | 审计者 | read, history, branches, query | _待绑定_ |

**说明**：
- R1/R2/R3 定义的是**使用 EventWeaver 动作的组织资格**，不涉及文件级权限
- 文件级的所有权（owner）和合并权限（grant/revoke）由工具内部 CBAC 管理
- 创建 block 的人自动成为该 block 的 owner，这是运行时状态，不是 Role
- R1 比 R2 多 `force_resolve`：当 owner 不响应时，管理员可强制处理分支

## §2 Flows

### Flow: branch_review

分支审查流程——当 P2P 同步检测到无权限写入时，系统自动创建分支并触发此流程。

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | diverge | pending | R2 | any |
| pending | accept | merged | R2 | any |
| pending | reject | discarded | R2 | any |
| pending | force_resolve | merged | R1 | any |
| merged | _none_ | _终态_ | — | — |
| discarded | _none_ | _终态_ | — | — |

**流程说明**：
- `diverge`：同步时系统检测到写入者无目标 block 的 grant → 自动创建分支 → 归因于写入者
- `accept`/`reject`：由父 block 的 owner 执行（工具内部验证所有权，非 CBAC 层）
- `force_resolve`：管理员强制合并（当 owner 超时未响应，触发 C2）
- 分支本身是一个 block，分支创建者是其 owner（递归适用同样的分支逻辑）

### Flow: access_change

权限变更流程——block owner 授予或撤销其他参与者对 block 的合并权限。

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | grant | active | R2 | any |
| active | revoke | revoked | R2 | any |
| revoked | _none_ | _终态_ | — | — |

**流程说明**：
- `grant`：owner 授予某参与者对特定 block 的合并权限（未来该参与者的写入可 auto-merge）
- `revoke`：owner 撤销已授予的合并权限
- 工具内部验证：只有 block owner 能 grant/revoke 自己 block 的权限

**非 Flow 操作**（直接工具调用，不经过状态机）：

以下操作由参与者直接调用工具执行，产生 EventWeaver 事件但不创建 Flow instance：

| 操作 | 说明 | 所需 Role |
|------|------|-----------|
| track | 开始追踪文件，创建 block（调用者成为 owner） | R2 |
| write | 写入 block 内容（有 grant→主线，无 grant→分支） | R2 |
| read | 读取 block 当前状态 | R3 |
| link | 添加 block 间的 DAG 关系（implement） | R2 |
| unlink | 移除 block 间的 DAG 关系 | R2 |
| history | 查看 block 的完整事件历史 | R3 |
| branches | 查看 block 的所有分支 | R3 |
| query | 结构化查询事件（按作者、时间、关系等） | R3 |
| archive | 软删除 block（owner-only，工具内部验证） | R2 |

## §3 Commitments

| ID | 当事方 | 义务 | 触发条件 | 截止时间 |
|----|--------|------|---------|---------|
| C1 | R2 → R2 | 父 block 所有者必须审查 pending 分支（accept 或 reject） | branch_review.pending | 触发后 72h |
| C2 | R1 → R2 | 若 C1 超时，管理员应 force_resolve 处理滞留分支 | C1 violated | 触发后 24h |
| C3 | R2 → R3 | 所有事件记录对审计者可查询（工具层面保证） | 系统运行时 | 持续 |

## §4 Arena

- 进入策略: role_based
- 最小参与者: 1

**说明**：
- 最小 1 人即可运行（单人文件追踪场景）
- 多人场景下，参与者通过 Room 成员身份获得 R2，审计者获得 R3
- R1 通常由 Room owner 或指定管理员持有

## §5 Context Bindings

### on: diverge

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: accept

- 前置: R2 + 状态=pending
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: reject

- 前置: R2 + 状态=pending
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: force_resolve

- 前置: R1 + 状态=pending
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _待实现_
- 委托: _无_
- 资源: _待实现_

### on: grant

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: revoke

- 前置: R2 + 状态=active
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: track

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: write

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: read

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: link

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: unlink

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: history

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: branches

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: query

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: archive

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_
