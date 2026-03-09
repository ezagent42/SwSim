# Socialware 模拟数据格式参考

映射 ezagent 的 Zenoh key space 到本地文件系统。

## 基础路径

```
simulation/workspace/
```

## Identity

路径: `identities/@{entity}.json`（全局）+ `rooms/{room}/identities/@{entity}.json`（Room 成员引用）

映射: `ezagent/@{entity_id}/identity/pubkey`

```json
{
  "entity_id": "@alice:local",
  "pubkey_sim": "sim:ed25519:alice-pubkey",
  "created_at": "2026-03-09T10:00:00Z"
}
```

- `entity_id` 格式: `@{local_part}:{domain}`，模拟中 domain 统一用 `local`
- `pubkey_sim`: 模拟签名，不做真 Ed25519
- 全局 identity 在 `workspace/identities/`，Room 成员引用在 `rooms/{room}/identities/`

## Room Config

路径: `rooms/{room}/config.json`

映射: `ezagent/{room_id}/config/{state|updates}`

```json
{
  "room_id": "room-{name}-001",
  "name": "{Name}",
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
    "installed": ["ew", "ta", "rp"],
    "roles": {
      "@alice:local": ["ew:emitter", "ew:brancher", "ta:poster"],
      "@bob:local": ["ew:merger", "ew:admin", "ta:reviewer", "rp:allocator"]
    }
  }
}
```

字段说明:
- `membership.policy`: `open` | `knock` | `invite`（映射 Arena §4）
- `membership.members`: entity → room role（`owner` | `admin` | `member`）
- `socialware.installed`: 已安装 Socialware 的 namespace 列表
- `socialware.roles`: entity → Socialware Role 列表（namespace:role 格式）

## Ref（Timeline 条目）

路径: `rooms/{room}/timeline/{shard_id}.jsonl`（每行一条）

映射: `ezagent/{room_id}/index/{shard_id}/{state|updates}` 中的 crdt_array 元素

```json
{
  "ref_id": "msg-001",
  "author": "@alice:local",
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
  "author": "@alice:local",
  "body": {
    "name": "hotfix",
    "description": "紧急修复分支"
  },
  "format": "application/json",
  "created_at": "2026-03-09T10:00:00Z",
  "signature": "sim:not-verified"
}
```

- `body`: 动作的具体数据，结构由 binding 的输入/输出定义
- `format`: `application/json` | `text/plain` | `text/markdown`
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
      "subject_author": "@alice:local",
      "last_action": "branch.create",
      "last_ref": "msg-001"
    },
    "msg-002": {
      "flow": "ta:task_lifecycle",
      "state": "claimed",
      "subject_action": "task.post",
      "subject_author": "@alice:local",
      "last_action": "task.claim",
      "last_ref": "msg-004"
    }
  },
  "role_map": {
    "@alice:local": ["ew:emitter", "ew:brancher", "ta:poster"],
    "@bob:local": ["ew:merger", "ew:observer", "ta:reviewer"]
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
    "@alice:local": 5,
    "@bob:local": 2
  }
}
```

字段说明:
- `flow_states`: flow instance ID (= subject Ref 的 ref_id) → 当前状态
  - `flow`: namespace:flow_name 格式（跨 namespace 可区分）
  - `subject_author`: Flow 创建者（用于 CBAC 验证）
- `role_map`: 从 config.json 的 `socialware.roles` 复制（不随 timeline 变化）
- `commitments`: namespace:commitment_id → 状态（`inactive` | `active` | `fulfilled` | `violated`）
- `last_clock`: 当前最大 Lamport clock
- `peer_cursors`: 每个 identity 上次"在线"时见过的最大 clock

## Artifacts

路径: `rooms/{room}/artifacts/`

工具执行的副产物文件。不是 truth，只是 side-effect。

例:
- `artifacts/doc-42.md` — `bash: cat >> doc-42.md` 的产物
- `artifacts/tasks.log` — `bash: echo >> tasks.log` 的产物
