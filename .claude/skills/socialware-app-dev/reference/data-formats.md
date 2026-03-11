# Socialware 模拟数据格式参考

映射 ezagent 的 Zenoh key space 到本地文件系统。

## 基础路径

```
simulation/workspace/
```

## Identity

路径: `identities/{username}@{namespace}.json`（全局）+ `rooms/{room}/identities/{username}@{namespace}.json`（Room 成员引用）——文件名省略 nickname（避免 `:` 文件系统问题），JSON 内 `entity_id` 使用完整格式 `{username}:{nickname}@{namespace}`

映射: `ezagent/{entity_id}/identity/pubkey`

```json
{
  "entity_id": "alice:Alice@local",
  "pubkey_sim": "sim:ed25519:alice-pubkey",
  "created_at": "2026-03-09T10:00:00Z"
}
```

- `entity_id` 格式: `{username}:{nickname}@{namespace}`，模拟中 namespace 统一用 `local`
- `pubkey_sim`: 模拟签名，不做真 Ed25519
- 全局 identity 在 `workspace/identities/`，Room 成员引用在 `rooms/{room}/identities/`

## App Store

路径: `app-store/{app-id}.app.md`

已开发但尚未安装的 Socialware App。§5 工具已填，§1 持有者为 `_待绑定_`。

- 由 `/socialware-app-dev` 生成
- 由 `/socialware-app-install` 读取并安装到 Room

## Room Config

路径: `rooms/{room}/config.json`

映射: `ezagent/{room_id}/config/{state|updates}`

```json
{
  "room_id": "room-{name}-001",
  "name": "{Name}",
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
        "app_id": "engineering-workflow",
        "namespace": "ew",
        "contract": "engineering-workflow.app.md",
        "template": "engineering-workflow.socialware.md"
      },
      {
        "app_id": "task-assignment",
        "namespace": "ta",
        "contract": "task-assignment.app.md",
        "template": "task-assignment.socialware.md"
      }
    ],
    "roles": {
      "ew:R1": "alice:Alice@local",
      "ew:R2": "bob:Bob@local",
      "ta:R1": "alice:Alice@local",
      "ta:R2": "bob:Bob@local"
    }
  }
}
```

字段说明:
- `membership.policy`: `open` | `knock` | `invite`（映射 Arena §4）
- `membership.members`: entity → room role（`owner` | `admin` | `member`）
- `socialware.installed`: 已安装 App 的对象数组（app_id + namespace + contract 文件名 + 模板来源）
- `socialware.roles`: `{ns}:{R-ID}` → entity 映射（如 `"ew:R1": "alice:Alice@local"`）

## Ref（Timeline 条目）

路径: `rooms/{room}/timeline/{shard_id}.jsonl`（每行一条）

映射: `ezagent/{room_id}/index/{shard_id}/{state|updates}` 中的 crdt_array 元素

```json
{
  "ref_id": "msg-001",
  "author": "alice:Alice@local",
  "content_type": "immutable",
  "content_id": "sha256:a1b2c3",
  "created_at": "2026-03-09T10:00:00Z",
  "status": "active",
  "clock": 1,
  "signature": "sim:not-verified",
  "ext": {
    "reply_to": null,
    "command": {
      "namespace": "ew",
      "action": "event.record",
      "invoke_id": "inv-001"
    },
    "channels": ["main"]
  }
}
```

字段说明:
- `ref_id`: 全局唯一（真实系统用 ULID，模拟用 `msg-{seq}`）
- `clock`: Lamport clock，每条新消息 = max(已见 clock) + 1
- `status`: `active` | `deleted_by_author`
- `ext.reply_to`: `null`（subject 动作）或 `{ "ref_id": "msg-xxx" }`（后续动作）
- `ext.command.namespace`: Socialware 命名空间
- `ext.command.action`: 动作名
- `ext.channels`: 消息所属 channel

Flow 实例关联规则:
- subject 动作（Flow 表第一行的动作）: 该 Ref 的 `ref_id` 成为 flow instance ID
- 后续动作: 通过 `ext.reply_to.ref_id` 关联到 flow instance

## Content Object

路径: `rooms/{room}/content/sha256_{hash}.json`

映射: `ezagent/{room_id}/content/{sha256_hash}`

```json
{
  "content_id": "sha256:a1b2c3",
  "type": "immutable",
  "author": "alice:Alice@local",
  "body": {
    "name": "hotfix",
    "description": "紧急修复分支"
  },
  "format": "application/json",
  "created_at": "2026-03-09T10:00:00Z",
  "signature": "sim:not-verified",
  "artifacts": []
}
```

- `body`: 动作的具体数据，结构由 binding 的输入/输出定义
- `format`: `application/json` | `text/plain` | `text/markdown`
- `artifacts`: 可选，工具生成的副产物文件路径列表（如 `["artifacts/task-001-spec.md"]`）。manual 工具通常为空数组 `[]`，bash/mcp/api 工具可能产生文件
- 真实系统中 `content_id = sha256(canonical_json(content))`，模拟中简化

## State Cache

路径: `rooms/{room}/state.json`

**纯派生**，可从 timeline 重建。

```json
{
  "flow_states": {
    "msg-001": {
      "flow": "ew:branch_lifecycle",
      "state": "active",
      "subject_action": "branch.create",
      "subject_author": "alice:Alice@local",
      "last_action": "branch.create",
      "last_ref": "msg-001"
    },
    "msg-002": {
      "flow": "ta:task_lifecycle",
      "state": "claimed",
      "subject_action": "task.post",
      "subject_author": "alice:Alice@local",
      "last_action": "task.claim",
      "last_ref": "msg-004"
    }
  },
  "role_map": {
    "ew:R1": "alice:Alice@local",
    "ew:R2": "bob:Bob@local",
    "ta:R1": "alice:Alice@local",
    "ta:R2": "bob:Bob@local"
  },
  "commitments": {
    "ew:C1": {
      "status": "inactive",
      "triggered_by": null,
      "triggered_at": null
    },
    "ta:C1": {
      "status": "active",
      "triggered_by": "msg-002",
      "triggered_at": "2026-03-09T10:05:00Z"
    }
  },
  "last_clock": 5,
  "peer_cursors": {
    "alice:Alice@local": 5,
    "bob:Bob@local": 2
  }
}
```

字段说明:
- `flow_states`: flow instance ID (= subject Ref 的 ref_id) → 当前状态
  - `flow`: namespace:flow_name 格式（跨 namespace 可区分）
  - `subject_author`: Flow 创建者（用于 CBAC 验证）
- `role_map`: `{ns}:{R-ID}` → entity 映射，从 config.json 的 `socialware.roles` 复制（不随 timeline 变化）
- `commitments`: namespace:commitment_id → 状态（`inactive` | `active` | `fulfilled` | `violated`）
- `last_clock`: 当前最大 Lamport clock
- `peer_cursors`: 每个 identity 上次"在线"时见过的最大 clock

## Active Session

路径: `workspace/.active-session.json`

Runtime 会话标记，由 `/socialware-app` 启动时创建，退出时删除。用于 `UserPromptSubmit` hook 判断是否检查 inbox。

```json
{
  "room": "project-alpha",
  "identity": "alice:Alice@local",
  "started_at": "2026-03-10T10:00:00Z"
}
```

其他 skill（`/socialware-dev`、`/socialware-app-dev`、`/socialware-app-install`、`/room`）启动时如果发现此文件存在，应删除它。

## Artifacts

路径: `rooms/{room}/artifacts/`

工具执行的副产物文件。不是 truth，只是 side-effect。

例:
- `artifacts/doc-42.md` — `bash: cat >> doc-42.md` 的产物
- `artifacts/tasks.log` — `bash: echo >> tasks.log` 的产物
