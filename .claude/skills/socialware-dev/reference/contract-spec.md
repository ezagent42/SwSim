# Socialware 契约文件格式规范

## 概述

Socialware 契约文件是一份 Markdown 文档，定义一个组织的完整结构。它既是人类可读的设计文档，也是 Skill Runtime 可解析的可执行契约。

本规范定义**模板**（`.socialware.md`）和**绑定副本**（`.app.md`）的共同格式。

## 文件命名

- 模板: `{descriptive-name}.socialware.md`（如 `two-role-submit-approve.socialware.md`）
- 绑定副本: `{namespace}.app.md`（如 `ta.app.md`）
- 名称解耦: 模板名 ≠ App 名，由用户独立选择

## 必需章节

### 头部元信息

```markdown
# {Name} — Socialware Contract

> 状态: 模板 | 已绑定 | 运行中
> 创建者: {who}
> 创建日期: {YYYY-MM-DD}
> 绑定者: {who}（已绑定后填写）
> Namespace: {ns}（已绑定后填写）
> 基于模板: {template_name}.socialware.md（已绑定后填写）
> 引用: [{contract}](path)（可选，列出引用的其他契约）
```

### §1 Roles

定义组织中的角色。每个角色是一个可寻址的原子。

```markdown
## §1 Roles

| ID | 名称 | 能力 | 持有者 |
|----|------|------|--------|
| R1 | {name} | {cap1}, {cap2} | _待绑定_ 或 @{entity} |
```

- **ID**: 本契约内唯一标识（R1, R2, ...）
- **能力**: 该角色可触发的动作名列表
- **持有者**: `_待绑定_`（模板阶段）或具体 Identity（绑定后）

### §2 Flows

定义状态机。每个 Flow 是一个可寻址的原子。

```markdown
## §2 Flow: {flow_name}

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

定义契约义务。

```markdown
## §3 Commitments

| ID | 双方 | 承诺 | 触发条件 | 时限 |
|----|------|------|---------|------|
| C1 | {R_a} ↔ {R_b} | {obligation} | {trigger_action} | {deadline} 或 ongoing |
```

### §4 Arena

定义参与边界。

```markdown
## §4 Arena

| 规则 | 值 |
|------|-----|
| 进入策略 | {policy_expression} |
```

Policy 表达式示例：
- `持有 R1/R2/R3 任一角色`
- `anyone`（公开）
- `invite_only`

### §5 Context Bindings

**模板阶段工具全部为 `_待绑定_`。依赖/委托/资源视设计需求填写。**

```markdown
## §5 Context Bindings

### on: {action}
- 前置: {role} [+ 状态={state}]
- 工具: _待绑定_ 或 `bash: ...` 或 `mcp: ...` 或 `api: ...` 或 `manual` 或 `llm: ...`
- 输入: _待绑定_ 或 {description}
- 输出: _待绑定_ 或 {description}
- 消息模板: _待绑定_ 或 "{emoji} @{author} {description}"
- 依赖: _待绑定_ 或 _无_ 或 [{ns}:{flow} {state}](同 Room)
- 委托: _待绑定_ 或 _无_ 或 [{ns}:{role}](同 Room)
- 资源: _待绑定_ 或 _无_ 或 [{ns}:{arena}](同 Room)
```

**`_待绑定_` vs `_无_` 的区分**:
- `_待绑定_`: 设计层声明了抽象需求，App Dev 阶段需要填入具体引用
- `_无_`: 确实不存在该类型的依赖（设计决策）

### §6 模拟环境（App Dev 阶段填入）

```markdown
## §6 模拟环境

| 项 | 值 |
|----|-----|
| workspace | simulation/workspace/rooms/{room}/ |
| 身份模拟 | 当前用户 = @{entity}:local |
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
