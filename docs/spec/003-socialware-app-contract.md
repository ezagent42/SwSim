# 003 — Socialware App 契约文件规范 (.app.md)

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 概述

`.app.md` 是 Socialware 的**绑定契约文件**。它有两种状态：
- **已开发**（App Dev 产出）：所有 §5 `_待实现_` 字段已填入 Tool 和跨契约引用，但 §1 Holder 仍为 `_待绑定_`。存储在 `workspace/app-store/`。
- **已安装**（App Install 产出）：所有字段已填入真实值，§1 Holder 绑定为具体 Identity。安装在 Room 中，为 Room 提供一个 namespace 的命令集。

---

## 2. 与模板的关系

| 属性 | 模板 (.socialware.md) | 已开发 App (.app.md) | 已安装 App (.app.md) |
|------|----------------------|---------------------|---------------------|
| 性质 | 抽象设计，只读产品 | 工具已绑定，可安装 | 具体实例，可运行 |
| Holder | `_待绑定_` | `_待绑定_` | 绑定为 `alice:Alice@local` 等 |
| Tool | `_待实现_` | 绑定为 `bash: ...` 等 | 绑定为 `bash: ...` 等 |
| 引用 | `_待实现_` 或 `_无_` | 具体路径或 `_无_` | 具体路径或 `_无_` |
| Status | `模板` | `已开发` | `已安装` |
| 存储 | `simulation/socialware/` | `workspace/app-store/` | `workspace/rooms/{room}/contracts/` |

**创建流程**：App Dev 复制模板 → 填充所有 §5 `_待实现_` → 保存为 `.app.md`（已开发）到 app-store，并在 `simulation/app-store/registry.json` 中创建注册条目。App Install 从 app-store（通过 registry.json 查询）复制 → 填充 §1 `_待绑定_` → 安装到 Room。模板保持只读。

---

## 3. 命名规则

模板名、App-ID、namespace 三者**解耦**，用户在各阶段独立选择：

| 层级 | 命名 | 示例 |
|------|------|------|
| 模板 | `{descriptive-name}.socialware.md` | `two-role-submit-approve.socialware.md` |
| App（app-store） | `{AppName}.{DeveloperName}.{SocialwareName}.app.md` | `doc-review.alice.two-role-submit-approve.app.md` |
| App（已安装） | `{AppName}.{DeveloperName}.{SocialwareName}.app.md`（复制到 Room） | `doc-review.alice.two-role-submit-approve.app.md` |
| Namespace | 2-4 字母简称，install 时选择 | `da`, `ta`, `ew` |

**App-ID 格式**：`{AppName}.{DeveloperName}.{SocialwareName}`
- **AppName**：开发者为其实现选择的名称（如 `doc-review`）
- **DeveloperName**：开发者 Identity 的 username 部分（如 `alice` from `alice:Alice@local`）
- **SocialwareName**：模板文件名去掉 `.socialware.md` 扩展名（如 `two-role-submit-approve`）

- 模板名描述组织设计（what it is）
- App-ID 结合了实现名、开发者、来源模板（who made what from which template）
- Namespace 是 Room 内的短缩写（how it's called in this Room）
- 同一个模板可以被不同 App Dev 开发成不同 App，同一 App 可安装到多个 Room

---

## 4. 文件格式

### 4.1 Header

**已开发阶段**（`app-store/{AppName}.{DeveloperName}.{SocialwareName}.app.md`）:

```markdown
# {AppName}.{DeveloperName}.{SocialwareName}.app.md

> 状态: 已开发
> App-ID: {AppName}.{DeveloperName}.{SocialwareName}
> 基于模板: {SocialwareName}.socialware.md
> 开发者: {username}:{nickname}@{namespace}
```

**已安装阶段**（`rooms/{room}/contracts/{AppName}.{DeveloperName}.{SocialwareName}.app.md`）:

```markdown
# {AppName}.{DeveloperName}.{SocialwareName}.app.md

> 状态: 已安装
> App-ID: {AppName}.{DeveloperName}.{SocialwareName}
> 基于模板: {SocialwareName}.socialware.md
> 开发者: {username}:{nickname}@{namespace}
> 安装者: {username}:{nickname}@{namespace}
> Namespace: {ns}
> Room: {room_name}
```

**开发者/安装者**: 必填，由各阶段操作者的当前身份自动填入。操作者必须先在 `workspace/identities/` 中拥有身份。

### 4.2 §1 Roles — 已安装角色

Holder 填入具体 Identity：

```markdown
## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 提交者 | submit, revise | alice:Alice@local |
| R2 | 审批者 | approve, reject | bob:Bob@local |
```

**Identity 格式**：`{username}:{nickname}@{namespace}`，模拟环境中 namespace 为 `local`。

### 4.3 §2 Flows — 不变

Flow 定义从模板直接复制，不做修改。状态机是组织设计的核心，绑定阶段不改变。

### 4.4 §3 Commitments — 不变

Commitment 定义从模板直接复制。

### 4.5 §4 Arena — 不变

Arena 定义从模板直接复制。

### 4.6 §5 Context Bindings — 已实现

所有 `_待实现_` 字段填入具体值（在 App Dev 阶段完成）：

```markdown
## §5 Context Bindings

### on: submit

- 前置: R1
- 工具: manual
- 输入: 任务标题 + 描述
- 输出: 任务提交确认消息
- 消息模板: "📋 @{author} 提交了任务: {title}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: approve

- 前置: R2
- 工具: manual
- 输入: 审批意见
- 输出: 审批结果通知
- 消息模板: "✅ @{author} 审批通过: {comment}"
- 依赖: [ta:task_lifecycle submitted](同 Room)
- 委托: _无_
- 资源: _无_
```

### 4.7 §6 Simulation Environment — 模拟环境配置

App 文件新增的章节，定义运行时环境：

```markdown
## §6 Simulation Environment

| 属性 | 值 |
|------|-----|
| Workspace 路径 | simulation/workspace/rooms/{room_name}/ |
| Identity 模拟 | 文件系统身份（{username}:{nickname}@local） |
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
│   ├── task-arena.alice.two-role-submit-approve.app.md   (namespace: ta)
│   ├── edit-workflow.alice.event-weaver.app.md           (namespace: ew)
│   └── resource-pool.bob.resource-pool.app.md            (namespace: rp)
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
  "created_by": "alice:Alice@local",
  "created_at": "2026-03-09T10:00:00Z",
  "membership": {
    "policy": "invite",
    "members": {
      "alice:Alice@local": "owner",
      "bob:Bob@local": "member"
    }
  },
  "socialware": {
    "installed": [
      {
        "app_id": "task-arena.alice.two-role-submit-approve",
        "namespace": "ta",
        "contract": "task-arena.alice.two-role-submit-approve.app.md",
        "template": "two-role-submit-approve.socialware.md"
      },
      {
        "app_id": "edit-workflow.alice.branch-merge",
        "namespace": "ew",
        "contract": "edit-workflow.alice.branch-merge.app.md",
        "template": "branch-merge.socialware.md"
      },
      {
        "app_id": "resource-pool.bob.resource-allocation",
        "namespace": "rp",
        "contract": "resource-pool.bob.resource-allocation.app.md",
        "template": "resource-allocation.socialware.md"
      }
    ],
    "roles": {
      "ta:R1": "alice:Alice@local",
      "ta:R2": "bob:Bob@local",
      "ew:R1": "alice:Alice@local",
      "ew:R2": "alice:Alice@local",
      "ew:R3": "bob:Bob@local",
      "rp:R1": "alice:Alice@local",
      "rp:R2": "bob:Bob@local"
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
| `socialware.installed` | array | 已安装 App 的对象数组，每项含 `app_id`, `namespace`, `contract`, `template` |
| `socialware.roles` | object | `{ns}:{R-ID}` → `{username}:{nickname}@{namespace}`，每个角色到身份的映射 |

---

## 7. 数据格式

### 7.1 Ref — Timeline Entry

Timeline 中的每条 entry 是一个 Ref，记录消息的元数据和指向 Content Object 的引用。路径: `rooms/{room}/timeline/{shard_id}.jsonl`（每行一条）。

```json
{
  "ref_id": "msg-001",
  "author": "alice:Alice@local",
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
| `author` | string | 消息发送者的 Identity（`{username}:{nickname}@{namespace}`） |
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
  "author": "alice:Alice@local",
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
      "subject_author": "alice:Alice@local",
      "last_action": "task.submit",
      "last_ref": "msg-001"
    },
    "msg-003": {
      "flow": "ew:branch_lifecycle",
      "state": "active",
      "subject_action": "branch.create",
      "subject_author": "alice:Alice@local",
      "last_action": "branch.create",
      "last_ref": "msg-003"
    }
  },
  "role_map": {
    "ta:R1": "alice:Alice@local",
    "ta:R2": "bob:Bob@local",
    "ew:R1": "alice:Alice@local",
    "ew:R2": "alice:Alice@local",
    "ew:R3": "bob:Bob@local"
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
    "alice:Alice@local": 5,
    "bob:Bob@local": 3
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
| `role_map` | object | `{ns}:{R-ID}` → entity，从 config.json 的 `socialware.roles` 复制（不随 timeline 变化） |
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

### 8.1 task-arena.alice.two-role-submit-approve.app.md

```markdown
# task-arena.alice.two-role-submit-approve.app.md

> 状态: 已安装
> App-ID: task-arena.alice.two-role-submit-approve
> 基于模板: two-role-submit-approve.socialware.md
> 开发者: alice:Alice@local
> 安装者: alice:Alice@local
> Namespace: ta
> Room: alpha

## §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 提交者 | submit, revise | alice:Alice@local |
| R2 | 审批者 | approve, reject | bob:Bob@local |

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

- 进入策略: role_based
- 准入条件: 必须被分配 R1 或 R2 角色

## §5 Context Bindings

### on: submit

- 前置: R1
- 工具: manual
- 输入: 任务标题 + 描述文本
- 输出: 任务提交确认
- 消息模板: "📋 @{author} 提交了任务: {title}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: approve

- 前置: R2
- 工具: manual
- 输入: 审批意见文本
- 输出: 审批通过通知
- 消息模板: "✅ @{author} 审批通过: {comment}"
- 依赖: [ta:task_lifecycle submitted](同 Room)
- 委托: _无_
- 资源: _无_

### on: reject

- 前置: R2
- 工具: manual
- 输入: 驳回原因文本
- 输出: 驳回通知
- 消息模板: "❌ @{author} 驳回了任务: {reason}"
- 依赖: [ta:task_lifecycle submitted](同 Room)
- 委托: _无_
- 资源: _无_

### on: revise

- 前置: R1 + 状态=rejected
- 工具: manual
- 输入: 修改后的任务描述
- 输出: 修改提交确认
- 消息模板: "🔄 @{author} 修改并重新提交了任务: {title}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

## §6 Simulation Environment

| 属性 | 值 |
|------|-----|
| Workspace 路径 | simulation/workspace/rooms/alpha/ |
| Identity 模拟 | 文件系统身份（{username}:{nickname}@local） |
| P2P 模式 | multi-session |
| 持久化 | Timeline = JSONL, State = JSON |
```

### 8.2 config.json

```json
{
  "room_id": "room-alpha-001",
  "name": "Alpha Team Room",
  "created_by": "alice:Alice@local",
  "created_at": "2026-03-09T10:00:00Z",
  "membership": {
    "policy": "invite",
    "members": {
      "alice:Alice@local": "owner",
      "bob:Bob@local": "member"
    }
  },
  "socialware": {
    "installed": [
      {
        "app_id": "task-arena.alice.two-role-submit-approve",
        "namespace": "ta",
        "contract": "task-arena.alice.two-role-submit-approve.app.md",
        "template": "two-role-submit-approve.socialware.md"
      }
    ],
    "roles": {
      "ta:R1": "alice:Alice@local",
      "ta:R2": "bob:Bob@local"
    }
  }
}
```
