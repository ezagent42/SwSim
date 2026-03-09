# 002 — Socialware 契约文件规范 (.socialware.md)

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 概述

`.socialware.md` 是 Socialware 的**模板契约文件**。它用 Markdown 格式定义一个完整的组织结构——四原语（Role / Flow / Commitment / Arena）及其 Context Bindings。

模板是**只读产品**：创建后不修改，可分发、可复用。App Dev 阶段会复制模板并绑定具体的 Identity 和 Tool，生成 `.app.md`。

---

## 2. 文件扩展名与状态

| 属性 | 值 |
|------|-----|
| 文件扩展名 | `.socialware.md` |
| 存储位置 | `simulation/contracts/` |
| Status 字段 | 始终为 `模板` |
| 性质 | 只读，创建后不修改 |

---

## 3. Header Metadata

每个 `.socialware.md` 文件以 YAML-style 元数据开头：

```markdown
# {Socialware 名称}

> **类型**：Socialware 契约模板
> **状态**：模板
> **创建者**：{creator}
> **日期**：{YYYY-MM-DD}
> **引用**：{相关文档或规范的链接，可选}
> **描述**：{一句话描述这个 Socialware 的用途}
```

---

## 4. §1 Roles — 角色定义

角色表定义组织中的所有位置。模板中 holder 始终为 `_待绑定_`。

### 4.1 格式

```markdown
## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | {角色名} | {能力列表，逗号分隔} | _待绑定_ |
| R2 | {角色名} | {能力列表，逗号分隔} | _待绑定_ |
```

### 4.2 规则

- **ID**：唯一标识符，格式 `R{n}`（R1, R2, R3...）
- **名称**：人类可读的角色名（如「提交者」「审批者」「观察者」）
- **Capabilities**：该角色拥有的能力，用于 CBAC 检查（如 `submit`, `approve`, `view`）
- **Holder**：模板中始终为 `_待绑定_`，App Dev 阶段绑定为具体 Identity

### 4.3 Atom 地址

```
{contract}://roles/{ID}
```

示例：`two-role-submit-approve://roles/R1`

---

## 5. §2 Flows — 工作流定义

Flow 是状态机，定义 action 如何推进状态。

### 5.1 格式

```markdown
## §2 Flows

### Flow: {flow_name}

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | {subject_action} | {state} | R{n} | any |
| {state} | {action} | {state} | R{n} | {cbac} |
| {state} | {action} | {state} | R{n} | {cbac} |
```

### 5.2 规则

- **Current State**：`_none_` 表示 flow instance 尚未创建
- **Action**：动作名（如 `submit`, `approve`, `reject`, `revise`）
- **Next State**：执行 action 后的目标状态
- **Required Role**：执行此 action 需要的角色 ID
- **CBAC**：Capability-Based Access Control 约束

### 5.3 Subject Action

**第一个 action（Current State = `_none_`）是 subject action**——它创建一个 flow instance。Subject action 的执行者被记录为 `subject_author`，后续 CBAC 中的 `author` 指的就是这个人。

### 5.4 CBAC 类型

| CBAC 值 | 含义 | 验证逻辑 |
|---------|------|---------|
| `any` | 任何持有 required_role 的人 | 仅检查角色 |
| `author` | 仅 flow instance 的创建者 | 检查角色 + 验证 subject_author 身份 |
| `author \| role:{R}` | 创建者 OR 指定管理角色 | 检查角色 + (subject_author OR 持有 R) |

### 5.5 Author 验证

`author` CBAC 的验证过程：

1. 从当前消息的 `reply_to` 链向上追溯
2. 找到 subject message（创建 flow instance 的消息）
3. 比较 subject message 的 author 与当前操作者
4. 如果匹配，允许操作；否则拒绝

### 5.6 Atom 地址

```
{contract}://flows/{flow_name}/{state}
```

示例：`two-role-submit-approve://flows/task_lifecycle/submitted`

---

## 6. §3 Commitments — 承诺定义

Commitment 定义角色间的可追踪义务。

### 6.1 格式

```markdown
## §3 Commitments

| ID | 当事方 | 义务 | 触发条件 | 截止时间 |
|----|--------|------|---------|---------|
| C1 | R{n} → R{m} | {义务描述} | {触发 flow state} | {deadline 描述} |
```

### 6.2 规则

- **ID**：唯一标识符，格式 `C{n}`
- **当事方**：`R{a} → R{b}` 表示 R{a} 对 R{b} 承担义务
- **义务**：具体的责任描述
- **触发条件**：关联的 flow state，当进入该状态时触发
- **截止时间**：可以是相对时间（如「触发后 24h」）或绝对时间

### 6.3 Atom 地址

```
{contract}://commitments/{ID}
```

---

## 7. §4 Arena — 准入策略

Arena 定义谁可以进入这个组织。

### 7.1 格式

```markdown
## §4 Arena

| 属性 | 值 |
|------|-----|
| 准入策略 | {role_based / anyone / invite_only} |
| 准入条件 | {具体条件描述} |
```

### 7.2 准入策略类型

| 策略 | 含义 |
|------|------|
| `role_based` | 必须被分配角色才能进入 |
| `anyone` | 任何人可以进入 |
| `invite_only` | 需要现有成员邀请 |

---

## 8. §5 Context Bindings — 上下文绑定

Context Bindings 定义每个 action 的执行细节。模板中所有绑定为 `_待绑定_`。

### 8.1 格式

```markdown
## §5 Context Bindings

### Action: {flow_name}.{action}

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |
| 输入 (Input) | _待绑定_ |
| 输出 (Output) | _待绑定_ |
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | {_待绑定_ 或 _无_} |
| 委托 (Delegates) | {_待绑定_ 或 _无_} |
| 资源 (Requests) | {_待绑定_ 或 _无_} |
```

### 8.2 `_待绑定_` vs `_无_` 的关键区分

这是模板设计中最重要的区分：

| 值 | 含义 | 场景 |
|----|------|------|
| `_待绑定_` | 设计层面存在抽象依赖，App Dev 阶段需要绑定具体引用 | 设计声明了「此 action 依赖另一个 flow 的状态」 |
| `_无_` | 完全没有依赖 | 设计层面就不存在任何依赖 |

**示例**：
- 「审批 action 需要检查提交状态」→ 依赖 (Requires) = `_待绑定_`（有依赖，但具体引用在 App Dev 时绑定）
- 「提交 action 不依赖任何外部状态」→ 依赖 (Requires) = `_无_`（没有依赖）

### 8.3 引用语法（Reference Syntax）

三种跨契约引用类型：

| 类型 | 语法 | 含义 |
|------|------|------|
| **Requires** | `[ns:flow.state](path)` | Flow state 依赖——当前 action 需要检查另一个 flow 的状态 |
| **Delegates** | `[ns:role](path)` | 角色委托——当前 action 委托另一个角色执行 |
| **Requests** | `[ns:arena.resource](path)` | 资源请求——当前 action 需要另一个 arena 的资源 |

模板中这些引用全部为 `_待绑定_`，App Dev 时填入具体路径。

---

## 9. Atom Addressing — 原子寻址

每个 Socialware 中的实体都有唯一的 Atom 地址：

```
{contract}://roles/{ID}
{contract}://flows/{flow_name}/{state}
{contract}://commitments/{ID}
{contract}://arena
{contract}://bindings/{flow_name}.{action}
```

Atom 地址用于：
- 跨契约引用（Requires / Delegates / Requests）
- 日志和调试中定位实体
- State 中记录 flow instance 的来源

---

## 10. 完整示例

```markdown
# 双角色提交-审批

> **类型**：Socialware 契约模板
> **状态**：模板
> **创建者**：Allen
> **日期**：2026-03-09
> **描述**：最简单的双角色工作流——一方提交，一方审批

## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 提交者 | submit, revise | _待绑定_ |
| R2 | 审批者 | approve, reject | _待绑定_ |

## §2 Flows

### Flow: task_lifecycle

| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | submit | submitted | R1 | any |
| submitted | approve | approved | R2 | any |
| submitted | reject | rejected | R2 | any |
| rejected | revise | submitted | R1 | author |
| approved | _none_ | _终态_ | — | — |

## §3 Commitments

| ID | 当事方 | 义务 | 触发条件 | 截止时间 |
|----|--------|------|---------|---------|
| C1 | R2 → R1 | 审批者必须在截止时间前做出审批决定 | task_lifecycle.submitted | 触发后 48h |

## §4 Arena

| 属性 | 值 |
|------|-----|
| 准入策略 | role_based |
| 准入条件 | 必须被分配 R1 或 R2 角色 |

## §5 Context Bindings

### Action: task_lifecycle.submit

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |
| 输入 (Input) | _待绑定_ |
| 输出 (Output) | _待绑定_ |
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.approve

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |
| 输入 (Input) | _待绑定_ |
| 输出 (Output) | _待绑定_ |
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | _待绑定_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.reject

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |
| 输入 (Input) | _待绑定_ |
| 输出 (Output) | _待绑定_ |
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | _待绑定_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.revise

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |
| 输入 (Input) | _待绑定_ |
| 输出 (Output) | _待绑定_ |
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |
```
