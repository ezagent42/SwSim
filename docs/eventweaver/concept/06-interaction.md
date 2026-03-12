# 06 — EventWeaver 的交互形式

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 交互形式概览

EventWeaver 在 Socialware Room 中有三种交互形式：

```
┌─────────────────────────────────────────────────────┐
│  1. 主动命令 — 用户在聊天室中输入 ew:xxx 触发         │
│  2. 自动触发 — P2P 同步/Hook 自动触发 EventWeaver     │
│  3. 被动查询 — 其他 App 调用 EventWeaver 工具获取信息  │
└─────────────────────────────────────────────────────┘
```

## 2. 主动命令（聊天室命令）

用户在 Room 的对话中输入 `ew:action` 格式的命令。

### 2.1 命令格式

```
ew:{action} [参数...]
```

Socialware Runtime 解析命令 → 检查 Role/CBAC → 调用 EventWeaver 工具 → 结果写入 Timeline。

### 2.2 完整命令列表

#### 产出物管理

```
ew:create {name} --type {document|session|ref} [--content "内容"]
  → 创建 block，开始追踪
  → 输出: "已创建 block-001 (document)，你是管家"

ew:contribute {block_id} --content "新内容"
  → 向 block 贡献内容
  → 输出: "已写入 block-001 (delta, +5-2)"
  → 或: "已写入 block-001 → 自动分叉 fork-001（无合并权限）"

ew:view {block_id}
  → 查看 block 当前状态
  → 输出: block 的完整内容和元数据

ew:archive {block_id}
  → 归档 block
  → 输出: "block-001 已归档"
```

#### 关系管理

```
ew:relate {parent_id} {child_id} [--type implement]
  → 添加因果关系
  → 输出: "block-001 → block-002 (implement)"

ew:unrelate {parent_id} {child_id}
  → 移除关系
  → 输出: "已移除 block-001 → block-002"
```

#### 信任管理

```
ew:grant {block_id} {target_identity}
  → 授予合并权限
  → 输出: "已授予 bob:Bob@local 对 block-001 的合并权限"

ew:revoke {block_id} {target_identity}
  → 撤销合并权限
  → 输出: "已撤销 bob:Bob@local 对 block-001 的合并权限"
```

#### 分叉管理

```
ew:list_forks {block_id}
  → 查看所有分叉
  → 输出:
    fork-001 by carol:Carol@local  (pending, 2 events)
    fork-002 by dave:Dave@local    (merged, 5 events)

ew:accept {fork_id} [--comment "审查意见"]
  → 接受分叉，合入主线
  → 输出: "fork-001 已合入 block-001 主线（CRDT 自动合并）"
  → 或: "fork-001 合并冲突，需手动解决"

ew:reject {fork_id} [--comment "拒绝原因"]
  → 拒绝分叉
  → 输出: "fork-001 已拒绝"

ew:force_resolve {fork_id} [--strategy accept|reject]
  → 管理员强制处理（仅 R1）
  → 输出: "管理员强制合并 fork-001"
```

#### 事件消费

```
ew:audit {block_id} [--limit 10]
  → 查看事件历史
  → 输出:
    evt-001  2026-03-10 10:00  alice  create     (full)
    evt-002  2026-03-10 14:30  alice  contribute (delta, +15-3)
    evt-003  2026-03-11 09:15  bob    contribute (delta, +8-1)

ew:state_at {block_id} {event_id}
  → 时光回溯
  → 输出: 该事件点的 block 完整状态

ew:diff {block_id} --from {event_id} --to {event_id}
  → 差异比较
  → 输出: 两点之间的具体变化

ew:query --author alice --type document --has-forks
  → 结构化查询
  → 输出: 符合条件的 block/event 列表

ew:trace {block_id} [--depth 3]
  → 因果链追溯
  → 输出:
    block-001 (auth-module.rs)
      ← implements ← block-002 (auth-spec.md)
        ← implements ← block-003 (project-prd.md)
```

## 3. 自动触发

某些 EventWeaver 操作不是用户主动发起的，而是系统自动触发。

### 3.1 P2P 同步触发

```
触发时机: 另一个 Peer 的事件同步到本节点

处理流程:
  收到远程事件 E
    │
    ├── E.author 有 grant → CRDT auto-merge → 静默处理
    │   （不产生聊天室消息，只更新 eventstore.db）
    │
    └── E.author 无 grant → 自动分叉
        │
        ▼ 产生通知
        在聊天室中显示:
        "⚡ carol:Carol@local 对 block-001 的修改已自动分叉为 fork-001"
        │
        ▼ 创建 fork_review Flow instance
        "请管家 alice:Alice@local 审查: ew:accept fork-001 或 ew:reject fork-001"
```

### 3.2 Hook 触发

Socialware Runtime 的 Hook 机制可以在特定事件时自动调用 EventWeaver：

```
Hook: UserPromptSubmit
  │
  ▼ check-inbox.sh 检查
  检测到新的同步事件 → 显示通知

Hook: AfterWrite (Socialware 层)
  │
  ▼ 当 ta:submit 写入 Timeline 后
  自动触发 ew:create 开始追踪关联文件
```

### 3.3 Commitment 超时触发

```
C1 超时: fork_review.pending 超过 72h
  │
  ▼ 系统通知
  "⏰ C1 violated: block-001 的分叉 fork-001 已超时未审查"
  "管理员 admin:Admin@local 请执行 ew:force_resolve fork-001"
```

## 4. 被动查询（其他 App 调用）

EventWeaver 被其他 App 作为信息源调用。

### 4.1 TaskArena 查询审计证据

```
场景: Bob 审批任务前，TaskArena 的 approve binding 依赖 EventWeaver

ta:approve 的 §5 Binding:
  依赖: [ew:audit](同 Room)

执行流程:
  bob → ta:approve
    │
    ▼ TaskArena 检查依赖
    调用 ew:audit {关联的 block_id}
    │
    ▼ 返回审计证据
    展示给 Bob:
    "审计报告: block-001 共 5 次修改，最近一次 by alice 于 2026-03-11"
    │
    ▼ Bob 确认后
    TaskArena 执行 approve
```

### 4.2 AgentForge 查询操作记录

```
场景: 管理员查看某 Agent 做了什么

ew:query --author code-bot
  → 返回 code-bot 的所有操作事件
```

## 5. 输出渲染

### 5.1 文本模式（默认）

适用于 CLI / 聊天室文本输出。

```
$ ew:audit block-001

事件历史: block-001 (auth-module.rs)
管家: alice:Alice@local
分叉: 1 个 pending

 #  时间                作者              操作         详情
 1  2026-03-10 10:00   alice:Alice@local  create      (full, 120 行)
 2  2026-03-10 14:30   alice:Alice@local  contribute  (delta, +15-3)
 3  2026-03-11 09:15   bob:Bob@local      contribute  (delta, +8-1)
 4  2026-03-11 11:00   carol:Carol@local  diverge     → fork-001 (pending)
```

### 5.2 结构化模式（MCP/API）

适用于工具间调用，返回 JSON。

```json
{
  "block_id": "block-001",
  "name": "auth-module.rs",
  "owner": "alice:Alice@local",
  "forks": [{ "fork_id": "fork-001", "status": "pending", "author": "carol:Carol@local" }],
  "events": [
    { "event_id": "evt-001", "attribute": "alice/create", "mode": "full", "created_at": "2026-03-10T10:00:00Z" },
    { "event_id": "evt-002", "attribute": "alice/contribute", "mode": "delta", "created_at": "2026-03-10T14:30:00Z" }
  ]
}
```

### 5.3 Capability Plugin 渲染

不同 block_type 的 plugin 决定内容如何展示：

| Plugin | view 渲染 | diff 渲染 |
|---|---|---|
| document | Markdown 文本 | 行级 diff（+红 -绿） |
| session | 对话日志（时间 + 作者 + 内容） | 新增条目列表 |
| ref | 文件链接 + hash + size | hash 变化 |

## 6. 通知机制

### 6.1 通知场景

| 事件 | 通知对象 | 内容 |
|---|---|---|
| 新分叉产生 | 父 block 的管家 | "carol 的修改已分叉为 fork-001，请审查" |
| 分叉被 accept | 分叉创建者 | "你的 fork-001 已被 alice 合入主线" |
| 分叉被 reject | 分叉创建者 | "你的 fork-001 被 alice 拒绝: {原因}" |
| C1 超时 | R1 管理员 | "fork-001 超时未审查，请 force_resolve" |
| grant 授予 | 被授权者 | "alice 授予你对 block-001 的合并权限" |
| revoke 撤销 | 被撤权者 | "alice 撤销了你对 block-001 的合并权限" |

### 6.2 SwSim 中的通知实现

通过 per-room per-identity 的 session 文件：

```
rooms/{room}/.session.{username}.json
```

- 写入：EventWeaver 工具执行后，将通知写入目标用户的 session 文件
- 读取：UserPromptSubmit Hook (check-inbox.sh) 扫描 session 文件，展示通知
- 清理：`/room clean-sessions` 清理残留 session 文件

### 6.3 真实系统中的通知

通过 Zenoh pub/sub：

```
topic: "room/{room}/ew/notifications/{identity}"
payload: { type: "fork_created", fork_id: "fork-001", ... }
```

每个 Peer 订阅自己的通知 topic，收到后在 UI 中展示。
