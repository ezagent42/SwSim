# EventWeaver 概念设计草案

> 日期: 2026-03-12
> 状态: 草案 (brainstorming 产出)
> 来源: elfiee 完整实现 → 拆解重构 → 长在 Socialware 上

---

## 1. 定位

EventWeaver 是**文件级事件溯源系统**，作为 Socialware App 运行在 Room 中。

**不是什么：**
- 不是通用内容管理系统
- 不是 P2P 基础设施（DAG/CRDT/Zenoh 是底层 elf 和 ezagent 的事）
- 不是 Git（没有手动分支/合并操作）

**是什么：**
- 记录一切文件事件（EAVT 模型）
- 权限驱动的自动分支（有权限→主线，无权限→分支）
- 逻辑链关联（DAG implement 关系 + tool_usage 推导）
- 线性/非线性事件消费（历史回放、时光回溯、审计证据）

## 2. 在四 App 体系中的位置

```
┌─────────────────────────────────────────────────┐
│  应用层                                          │
│  ta: TaskArena    — 谁该做什么（工作流状态机）    │
│  af: AgentForge   — 谁来做（Agent 构造/管理）    │
├─────────────────────────────────────────────────┤
│  基础设施层                                       │
│  ew: EventWeaver  — 东西发生了什么（事件/分支/审计）│
│  rp: RePool       — 东西存在哪（资源分配/存储）    │
├─────────────────────────────────────────────────┤
│  Socialware Runtime                              │
│  Timeline / State / Role / Flow / Commitment     │
├─────────────────────────────────────────────────┤
│  ezagent 底层                                    │
│  elf (Block/DAG) / yrs (CRDT) / Zenoh (P2P)     │
│  RocksDB (本地) / Ed25519 (签名)                  │
└─────────────────────────────────────────────────┘
```

### 各 App 边界

| 维度 | TaskArena (ta:) | RePool (rp:) | EventWeaver (ew:) | AgentForge (af:) |
|---|---|---|---|---|
| 管什么 | 谁该做什么 | 东西存在哪 | 东西发生了什么 | 谁来做 |
| 数据 | Task 状态机 | 文件 bytes/位置 | 文件 event log + 分支 | Agent 身份/能力 |
| 自有存储 | — | 文件系统/对象存储 | eventstore.db（本地） | — |
| 核心价值 | 工作流推进 | 资源可用性 | 审计 + 分支 + 合并 | Agent 生命周期 |

### Content vs Artifact 划分

| | Socialware 管的 (Content) | EventWeaver 管的 (Artifact) |
|---|---|---|
| 是什么 | Timeline 中的 msg（组织级 action） | 文件的变更事件（文件级 delta） |
| 存在哪 | Timeline JSONL / CRDT | eventstore.db（节点本地） |
| 例子 | "alice 提交了审核" | "file-001 第3行改了" |
| 粒度 | action 级 | file delta 级 |

两套 event 通过 **file ref**（来自 RePool）关联：Socialware msg 引用 RePool 文件，EventWeaver 追踪该文件的变更历史。tool_usage 可推导关联关系。

## 3. 来源：从 elfiee 拆解

elfiee 是完整实现，需拆解到四个 App：

| elfiee 功能 | 归属 App | 说明 |
|---|---|---|
| Editor 管理（create/delete） | AgentForge | 身份/Agent 生命周期 |
| Task blocks（assign/commit） | TaskArena | 任务状态机 |
| ref 模式（hash/path/size） | RePool | 文件实际存储 |
| **Event sourcing (EAVT)** | **EventWeaver** | 核心保留 |
| **CBAC (grant/revoke)** | **EventWeaver** | 核心保留（语义改为分支策略） |
| **Document blocks** | **EventWeaver** | 核心保留 |
| **Session blocks** | **EventWeaver** | 核心保留 |
| **DAG (implement links)** | **EventWeaver** | 核心保留 |
| **Time travel** | **EventWeaver** | 核心保留 |
| **Vector Clock** | **EventWeaver** | 升级为自动分支管理 |

## 4. 核心机制

### 4.1 统一的权限-分支规则

**一条规则解释一切：**

```
任何写操作 + 有 grant  → 写入 owner 的主线，P2P 同步时 CRDT auto-merge
任何写操作 + 无 grant  → 自动分支，等 owner 处理
```

- 不拒绝任何写操作——所有人都能写，差别是进主线还是进分支
- "权限"的本质是 **merge policy**，不是 access control
- 分支是 P2P 同步时自动产生的，不是用户主动创建的
- 合并也是自动的（CRDT），只有冲突时才需要人工介入

适用于所有写操作类型：

```
内容编辑（document.write / session.append）  → 统一规则
关系变更（link / unlink）                     → 统一规则
元数据变更（rename / description）            → 统一规则
```

### 4.2 不可变约束

以下属性创建后不可修改，也不可通过分支修改：

| 属性 | 理由 |
|---|---|
| `block_id` | 身份标识 |
| `block_type` | 决定使用哪个 capability plugin |
| `owner` | 权限根源（谁的主线） |
| `created_at` | 出生时间 |

### 4.3 P2P 同步流程

```
Peer A (本地)                         Peer B (本地)
┌─────────────────┐                   ┌─────────────────┐
│ 本地 Event Store │                   │ 本地 Event Store │
│ e1 → e2 → e3    │                   │ e1 → e2 → e4    │
│                  │                   │                  │
│ 本地文件状态      │                   │ 本地文件状态      │
│ (从 events 派生) │                   │ (从 events 派生) │
└────────┬─────────┘                   └────────┬─────────┘
         │             断网重连/同步              │
         └──────────────────┬──────────────────────┘
                            ↓
                  检查 B 对该 block 的 grant
                            │
              ┌─────────────┴─────────────┐
              │                           │
         B 有 grant                   B 无 grant
              │                           │
         CRDT auto-merge              自动分支
         e1→e2→e3→e4(merged)          e1→e2→e3 (主线)
                                           └→e4 (B 的分支)
                                      │
                                 owner 审查
                                 ├── ew:resolve → 合入主线
                                 ├── ew:grant B → 未来 auto-merge
                                 └── reject → 丢弃
```

### 4.4 事件模型 (EAVT)

沿用 elfiee 的 EAVT 模型：

- **Entity**: block_id（被改变的块）
- **Attribute**: `"{author_id}/{cap_id}"`（谁做了什么）
- **Value**: JSON 载荷（具体变更内容，格式由 capability plugin 决定）
- **Timestamp**: Vector clock（因果排序 + 冲突检测）

四种事件 mode：

| Mode | 用途 | 示例 |
|---|---|---|
| `full` | 完整状态快照 | 块创建、小型配置文件 |
| `delta` | 增量差异 | 文档文本修改 |
| `ref` | 外部引用 | 二进制文件（hash/path/size，关联 RePool） |
| `append` | 追加条目 | Session 块的 append-only 语义 |

## 5. 架构

### 5.1 核心引擎

```
┌─ EventWeaver Core ────────────────────────────────────┐
│                                                       │
│  Event Store (EAVT, 不可变, 节点本地)                   │
│  权限表 (grant/revoke → 决定主线 vs 分支)               │
│  分支管理 (自动分叉 / CRDT 自动合并 / 冲突标记)          │
│  查询接口 (history / state_at / branches / query)      │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 5.2 Capability Plugin 机制

核心只管 "event 进来 → 存储 → 检查权限 → 主线或分支"。

具体怎么记录、怎么 diff、怎么渲染，由 plugin 决定：

```
Capability Plugin 接口:
  block_type     → 处理哪种块
  event_mode     → 用什么 mode 记录 (full/delta/ref/append)
  diff(old, new) → 怎么算差异
  merge(a, b)    → CRDT 怎么合并
  render(state)  → 怎么展示给人看

内置 plugins:
  ┌─ document ─┐  ┌─ session ──┐  ┌─ ref ───────┐
  │ mode=delta │  │ mode=append│  │ mode=ref    │
  │ diff: text │  │ diff: N/A  │  │ diff: hash  │
  │ merge: yrs │  │ merge: 追加│  │ merge: 按hash│
  │ render: md │  │ render: log│  │ render: link│
  └────────────┘  └────────────┘  └─────────────┘

未来可扩展:
  schema / config / notebook / ...
```

### 5.3 暴露的操作（CLI/MCP 工具 → §5）

```
块管理:
  ew:create {name, block_type, ...}     创建块（成为 owner）
  ew:delete {block_id}                  软删除

内容操作（由 plugin 处理）:
  ew:write {block_id, content}          写入内容（plugin 决定 mode）
  ew:read {block_id}                    读取当前状态

关系操作:
  ew:link {parent, child, relation}     添加 DAG 关系
  ew:unlink {parent, child, relation}   删除 DAG 关系

权限操作:
  ew:grant {block_id, editor_id, cap}   授权（允许 auto-merge）
  ew:revoke {block_id, editor_id, cap}  撤权

分支/冲突:
  ew:branches {block_id}               查看分支列表
  ew:resolve {branch_id, strategy}     解决冲突（accept/reject/manual）

查询/消费:
  ew:history {block_id}                事件历史（线性消费）
  ew:state_at {block_id, event_id}     时光回溯（非线性消费）
  ew:diff {block_id, from, to}         两点间差异
  ew:query {filter...}                 结构化查询
  ew:trace {event_id, depth}           因果链追溯
```

## 6. 协作示例：doc-review Room

展示 TaskArena + RePool + EventWeaver 如何组合工作。

### Room 结构

```
Room "doc-review"/
├── socialware-app/
│   ├── doc-audit.app.md     (namespace: da) ← TaskArena
│   ├── file-tracker.app.md  (namespace: ew) ← EventWeaver
│   └── storage.app.md       (namespace: rp) ← RePool
├── timeline/
└── state.json
```

### 流程

```
1. Alice 提交文档审核
   Timeline msg:  alice → da:submit {doc_ref: "rp:file-001"}
   TaskArena:     task-001 → pending_review
   RePool:        file-001 存储实际文件
   EventWeaver:   evt-001: file-001, op=create, mode=full

2. Bob 审核拒绝
   Timeline msg:  bob → da:reject {task: "task-001", reason: "..."}
   TaskArena:     task-001 → needs_revision
   （EventWeaver 无事发生——纯 flow 操作）

3. Alice 修改文档
   EventWeaver:   evt-002: file-001, op=edit, mode=delta, author=alice
   RePool:        file-001 更新存储
   Timeline msg:  alice → da:resubmit {task: "task-001"}

4. Bob 要求看修改历史
   bob → ew:history {file: "file-001"}
   → evt-001: create (alice, 01-10)
   → evt-002: edit   (alice, 01-11, diff: +15-3)
   bob → ew:diff {from: evt-001, to: evt-002}
   → 具体修改内容
   bob → da:reject {reason: "第3段仍有问题"}

5. Carol 帮忙改（Alice 授权过）
   前置: alice → ew:grant {file-001, carol, write}
   Carol 编辑 → P2P 同步 → 有 grant → CRDT auto-merge
   EventWeaver:   evt-003: file-001, op=edit, author=carol (主线)

6. Dave 也改了（无权限）—— 关键场景
   Dave 本地编辑 → 本地保存成功
   P2P 同步 → dave 无 grant → 自动分支
   EventWeaver:   evt-004: file-001, op=edit, author=dave (分支)

   Alice 查看:
     ew:branches {file-001} → "dave/file-001": 1 commit
   Alice 决定:
     ew:resolve {branch: "dave/file-001", strategy: "accept"} → 合入
     或 ew:grant {dave, ...} → 授权后自动合并
     或 ew:resolve {strategy: "reject"} → 丢弃

7. 最终通过
   alice → da:resubmit
   bob → ew:history → 完整审计轨迹（含分支合并记录）
   bob → da:approve
   TaskArena: task-001 → completed
```

## 7. 核心功能清单

```
✅ 完整记录 event
   ├── EAVT 模型（entity/attribute/value/timestamp）
   ├── 四种 mode（full/delta/ref/append）
   └── 不可变 event store（节点本地 SQLite/RocksDB）

✅ 关联 event 形成逻辑链条
   ├── DAG implement links — 块间因果关系
   ├── 同一 block 的 event 序列 — 时间线上的逻辑链
   └── tool_usage 推导 — Socialware msg event ↔ file event 关联

✅ 线性消费
   ├── history — 按时间顺序回放
   ├── state rebuild — 从 event 重建当前状态
   └── audit trail — 给其他 App 提供审计证据

✅ 非线性消费（时光回溯）
   ├── state_at_event — 任意历史点的状态
   ├── diff(from, to) — 任意两点间的差异
   └── branches — 并行世界线的状态

✅ 权限驱动的自动分支
   ├── 有 grant → auto-merge 到主线
   ├── 无 grant → 自动分支
   └── 冲突 → CRDT 尝试 auto-merge，失败则标记等人工 resolve

✅ Capability Plugin 可扩展
   ├── 按 block_type 注册 plugin
   ├── plugin 定义 diff/merge/render 逻辑
   └── 新 block type = 新 plugin
```

## 8. 待决问题

1. **EventWeaver 的 Socialware 合约结构**——Role/Flow/Commitment/Arena 具体怎么定义？需要在下一步设计。
2. **与 ezagent 底层的对接**——elfiee 的 Vector Clock 升级为 yrs CRDT 后，分支管理的实现细节。
3. **跨 App 引用协议**——EventWeaver 如何引用 RePool 中的文件？`rp:file-id` 格式？需要与 RePool 设计同步。
4. **Plugin 注册机制**——Capability plugin 是静态编译还是动态加载？遵循 ezagent 的 `.so` 扩展模型？
5. **owner 转让**——owner 是不可变的，但现实中可能需要转让所有权。是否通过 "delete + recreate" 模拟？

---

> 下一步: 设计 EventWeaver 的 Socialware 合约 (.socialware.md)
