# Socialware 契约文件格式规范

## 概述

Socialware 契约文件是一份 Markdown 文档，定义一个组织的完整结构。它既是人类可读的设计文档，也是 Skill Runtime 可解析的可执行契约。

本规范定义三个阶段的文件格式：**模板**（`.socialware.md`）、**已开发 App**（`app-store/{app-id}.app.md`）、**已安装实例**（`rooms/{room}/socialware-app/{app-id}.app.md`）。

## 文件命名

- 模板: `{descriptive-name}.socialware.md`（如 `two-role-submit-approve.socialware.md`）
- 已开发 App: `{app-id}.app.md`（如 `doc-review.alice.two-role-submit-approve.app.md`），app-id 格式为 `{AppName}.{DeveloperName}.{SocialwareName}`
- 已安装实例: 与 app-store 中同名，复制到 Room 的 `socialware-app/` 目录
- 名称解耦: 模板名 ≠ AppName ≠ namespace，由用户在各阶段独立选择

## 身份格式

两种格式：

| 类型 | 格式 | 示例 |
|------|------|------|
| 人类用户 | `{username}@{namespace}` | `alice@local` |
| Agent Session | `{username}:{session-name}@{namespace}` | `alice:ppt-maker@local` |

- `session-name` 是 Claude Code（或其它 Agent）的 session 名称，由创建者命名（如 `ppt-maker`、`code-reviewer`）
- 同一个 `username` 可以拥有多个 Agent Session（`alice:ppt-maker@local`、`alice:code-reviewer@local`）
- `namespace` 默认为 `local`（本地模拟），也可以是网络名称（如 `onesyn`）
- 无 `@` 前缀——`@` 仅作 `username(:session-name)` 和 `namespace` 的分隔符
- **文件名**: `identities/{username}@{namespace}.json`——省略 session-name（避免 `:` 在 Windows/WSL 路径问题），JSON 内 `entity_id` 使用完整格式

## 必需章节

### 头部元信息

**模板阶段**（`.socialware.md`）:
```markdown
# {filename}.socialware.md

> 状态: 模板
> 开发者: {username}:{nickname}@{namespace}

{一句话描述}
```

**已开发阶段**（`app-store/{app-id}.app.md`）:
```markdown
# {app-id}.app.md

> 状态: 已开发
> App-ID: {app-id}
> 基于模板: {template_name}.socialware.md
> 开发者: {username}:{nickname}@{namespace}

{一句话描述}
```

**已安装阶段**（`rooms/{room}/socialware-app/{app-id}.app.md`）:
```markdown
# {app-id}.app.md

> 状态: 已安装
> App-ID: {app-id}
> 基于模板: {template_name}.socialware.md
> 开发者: {username}:{nickname}@{namespace}
> 安装者: {username}:{nickname}@{namespace}
> Namespace: {ns}
> Room: {room_name}

{一句话描述}
```

- **开发者/安装者**: 必填，由各阶段操作者的当前身份自动填入
- **前置条件**: 操作者必须先在 `workspace/identities/` 中拥有身份

### §1 Roles

定义组织中的角色。每个角色是一个可寻址的原子。

```markdown
## §1 Roles

| R-ID | 名称 | 能力 | 持有者 |
|------|------|------|--------|
| R1 | {name} | {cap1}, {cap2} | _待绑定_ 或 {username}:{nickname}@{namespace} |
```

- **R-ID**: 本契约内唯一标识（R1, R2, ...）
- **能力**: 该角色可触发的动作名列表
- **持有者**: `_待绑定_`（模板和已开发阶段）或具体 Identity（安装后）

### §2 Flows

定义状态机。每个 Flow 是一个可寻址的原子。一个契约可以包含多个 Flow。

```markdown
## §2 Flows

### Flow: {flow_name}

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|---------|------|---------|---------|---------|
| {state} | {action} | {next_state} | {role_id} | any 或 author 或 author | role:{R} |
```

- 每个 Flow 有一个 `subject` 动作（创建 Flow 实例的第一个动作）
- subject 动作的「当前状态」写 `_none_`，表示 Flow 实例尚不存在，由该动作创建
- **要求角色**列使用 R-ID（`R1`, `R2`），不使用角色名称
- **能力约束**列只允许三种值：`any` / `author` / `author | role:{R}`
- **能力约束**（CBAC — Capability-Based Access Control）：
  - `any`（默认）：持有角色即可
  - `author`：只有该 Flow 实例的创建者（subject 动作的 author）
  - `author | role:{R}`：创建者 OR 持有指定角色（admin override）
  - 验证方式：沿 `reply_to` 链回溯到 subject 消息，比对 `author` 字段

### §3 Commitments

定义契约义务。Commitment 是有方向的：债务人（debtor）对债权人（creditor）承担义务。承诺描述必须具体可衡量。

```markdown
## §3 Commitments

| C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限 |
|------|------|--------|--------|---------|------|
| C1 | {具体可衡量的义务描述} | {R_debtor} | {R_creditor} | {trigger_action} | {deadline} 或 _待绑定_ |
```

- **C-ID**: 本契约内唯一标识（C1, C2, ...）
- **承诺**: 必须包含 `{动作} + {量化指标} + {条件}`，如 `在提交后 24 小时内完成审批（approve 或 reject）`
- **债务人**: 承担义务的角色（R-ID）
- **债权人**: 享有权利的角色（R-ID）
- **时限**: 模板阶段可用 `_待绑定_`，App Dev 阶段填入具体值（如 `24h`、`ongoing`）

### §4 Arena

定义参与边界。

```markdown
## §4 Arena

- 进入策略: {policy_expression}
- 最小参与者: {number}
```

Policy 表达式示例：
- `invite-only`（仅邀请）
- `open`（公开加入）
- `持有 R1/R2/R3 任一角色`

### §5 Context Bindings

**模板阶段全部为 `_待实现_`（等待 App Dev 填入工具）。**

```markdown
## §5 Context Bindings

### on: {action}
- 前置: {role} [+ 状态={state}]
- 工具: _待实现_ 或 `bash: ...` 或 `mcp: ...` 或 `api: ...` 或 `manual` 或 `llm: ...`
- 输入: _待实现_ 或 {description}
- 输出: _待实现_ 或 {description}
- 消息模板: _待实现_ 或 "{emoji} {author} {description}"
- 依赖: _待实现_ 或 _无_ 或 [{ns}:{flow} {state}](同 Room)
- 委托: _待实现_ 或 _无_ 或 [{ns}:{role}](同 Room)
- 资源: _待实现_ 或 _无_ 或 [{ns}:{arena}](同 Room)
```

**三种占位符的区分**:
- `_待实现_`: §5 工具层，等待 App Dev 填入具体工具实现
- `_待绑定_`: §1 持有者，等待 App Install 填入具体用户
- `_无_`: 确实不存在该类型的依赖（设计决策）

### §6 模拟环境（App Install 阶段填入）

```markdown
## §6 模拟环境

| 项 | 值 |
|----|-----|
| workspace | simulation/workspace/rooms/{room}/ |
| 身份模拟 | 当前用户 = {username}:{nickname}@{namespace} |
| P2P 模拟 | 多会话（每 session 一个 peer）或单节点（/switch） |
| 消息持久化 | timeline/{shard}.jsonl（append-only） |
| 状态派生 | state.json（可从 timeline 重建） |
| 消息输出 | 终端打印 |
```

## 引用语法

契约之间通过 namespace 引用（同 Room 内）：

```markdown
[{ns}:{flow} {state}](同 Room, namespace={ns})
```

三种引用关系：

| 关系 | 含义 | 示例 |
|------|------|------|
| requires | 依赖对方的 Flow 状态 | `依赖: [ta:task_lifecycle committed](同 Room, namespace=ta)` |
| delegates | 委托对方的 Role 执行 | `委托: [ta:reviewer](同 Room, namespace=ta)` |
| requests | 请求对方的 Arena 资源 | `资源: [rp:resource_pool](同 Room, namespace=rp)` |

## 原子寻址

每个原子有唯一地址（namespace 作用域内）：

```
{ns}://roles/{role_id}
{ns}://flows/{flow_name}/{state}
{ns}://commitments/{commitment_id}
{ns}://arenas/{arena_name}
{ns}://bindings/on:{action}
```
