# 对等管家制

> 状态: 模板
> 开发者: allen:Allen@local

扁平对等的协作组织——创建即拥有，贡献自由但合并受控，信任关系动态变化。

核心原则：
- 参与者创建产出物后自动成为其管家（steward）
- 所有贡献本地成功，同步时按信任关系决定合入主线或自动分叉
- 分叉创建者即该分叉的管家（递归适用）
- 一切变更记录为不可变事件，状态可从事件完整重建

图结构：
- 节点：参与者（●）、产出物（■）、分叉（◆）
- 边：owns（创建时产生）、granted（授信）、forks_from（自动分叉）、relates（因果关联）
- 拓扑：动态信任网络，grant/revoke 改变边，参与者同时是管家和贡献者

## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 管理员 | create, contribute, view, relate, unrelate, grant, revoke, diverge, accept, reject, force_resolve, audit, list_forks, query, archive | _待绑定_ |
| R2 | 参与者 | create, contribute, view, relate, unrelate, grant, revoke, diverge, accept, reject, audit, list_forks, query, archive | _待绑定_ |
| R3 | 审计者 | view, audit, list_forks, query | _待绑定_ |

**说明**：
- R1/R2/R3 定义的是**使用本组织动作的资格**，不涉及产出物级别的权限
- 产出物级别的所有权（owner）和合并权限（grant/revoke）由工具内部管理
- 创建产出物的人自动成为该产出物的管家，这是运行时状态，不是 Role
- R1 比 R2 多 `force_resolve`：当管家不响应时，管理员可强制处理滞留分叉
- R2 之间的关系是**对等的**——每个人既是自己产出物的管家，又是他人产出物的潜在贡献者

## §2 Flows

### Flow: fork_review

分叉审查流程——当同步检测到无授信的贡献时，系统自动创建分叉并触发此流程。

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | diverge | pending | R2 | any |
| pending | accept | merged | R2 | any |
| pending | reject | discarded | R2 | any |
| pending | force_resolve | merged | R1 | any |
| merged | _none_ | _终态_ | — | — |
| discarded | _none_ | _终态_ | — | — |

**流程说明**：
- `diverge`：同步时系统检测到贡献者无目标产出物的 grant → 自动创建分叉 → 归因于贡献者
- `accept`/`reject`：由父产出物的管家执行（工具内部验证所有权，非 CBAC 层）
- `force_resolve`：管理员强制合并（当管家超时未响应，触发 C2）
- 分叉本身是一个产出物，分叉创建者是其管家（递归适用同样的分叉逻辑）

### Flow: trust_change

信任变更流程——管家授予或撤销其他参与者对产出物的合并权限。

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | grant | trusted | R2 | any |
| trusted | revoke | revoked | R2 | any |
| revoked | _none_ | _终态_ | — | — |

**流程说明**：
- `grant`：管家授予某参与者对特定产出物的合并权限（未来该参与者的贡献可 auto-merge）
- `revoke`：管家撤销已授予的合并权限
- 工具内部验证：只有产出物的管家能 grant/revoke

**非 Flow 操作**（直接工具调用，不经过状态机）：

以下操作由参与者直接调用工具执行，不创建 Flow instance：

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

## §3 Commitments

| ID | 当事方 | 义务 | 触发条件 | 截止时间 |
|----|--------|------|---------|---------|
| C1 | R2 → R2 | 管家必须审查 pending 分叉（accept 或 reject） | fork_review.pending | 触发后 72h |
| C2 | R1 → R2 | 若 C1 超时，管理员应 force_resolve 处理滞留分叉 | C1 violated | 触发后 24h |
| C3 | R2 → R3 | 所有事件记录对审计者可查询（工具层面保证） | 系统运行时 | 持续 |

## §4 Arena

- 进入策略: role_based
- 最小参与者: 1

**说明**：
- 最小 1 人即可运行（单人场景）
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

- 前置: R2 + 状态=trusted
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: create

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: contribute

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _待实现_

### on: view

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: relate

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: unrelate

- 前置: R2
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: audit

- 前置: R3
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: list_forks

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
