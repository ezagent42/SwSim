# 05 — EventWeaver 的本机运行与组合运行

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 运行模式概览

EventWeaver 可以**独立运行**，也可以与其他 App **组合运行**。

```
模式 A: 独立运行                模式 B: 组合运行
┌──────────────┐              ┌──────────────────────────┐
│ Room         │              │ Room                     │
│              │              │                          │
│  ew: only    │              │  ta: TaskArena           │
│              │              │  ew: EventWeaver         │
│  纯文件追踪  │              │  rp: RePool              │
│  无工作流    │              │  af: AgentForge          │
│  无资源管理  │              │                          │
└──────────────┘              │  四 App 协作             │
                              └──────────────────────────┘
```

## 2. 独立运行

EventWeaver 单独安装在 Room 中，提供纯粹的文件事件溯源。

### 2.1 适用场景

- 个人文件版本追踪（单人，R1=R2）
- 小团队文档协作（多人，只需追踪变更和审查分叉）
- 审计日志（只关心"谁改了什么"，不需要工作流）

### 2.2 独立运行时的限制

| 功能 | 独立运行 | 说明 |
|---|---|---|
| 创建/追踪文件 | 可用 | 核心功能 |
| 编辑/分叉/合并 | 可用 | 核心功能 |
| 权限管理 | 可用 | 核心功能 |
| 事件查询/审计 | 可用 | 核心功能 |
| 文件实际存储 | **受限** | 无 RePool，只能用本地路径或内联内容 |
| 任务驱动的文件修改 | **不可用** | 无 TaskArena，无法关联"为什么改" |
| Agent 自动化 | **不可用** | 无 AgentForge，无法自动化贡献 |

### 2.3 §5 Bindings 中的体现

独立运行时，§5 Context Bindings 中的跨 App 引用全部为 `_无_`：

```markdown
### on: contribute
- 依赖: _无_        ← 不依赖其他 App 的 Flow 状态
- 委托: _无_        ← 不委托其他 App 的角色
- 资源: _无_        ← 不请求其他 App 的资源（文件内容内联）
```

## 3. 组合运行

### 3.1 Socialware 的三种跨 App 引用

| 引用类型 | 语法 | 含义 | 方向 |
|---|---|---|---|
| **依赖 (Requires)** | `[ns:flow.state](path)` | 当前 action 需要检查另一个 App 的 Flow 状态 | 读取 |
| **委托 (Delegates)** | `[ns:role](path)` | 当前 action 委托另一个 App 的角色执行 | 调用 |
| **资源 (Requests)** | `[ns:arena.resource](path)` | 当前 action 需要另一个 App 的资源 | 请求 |

### 3.2 EventWeaver + RePool

**关系：资源引用**

EventWeaver 追踪文件的**变更历史**，RePool 管理文件的**实际存储**。

```
ew:create (block_type=ref)
    │
    ▼ 资源引用
rp:allocate → 返回 file_id, path, hash
    │
    ▼
EventWeaver 记录 ref 模式事件:
  value = { "hash": "sha256:...", "path": "rp:file-001", "size": 1024 }
```

**§5 Bindings 体现：**

```markdown
### on: create
- 资源: [rp:arena.storage](同 Room)    ← 请求 RePool 分配存储

### on: contribute
- 资源: [rp:arena.storage](同 Room)    ← 更新 RePool 中的文件
```

**不使用 RePool 时**：文件内容直接内联在事件的 value 中（mode=full 或 mode=delta）。适合小文件或纯文本。

### 3.3 EventWeaver + TaskArena

**关系：依赖 + 委托**

TaskArena 管理"为什么要改文件"（任务），EventWeaver 记录"文件怎么改的"（事件）。

```
场景: Alice 提交任务 → 任务要求修改 auth-module → 修改被 EventWeaver 记录

ta:submit {doc_ref: "rp:file-001"}
    │
    ▼ 依赖关系
ew:create → 开始追踪 file-001
    │
ta:approve 前
    │
    ▼ 依赖 EventWeaver 审计证据
ew:audit {block: "file-001"} → 返回变更历史
    │
    ▼ 审批者基于审计证据决策
ta:approve / ta:reject
```

**§5 Bindings 体现：**

```markdown
### on: create （EventWeaver 侧）
- 依赖: [ta:task_lifecycle.submitted](同 Room)  ← 关联到哪个任务

### on: accept （EventWeaver 侧）
- 委托: [ta:notify](同 Room)                     ← 合并后通知 TaskArena
```

**反向引用（TaskArena 侧）：**

```markdown
### on: approve （TaskArena 侧）
- 依赖: [ew:audit](同 Room)                      ← 审批前查看变更历史
```

### 3.4 EventWeaver + AgentForge

**关系：委托**

AgentForge 管理 Agent 的生命周期和能力，EventWeaver 记录 Agent 的操作。

```
场景: Agent "code-bot" 被分配修改任务 → Agent 自动贡献 → EventWeaver 记录

af:create_agent {name: "code-bot", capabilities: ["ew:contribute"]}
    │
    ▼
Agent 自动调用 ew:contribute
    │
    ▼
EventWeaver 记录事件: attribute = "code-bot/contribute"
```

**§5 Bindings 体现：**

```markdown
### on: contribute （EventWeaver 侧）
- 委托: [af:agent.active](同 Room)    ← 验证 Agent 身份有效
```

### 3.5 EventWeaver + EventWeaver（跨 Room）

未来场景：同一个 block 被多个 Room 引用。

```
Room A: 安装了 ew-a，追踪 shared-doc
Room B: 安装了 ew-b，也追踪 shared-doc

ew-a 和 ew-b 通过 P2P 同步 shared-doc 的事件
```

目前 SwSim 中暂不实现跨 Room 引用。

## 4. 组合运行的完整示例

### doc-review Room

```
Room "doc-review"/
├── socialware-app/
│   ├── doc-audit.ta.app.md      (namespace: da)  ← TaskArena
│   ├── file-tracker.ew.app.md   (namespace: ew)  ← EventWeaver
│   └── storage.rp.app.md        (namespace: rp)  ← RePool
├── ew/
│   ├── eventstore.db
│   └── cache.db
├── timeline/
├── state.json
└── config.json
```

### 跨 App 引用关系图

```
        依赖                     资源
da:approve ──────→ ew:audit    ew:create ──────→ rp:allocate
                               ew:contribute ──→ rp:update

        委托                     依赖
ew:accept ───────→ da:notify   ew:create ──────→ da:task_lifecycle.submitted

        资源
da:submit ───────→ rp:allocate
```

### 完整数据流

```
1. alice → da:submit {title, doc}
   ├── TaskArena: task-001 → submitted
   ├── RePool: file-001 存储文件
   └── EventWeaver: ew:create → block-001 追踪 file-001
       └── 依赖: da:task_lifecycle.submitted (关联 task-001)
       └── 资源: rp:file-001

2. alice → ew:contribute {block-001, 修改内容}
   ├── EventWeaver: evt-002 (delta)
   └── 资源: rp:file-001 更新

3. bob → ew:audit {block-001}
   └── EventWeaver: 返回 [evt-001(create), evt-002(edit)]

4. bob → da:approve {task-001}
   ├── 依赖: ew:audit → 确认变更合理
   └── TaskArena: task-001 → approved
```

## 5. 依赖 / 委托 / 资源 汇总表

| EventWeaver Action | 依赖 (Requires) | 委托 (Delegates) | 资源 (Requests) |
|---|---|---|---|
| create | `[ta:task_lifecycle.submitted]` (可选) | _无_ | `[rp:arena.storage]` (可选) |
| contribute | _无_ | _无_ | `[rp:arena.storage]` (可选) |
| accept | _无_ | `[ta:notify]` (可选) | `[rp:arena.storage]` (可选) |
| reject | _无_ | `[ta:notify]` (可选) | _无_ |
| force_resolve | `[C1 violated]` | _无_ | `[rp:arena.storage]` (可选) |
| grant | _无_ | _无_ | _无_ |
| revoke | _无_ | _无_ | _无_ |
| view | _无_ | _无_ | _无_ |
| audit | _无_ | _无_ | _无_ |
| query | _无_ | _无_ | _无_ |
| relate | _无_ | _无_ | _无_ |
| archive | _无_ | _无_ | _无_ |

**"可选"** 表示：独立运行时为 `_无_`，组合运行时填入具体引用。App Dev 阶段决定。
