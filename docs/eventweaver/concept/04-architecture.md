# 04 — EventWeaver 的架构

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 架构总览

```
┌─ Room 运行时 ─────────────────────────────────────────────┐
│                                                           │
│  Socialware Runtime                                       │
│  ┌─ Timeline ─┐  ┌─ State ─┐  ┌─ Flow Engine ─┐         │
│  │ msg events │  │ derived │  │ fork_review   │         │
│  │ (JSONL)    │  │ (JSON)  │  │ trust_change  │         │
│  └────────────┘  └─────────┘  └───────────────┘         │
│        │                                                  │
│        │ Socialware msg 引用 EventWeaver 工具              │
│        ▼                                                  │
│  ┌─ EventWeaver Engine ─────────────────────────────────┐ │
│  │                                                       │ │
│  │  ┌─ Command Pipeline ──────────────────────────┐     │ │
│  │  │ RECEIVE → LOOKUP → AUTHORIZE → EXECUTE →    │     │ │
│  │  │ CONFLICT → COMMIT → PROJECT                 │     │ │
│  │  └─────────────────────────────────────────────┘     │ │
│  │                                                       │ │
│  │  ┌─ Capability Registry ─┐  ┌─ Grants Table ──┐     │ │
│  │  │ document plugin       │  │ (owner, editor,  │     │ │
│  │  │ session plugin        │  │  cap, block)     │     │ │
│  │  │ ref plugin            │  │ → 主线 or 分叉    │     │ │
│  │  └───────────────────────┘  └──────────────────┘     │ │
│  │                                                       │ │
│  │  ┌─ State Projector ─────────────────────────┐       │ │
│  │  │ blocks: HashMap<BlockId, Block>           │       │ │
│  │  │ grants: GrantsTable                       │       │ │
│  │  │ forks: HashMap<BlockId, Vec<ForkId>>      │       │ │
│  │  │ parents: HashMap<BlockId, Vec<BlockId>>   │       │ │
│  │  └───────────────────────────────────────────┘       │ │
│  │                                                       │ │
│  └───────────────────────────────────────────────────────┘ │
│        │                              │                    │
│        ▼                              ▼                    │
│  ┌─ Event Store ─┐            ┌─ Cache Store ─┐           │
│  │ eventstore.db │            │ cache.db      │           │
│  │ (不可变)       │            │ (可丢弃)      │           │
│  └───────────────┘            └───────────────┘           │
└───────────────────────────────────────────────────────────┘
```

## 2. 本地数据存储

### 2.1 存储位置

EventWeaver 的数据存储在 Room 本地：

```
workspace/rooms/{room}/
├── timeline/                    ← Socialware 管（msg events）
├── state.json                   ← Socialware 管（flow states）
├── content/                     ← Socialware 管（Content Objects）
├── ew/                          ← EventWeaver 独有
│   ├── eventstore.db            ← 事件日志（不可变，单一真相源）
│   ├── cache.db                 ← 状态快照缓存（可丢弃重建）
│   └── config.toml              ← EventWeaver 配置（plugin 注册等）
└── ...
```

### 2.2 eventstore.db（核心，不可变）

SQLite 数据库，存储所有 EAVT 事件。

```sql
CREATE TABLE events (
    event_id    TEXT PRIMARY KEY,
    entity      TEXT NOT NULL,        -- block_id
    attribute   TEXT NOT NULL,        -- "{author_id}/{cap_id}"
    value       TEXT NOT NULL,        -- JSON payload
    timestamp   TEXT NOT NULL,        -- Vector clock (JSON)
    created_at  TEXT NOT NULL,        -- ISO 8601
    mode        TEXT NOT NULL         -- full/delta/ref/append
);

CREATE INDEX idx_entity ON events(entity);
CREATE INDEX idx_attribute ON events(attribute);
CREATE INDEX idx_created_at ON events(created_at);
```

**不可变约束**：只有 INSERT，没有 UPDATE 或 DELETE。这是单一真相源。

### 2.3 cache.db（加速，可丢弃）

SQLite 数据库，缓存 block 的最新状态快照。

```sql
CREATE TABLE block_snapshots (
    block_id        TEXT PRIMARY KEY,
    snapshot        TEXT NOT NULL,    -- JSON: Block 完整状态
    last_event_id   TEXT NOT NULL,    -- 快照基于的最新事件
    updated_at      TEXT NOT NULL
);
```

**可丢弃**：删除后通过重放 eventstore.db 重建。

### 2.4 真实系统中的存储

SwSim 中用 SQLite 模拟。在 ezagent 真实环境中：

| SwSim 模拟 | ezagent 真实 |
|---|---|
| SQLite eventstore.db | RocksDB（每个节点本地） |
| JSON Vector Clock | yrs CRDT 内置时钟 |
| 文件系统同步 | Zenoh pub/sub + queryable |

## 3. 通讯方式

### 3.1 SwSim 中的通讯

在 SwSim 模拟环境中，EventWeaver 通过以下方式与外部通讯：

```
┌─ Claude Code Session (Peer) ─────────────────────┐
│                                                   │
│  用户输入: "ew:contribute block-001 新内容"        │
│       │                                           │
│       ▼                                           │
│  Socialware Runtime (skill)                       │
│       │ 解析命令 → 调用 EventWeaver 工具            │
│       ▼                                           │
│  EventWeaver 工具执行                              │
│       │                                           │
│       ├── CLI 调用: `ew contribute block-001 ...`  │
│       │   （EventWeaver 作为独立二进制）             │
│       │                                           │
│       └── MCP 调用: EventWeaver MCP Server         │
│           （EventWeaver 作为 MCP 服务）             │
│                                                   │
│  结果写入:                                         │
│  ├── eventstore.db（EventWeaver 事件）             │
│  ├── Timeline（Socialware msg event）              │
│  └── state.json（Flow state 更新）                 │
└───────────────────────────────────────────────────┘
```

### 3.2 两种集成模式

#### 模式 A: CLI 工具

EventWeaver 编译为独立二进制 `ew`，Socialware skill 通过 bash 调用。

```bash
# Socialware skill 内部调用
ew create --name "auth-module" --type document --project ./ew/
ew contribute --block block-001 --content "新内容" --project ./ew/
ew audit --block block-001 --project ./ew/
ew accept --fork fork-001 --project ./ew/
```

**优势**：简单，无需长期运行进程
**劣势**：每次调用需启动引擎 + 重放事件（慢），无法推送通知

#### 模式 B: MCP Server

EventWeaver 作为 MCP Server 长期运行，Socialware skill 通过 MCP 协议调用。

```json
// .mcp.json
{
  "mcpServers": {
    "eventweaver": {
      "command": "ew",
      "args": ["serve", "--port", "47201", "--project", "./ew/"]
    }
  }
}
```

```
MCP 调用: eventweaver/contribute { block_id: "block-001", content: "新内容" }
```

**优势**：引擎常驻内存（快），可推送事件通知，支持并发
**劣势**：需要管理进程生命周期

#### 推荐

**开发阶段用 CLI**（简单，快速迭代），**生产/多人协作用 MCP Server**（性能，通知）。

两种模式共享同一个 EventWeaver 引擎代码，只是入口不同。

### 3.3 P2P 同步通讯

SwSim 中通过共享文件系统模拟 P2P：

```
Peer A 的 Claude Code Session
    │
    ▼ 写入 eventstore.db
workspace/rooms/{room}/ew/eventstore.db  ← 共享文件
    │
    ▼ Peer B 的 Session 读取
检测到新事件 → 权限检查 → 主线 or 分叉
```

真实系统中通过 Zenoh：

```
Peer A
    │ ew:contribute → 产生事件
    ▼
Zenoh pub/sub: topic = "room/{room}/ew/events"
    │
    ▼
Peer B
    │ 收到事件 → 权限检查 → 主线 or 分叉
    ▼
本地 RocksDB 写入
```

## 4. 引擎内部架构

### 4.1 命令处理管道（7 步）

沿用 elfiee 的 Actor 模型，适配 Socialware：

```
1. RECEIVE      从 CLI/MCP 接收命令
2. LOOKUP       从 Capability Registry 查找 plugin
3. AUTHORIZE    检查 Socialware Role（R1/R2/R3 资格）
4. EXECUTE      调用 plugin handler → 产生 Vec<Event>（纯函数）
5. CONFLICT     检查 Vector Clock / CRDT → 决定主线 or 分叉
6. COMMIT       原子追加事件到 eventstore.db
7. PROJECT      应用事件到 State Projector
                └──> 如果分叉 → 创建 fork_review Flow instance
                └──> 广播事件（MCP 模式下通知其他 peer）
```

### 4.2 分叉检测（步骤 5 详解）

```
收到事件 E（来自同步或本地写入）
    │
    ▼ 检查 E.author 对 E.entity (block) 的 grant
    │
    ├── 有 grant (或 author = owner)
    │   │
    │   ▼ CRDT 合并
    │   ├── 成功 → 事件进入主线
    │   └── 冲突 → 标记 conflict，等 ew:accept 手动解决
    │
    └── 无 grant
        │
        ▼ 自动分叉
        创建 fork block（E.author = fork owner）
        事件进入 fork 的事件链
        创建 fork_review Flow instance（pending）
        通知 parent block 的 owner
```

### 4.3 状态重建

```
State = reduce(events, initial_state)

启动时:
  1. 尝试从 cache.db 加载快照
  2. 找到快照对应的 last_event_id
  3. 从 eventstore.db 加载 last_event_id 之后的增量事件
  4. 逐个应用增量事件到快照
  5. 如果 cache.db 无效或不存在 → 全量重放

周期性:
  每 N 个事件或 M 分钟，保存当前状态到 cache.db
```

## 5. 不可变约束

以下 block 属性创建后永不改变：

| 属性 | 存储位置 | 理由 |
|---|---|---|
| block_id | eventstore.db (创建事件) | 身份标识 |
| block_type | eventstore.db (创建事件) | 决定使用哪个 plugin |
| owner | eventstore.db (创建事件) | 权限根源 |
| created_at | eventstore.db (创建事件) | 出生时间 |

可变属性（通过事件更新）：content, name, description, links, grants。
