# 003 — Socialware App 契约文件规范 (.app.md)

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 概述

`.app.md` 是 Socialware 的**绑定契约文件**。它是模板（`.socialware.md`）的具体实例——所有 `_待绑定_` 字段已填入真实的 Identity、Tool 和跨契约引用。

`.app.md` 安装在 Room 中，为 Room 提供一个 namespace 的命令集。

---

## 2. 与模板的关系

| 属性 | 模板 (.socialware.md) | App (.app.md) |
|------|----------------------|---------------|
| 性质 | 抽象设计，只读产品 | 具体实例，可运行 |
| Holder | `_待绑定_` | 绑定为 `@alice:local` 等 |
| Tool | `_待绑定_` | 绑定为 `bash: ...` 等 |
| 引用 | `_待绑定_` 或 `_无_` | 具体路径或 `_无_` |
| Status | `模板` | `已绑定` |
| 存储 | `simulation/contracts/` | `workspace/rooms/{room}/contracts/` |

**创建流程**：App Dev 复制模板 → 填充所有 `_待绑定_` → 保存为 `.app.md`。模板保持只读。

---

## 3. 命名规则

模板名和 App 名是**解耦的**，用户独立选择：

| 层级 | 命名 | 示例 |
|------|------|------|
| 模板 | `{descriptive-name}.socialware.md` | `two-role-submit-approve.socialware.md` |
| App | `{namespace}.app.md` | `ta.app.md` |

- 模板名描述组织设计（what it is）
- App 名是 namespace 缩写（how it's called in this Room）
- 同一个模板可以在不同 Room 以不同 namespace 安装

---

## 4. 文件格式

### 4.1 Header

```markdown
# {App 名称}

> **类型**：Socialware App（已绑定）
> **状态**：已绑定
> **来源模板**：{模板文件名}
> **Namespace**：{ns}
> **Room**：{room_name}
> **绑定者**：{binder}
> **日期**：{YYYY-MM-DD}
```

### 4.2 §1 Roles — 已绑定角色

Holder 填入具体 Identity：

```markdown
## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 提交者 | submit, revise | @alice:local |
| R2 | 审批者 | approve, reject | @bob:local |
```

**Identity 格式**：`@{name}:{domain}`，模拟环境中 domain 为 `local`。

### 4.3 §2 Flows — 不变

Flow 定义从模板直接复制，不做修改。状态机是组织设计的核心，绑定阶段不改变。

### 4.4 §3 Commitments — 不变

Commitment 定义从模板直接复制。

### 4.5 §4 Arena — 不变

Arena 定义从模板直接复制。

### 4.6 §5 Context Bindings — 已绑定

所有 `_待绑定_` 字段填入具体值：

```markdown
## §5 Context Bindings

### Action: task_lifecycle.submit

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | manual |
| 输入 (Input) | 任务标题 + 描述 |
| 输出 (Output) | 任务提交确认消息 |
| 消息模板 (Message Template) | 📋 @{author} 提交了任务: {title} |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.approve

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | manual |
| 输入 (Input) | 审批意见 |
| 输出 (Output) | 审批结果通知 |
| 消息模板 (Message Template) | ✅ @{author} 审批通过: {comment} |
| 依赖 (Requires) | [ta:task_lifecycle.submitted](state.json) |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |
```

### 4.7 §6 Simulation Environment — 模拟环境配置

App 文件新增的章节，定义运行时环境：

```markdown
## §6 Simulation Environment

| 属性 | 值 |
|------|-----|
| Workspace 路径 | simulation/workspace/rooms/{room_name}/ |
| Identity 模拟 | 文件系统身份（@name:local） |
| P2P 模式 | multi-session（推荐）或 single-session |
| 持久化 | Timeline = JSONL, State = JSON |
```

---

## 5. Namespace 与 Multi-Namespace

### 5.1 Namespace 分配

每个安装到 Room 的 App 获得一个 namespace 前缀：

- Namespace 是短缩写：`ta`, `ew`, `rp`, `su`
- 同一 Room 内 namespace 不重复
- 所有命令以 `{ns}:` 为前缀：`ta:submit`, `ew:merge`

### 5.2 Multi-Namespace 共存

一个 Room 可安装多个 App，所有 namespace 的状态共存于同一个 `state.json`：

```
Room "alpha"
├── contracts/
│   ├── ta.app.md    (namespace: ta)
│   ├── ew.app.md    (namespace: ew)
│   └── rp.app.md    (namespace: rp)
├── config.json      (注册所有 namespace)
├── state.json       (合并所有 namespace 的 flow_states)
└── timeline/        (共享 timeline)
```

---

## 6. config.json 规范

`config.json` 是 Room 的配置文件，管理 Room 元数据、成员和已安装的 Socialware。

### 6.1 完整 JSON Schema

```json
{
  "room_id": "room-alpha-001",
  "name": "Alpha Team Room",
  "created_by": "@alice:local",
  "created_at": "2026-03-09T10:00:00Z",
  "membership": {
    "policy": "invite",
    "members": {
      "@alice:local": "owner",
      "@bob:local": "member"
    }
  },
  "socialware": {
    "installed": ["ta", "ew", "rp"],
    "roles": {
      "@alice:local": ["ta:poster", "ew:emitter", "ew:brancher", "rp:requester"],
      "@bob:local": ["ta:approver", "ew:merger", "rp:allocator"]
    }
  }
}
```

### 6.2 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `room_id` | string | Room 唯一标识符（`room-{name}-{seq}`） |
| `name` | string | Room 显示名称 |
| `created_by` | string | 创建者 Identity |
| `created_at` | ISO 8601 | 创建时间 |
| `membership.policy` | string | `open` \| `knock` \| `invite`（映射 Arena §4） |
| `membership.members` | object | entity → room role（`owner` \| `admin` \| `member`） |
| `socialware.installed` | string[] | 已安装的 namespace 列表 |
| `socialware.roles` | object | entity → Socialware Role 列表（`{ns}:{role_name}` 格式） |

> **Note**: 每个 namespace 的契约路径和来源模板可从文件系统推导——契约文件在 `contracts/{ns}.app.md`，来源模板记录在 `.app.md` 的 Header 中。

---

## 7. 数据格式

### 7.1 Ref — Timeline Entry

Timeline 中的每条 entry 是一个 Ref，记录消息的元数据和指向 Content Object 的引用。路径: `rooms/{room}/timeline/{shard_id}.jsonl`（每行一条）。

```json
{
  "ref_id": "msg-001",
  "author": "@alice:local",
  "content_type": "immutable",
  "content_id": "sha256:a1b2c3",
  "created_at": "2026-03-09T10:30:00Z",
  "status": "active",
  "clock": 1,
  "signature": "sim:not-verified",
  "ext": {
    "reply_to": null,
    "command": {
      "namespace": "ta",
      "action": "task.submit",
      "invoke_id": "inv-001"
    },
    "channels": ["main"]
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `ref_id` | string | 全局唯一（真实系统用 ULID，模拟用 `msg-{seq}`） |
| `author` | string | 消息发送者的 Identity（`@entity:local`） |
| `content_type` | string | `immutable`（不可变消息） |
| `content_id` | string | Content Object 的 hash（`sha256:xxx`） |
| `created_at` | ISO 8601 | 创建时间 |
| `status` | string | `active` \| `deleted_by_author` |
| `clock` | integer | Lamport 逻辑时钟，每条新消息 = max(已见 clock) + 1 |
| `signature` | string | 模拟签名（`sim:not-verified`） |
| `ext.reply_to` | object \| null | `null`（subject 动作）或 `{ "ref_id": "msg-xxx" }`（后续动作） |
| `ext.command.namespace` | string | Socialware 命名空间 |
| `ext.command.action` | string | 动作名 |
| `ext.command.invoke_id` | string | 调用 ID |
| `ext.channels` | string[] | 消息所属 channel |

**Flow 实例关联规则**:
- subject 动作（`reply_to=null`）: 该 Ref 的 `ref_id` 成为 flow instance ID
- 后续动作: 通过 `ext.reply_to.ref_id` 关联到 flow instance（沿链回溯）

### 7.2 Content Object

消息的实际内容，存储在 `content/sha256_{hash}.json`：

```json
{
  "content_id": "sha256:a1b2c3",
  "type": "immutable",
  "author": "@alice:local",
  "body": {
    "title": "实现用户认证模块",
    "description": "使用 JWT + OAuth2 实现用户认证"
  },
  "format": "application/json",
  "created_at": "2026-03-09T10:30:00Z",
  "signature": "sim:not-verified"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `content_id` | string | `sha256:hash`（真实系统中 = sha256(canonical_json(content))） |
| `type` | string | `immutable` |
| `author` | string | 创建者 |
| `body` | object | 动作的具体数据，结构由 binding 的输入/输出定义 |
| `format` | string | `application/json` \| `text/plain` \| `text/markdown` |

### 7.3 State Cache

`state.json` 是从 Timeline 纯推导的状态缓存。**可删除后从 timeline 重建**（`rebuild-state.py`）。

```json
{
  "flow_states": {
    "msg-001": {
      "flow": "ta:task_lifecycle",
      "state": "submitted",
      "subject_action": "task.submit",
      "subject_author": "@alice:local",
      "last_action": "task.submit",
      "last_ref": "msg-001"
    },
    "msg-003": {
      "flow": "ew:branch_lifecycle",
      "state": "active",
      "subject_action": "branch.create",
      "subject_author": "@alice:local",
      "last_action": "branch.create",
      "last_ref": "msg-003"
    }
  },
  "role_map": {
    "@alice:local": ["ta:poster", "ew:emitter", "ew:brancher"],
    "@bob:local": ["ta:worker", "ew:merger"]
  },
  "commitments": {
    "ta:C1": {
      "status": "active",
      "triggered_by": "msg-001",
      "triggered_at": "2026-03-09T10:30:00Z"
    }
  },
  "last_clock": 5,
  "peer_cursors": {
    "@alice:local": 5,
    "@bob:local": 3
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `flow_states` | object | key = subject Ref 的 ref_id（flow instance ID） |
| `flow_states.*.flow` | string | `{ns}:{flow_name}` 格式 |
| `flow_states.*.state` | string | 当前状态 |
| `flow_states.*.subject_action` | string | 创建此 instance 的动作名 |
| `flow_states.*.subject_author` | string | 创建者（用于 CBAC `author` 检查） |
| `flow_states.*.last_action` | string | 最后执行的动作 |
| `flow_states.*.last_ref` | string | 最后一条相关 Ref 的 ID |
| `role_map` | object | entity → `[ns:role, ...]`（从 config.json 复制，不随 timeline 变化） |
| `commitments` | object | `{ns}:{id}` → 状态（`inactive` \| `active` \| `fulfilled` \| `violated`） |
| `last_clock` | integer | 当前最大 Lamport clock |
| `peer_cursors` | object | entity → 该 peer 上次见过的最大 clock（integer） |

### 7.4 Artifacts

Artifacts 是 Tool 执行的副产物，存储在 `artifacts/` 目录。它们**不是真相源**——只是便利存储。可以通过重放 Timeline + 重新执行 Tool 来重新生成。

```
workspace/rooms/{name}/artifacts/
├── task-001-spec.md
├── branch-feature-auth.patch
└── report-2026-03.pdf
```

---

## 8. 完整示例

### 8.1 ta.app.md

```markdown
# TaskArena (ta)

> **类型**：Socialware App（已绑定）
> **状态**：已绑定
> **来源模板**：two-role-submit-approve.socialware.md
> **Namespace**：ta
> **Room**：alpha
> **绑定者**：@alice:local
> **日期**：2026-03-09

## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 提交者 | submit, revise | @alice:local |
| R2 | 审批者 | approve, reject | @bob:local |

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
| 工具 (Tool) | manual |
| 输入 (Input) | 任务标题 + 描述文本 |
| 输出 (Output) | 任务提交确认 |
| 消息模板 (Message Template) | 📋 @{author} 提交了任务: {title} |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.approve

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | manual |
| 输入 (Input) | 审批意见文本 |
| 输出 (Output) | 审批通过通知 |
| 消息模板 (Message Template) | ✅ @{author} 审批通过: {comment} |
| 依赖 (Requires) | [ta:task_lifecycle.submitted](state.json) |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.reject

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | manual |
| 输入 (Input) | 驳回原因文本 |
| 输出 (Output) | 驳回通知 |
| 消息模板 (Message Template) | ❌ @{author} 驳回了任务: {reason} |
| 依赖 (Requires) | [ta:task_lifecycle.submitted](state.json) |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

### Action: task_lifecycle.revise

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | manual |
| 输入 (Input) | 修改后的任务描述 |
| 输出 (Output) | 修改提交确认 |
| 消息模板 (Message Template) | 🔄 @{author} 修改并重新提交了任务: {title} |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |

## §6 Simulation Environment

| 属性 | 值 |
|------|-----|
| Workspace 路径 | simulation/workspace/rooms/alpha/ |
| Identity 模拟 | 文件系统身份（@name:local） |
| P2P 模式 | multi-session |
| 持久化 | Timeline = JSONL, State = JSON |
```

### 8.2 config.json

```json
{
  "room_id": "room-alpha-001",
  "name": "Alpha Team Room",
  "created_by": "@alice:local",
  "created_at": "2026-03-09T10:00:00Z",
  "membership": {
    "policy": "invite",
    "members": {
      "@alice:local": "owner",
      "@bob:local": "member"
    }
  },
  "socialware": {
    "installed": ["ta"],
    "roles": {
      "@alice:local": ["ta:poster"],
      "@bob:local": ["ta:approver"]
    }
  }
}
```
