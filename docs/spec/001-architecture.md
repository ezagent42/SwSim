# 001 — Socialware 架构总览

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 核心洞察

**Socialware = 组织约束的 IM 协议。**

同样的人 + 不同的组织（不同的 Role / Flow / Commitment / Arena）= 不同的 App。

Socialware 将「组织」从隐性的社会契约变为显性的可执行文件。改变组织结构就是改变 App 的行为——不需要写一行代码。一份 `.socialware.md` 文件就是一个完整的组织定义；绑定身份和工具后，它就是一个可运行的 App。

---

## 2. 四原语

| Primitive | 图论类比 | 定义 | 说明 |
|-----------|---------|------|------|
| **Role** | Graph node type | 组织中的**位置**（不是人），附带 capabilities | 一个 Role 可以由人或 AI 担任；holder 是可替换的 |
| **Flow** | Directed edge + transition rules | **状态机**，定义 action 如何推进状态 | 每个 action 需要特定 Role 和 capability 才能执行 |
| **Commitment** | Constraint on edges | 角色间的**可追踪义务** | 触发条件 + 截止时间 + 义务内容 |
| **Arena** | Subgraph / boundary | **准入边界**，定义谁可以进入这个组织 | 控制 membership：role-based / anyone / invite_only |

四原语的关系：

```
Arena（边界）
  ├── Role（节点）── 定义参与者的位置和能力
  ├── Flow（边 + 转换规则）── 定义工作流的状态转换
  └── Commitment（边上的约束）── 定义角色间的契约承诺
```

---

## 3. 五步开发模型

### 3.1 Socialware Dev — 设计契约模板

- **输入**：组织需求描述（自然语言）
- **输出**：`.socialware.md` 模板文件
- **工作**：定义四原语（Role / Flow / Commitment / Arena），§5 Bindings 为 `_待实现_`，§1 Roles Holder 为 `_待绑定_`
- **存储**：`simulation/socialware/`
- **性质**：模板是只读产品，可分发、可复用

### 3.2 Room — 创建协作空间

- **输入**：Room 名称 + 创建者 Identity
- **输出**：Room 目录结构 + config.json + state.json
- **工作**：创建空间、添加成员，为后续安装 Socialware 做准备
- **存储**：`workspace/rooms/{name}/`
- **性质**：Room 是独立于 App 的基础设施

### 3.3 Socialware App Dev — 开发契约

- **输入**：模板
- **输出**：`.app.md` 已开发文件
- **工作**：复制模板 → 绑定 Tool 到 Action → 填写跨契约引用（§5 `_待实现_` → 具体绑定），§1 Roles Holder 保持 `_待绑定_`
- **存储**：`workspace/app-store/{app-id}.app.md`（App-ID 格式：`{AppName}.{DeveloperName}.{SocialwareName}`）
- **注册**：在 `simulation/app-store/registry.json` 中创建条目
- **性质**：已开发的 App，可安装到任意 Room
- **状态**：`已开发`

### 3.4 Socialware App Install — 安装到 Room

- **输入**：已开发的 App（来自 app-store，通过 `simulation/app-store/registry.json` 查询）+ 目标 Room
- **输出**：Room 中的 `.app.md` 已安装文件 + 更新 config.json
- **工作**：从 app-store 复制 → 绑定 Identity 到 Role（§1 `_待绑定_` → 具体身份）→ 注册到 Room
- **存储**：`workspace/rooms/{name}/contracts/{AppName}.{DeveloperName}.{SocialwareName}.app.md`
- **性质**：App 安装在 Room 中，可运行
- **状态**：`已安装`

### 3.5 Socialware App Runtime — 文字游戏执行

- **输入**：已安装的 App + 身份
- **输出**：Timeline entries（append-only JSONL）
- **工作**：自然语言 → 解析 action → Hook Pipeline → 消息持久化
- **性质**：Timeline 是唯一真相源，State 纯推导

```
Room Management    Socialware Dev    App Dev              App Install            App Runtime
───────────────    ──────────────    ──────────────────   ──────────────────     ──────────────────────
Create space       Design org graph  Bind tools           Bind identities        Execute by contract
│                 │                 │                    │                      │
│ config.json     │ .socialware.md  │ .app.md            │ .app.md (installed)  │ Timeline grows
│ state.json      │ (template)      │ (developed)        │ (bound + room)       │ State derives
▼                 ▼                 ▼                    ▼                      ▼
workspace/rooms/  socialware/       workspace/app-store/ rooms/{name}/contracts/ timeline/*.jsonl
```

**契约状态流转**：`模板` → `已开发` → `已安装`

---

## 4. Room 模型

**Room 是协作空间，不是 App。**

Room 类似 Discord server——一个 Room 可以承载多个 Socialware，每个 Socialware 作为一个 namespace 提供命令集。App = 已安装的 Socialware 提供的命令。

```
Room "alpha"
├── contracts/
│   ├── task-arena.alice.two-role-submit-approve.app.md   (namespace: ta)  → /ta.submit, /ta.approve
│   ├── event-weaver.alice.event-weaver.app.md            (namespace: ew)  → /ew.create_branch, /ew.merge
│   └── res-pool.bob.resource-pool.app.md                 (namespace: rp)  → /rp.request, /rp.allocate
├── config.json          (Room 配置 + 所有 namespace 注册)
├── state.json           (合并所有 namespace 的状态)
├── timeline/            (所有 App 共享的 append-only 时间线)
├── content/             (Content Objects)
└── artifacts/           (工具副产物)
```

**关键区分**：
- Room = 容器（space）
- Socialware = 组织定义（contract）
- App = 安装在 Room 中的 Socialware 实例（bound contract + runtime）
- Namespace = App 在 Room 中的命名空间前缀

---

## 5. Multi-Namespace 模型

多个 Socialware 安装在同一个 Room 中，每个拥有一个 namespace 前缀：

| Namespace | Socialware | 命令示例 |
|-----------|-----------|---------|
| `ew` | EventWeaver（代码协作） | `ew:create_branch`, `ew:merge` |
| `ta` | TaskArena（任务管理） | `ta:submit`, `ta:approve` |
| `rp` | ResPool（资源管理） | `rp:request`, `rp:allocate` |

### 5.1 状态共存

所有 namespace 的 flow_states 共存于同一个 `state.json`，key 为 subject Ref 的 `ref_id`：

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
      "state": "submitted",
      "subject_action": "task.submit",
      "subject_author": "bob:Bob@local",
      "last_action": "task.submit",
      "last_ref": "msg-002"
    },
    "msg-005": {
      "flow": "rp:resource_lifecycle",
      "state": "in_use",
      "subject_action": "resource.request",
      "subject_author": "alice:Alice@local",
      "last_action": "resource.allocate",
      "last_ref": "msg-007"
    }
  }
}
```

### 5.2 跨 Namespace 引用

跨 namespace 交互 = 查询同一个 `state.json`，按 `flow` 字段中的 namespace 前缀过滤：

```
ew:merge.execute 需要检查 ta:task_lifecycle 的状态
→ 遍历 state.json 的 flow_states，找到 flow 字段以 "ta:" 开头的条目
→ 检查对应 state 是否满足前置条件
→ 无需跨 Room 文件读取，全在同一个 state.json 中
```

---

## 6. Hook Pipeline

每条消息经过三阶段 Hook Pipeline：

```
用户输入（自然语言 / 命令）
        │
        ▼
┌─────────────────────────────────────────────┐
│  Phase 1: pre_send                          │
│                                             │
│  ① Role Check — 发送者是否持有所需 Role      │
│  ② CBAC Check — Capability-Based Access     │
│     · any: 任何持有 required_role 的人       │
│     · author: 仅 flow instance 创建者        │
│     · author | role:{R}: 创建者 OR 管理角色   │
│  ③ Flow Check — 当前状态是否允许此 action     │
│  ④ Cross-Namespace Check — 跨 namespace 依赖 │
│                                             │
│  任一检查失败 → 拒绝，返回错误消息             │
└─────────────────┬───────────────────────────┘
                  │ 通过
                  ▼
┌─────────────────────────────────────────────┐
│  Phase 2: execute                           │
│                                             │
│  ① 运行绑定的 Tool（bash / mcp / api / llm）│
│  ② 捕获 Tool 输出                           │
│  ③ 生成 Content Object                      │
│  ④ 存储 Artifacts（如有副产物）              │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  Phase 3: after_write                       │
│                                             │
│  ① Append Ref to Timeline（JSONL）          │
│  ② Update State（flow_states, commitments） │
│  ③ Broadcast（通知其他 peer / namespace）    │
└─────────────────────────────────────────────┘
```

---

## 7. CRDT / Timeline as Truth

### 7.1 核心原则

- **Timeline 是唯一真相源**：消息以 append-only JSONL 格式持久化
- **State 是纯函数推导**：`State = f(Timeline)`
- **可重建性**：删除 `state.json` → 从 Timeline 重放 → State 完全重建
- **不可变性**：Timeline 条目一旦写入，永不修改或删除

### 7.2 Lamport Clock

每条 Timeline entry 携带 Lamport timestamp，用于因果排序：

```
Lamport Clock 规则：
1. 发送消息前：local_clock += 1，附加 clock 值
2. 接收消息时：local_clock = max(local_clock, received_clock) + 1
3. 因果关系：if msg_a.clock < msg_b.clock, then a happened-before b
4. 并发消息：clock 相同时，用 peer_id 字典序打破平局
```

### 7.3 数据流

```
写操作                          读操作
────────                        ────────
用户 action                     查询 state.json
    │                               │
    ▼                               ▼
Hook Pipeline                   State Cache
    │                           (pure-derived)
    ▼
Timeline (append JSONL)
    │
    ▼
State Update (derive)
```

---

## 8. P2P 模拟模型

SwSim 使用共享文件系统模拟 P2P 网络：

### 8.1 Multi-Session 模式（推荐）

每个 Claude Code session = 一个 peer identity。多个 session 共享 `simulation/workspace/` 文件系统。

```
Terminal A                    Terminal B
──────────                    ──────────
Claude Code session           Claude Code session
Identity: alice:Alice@local    Identity: bob:Bob@local
    │                             │
    └──── 共享文件系统 ────────────┘
          simulation/workspace/
          └── rooms/alpha/
              ├── timeline/    ← 两个 peer 都追加
              └── state.json   ← 两个 peer 都读写
```

**文件系统 = P2P 网络**：
- 文件写入 = 消息广播
- 文件读取 = 消息接收
- 文件锁 = 并发控制（OS 级别）

### 8.2 Single-Session 模式（Fallback）

单个 session 使用 `/switch {username}:{nickname}@{namespace}` 切换身份：

```
/switch alice:Alice@local    → 以 Alice 身份操作
/switch bob:Bob@local        → 以 Bob 身份操作
```

切换时显示「收件箱」—— 自上次切换以来对方发送的消息。

---

## 9. 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwSim Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Room             Socialware Dev    App Dev          App Install         App Runtime      │
│   ────             ─────────────    ────────         ───────────         ──────────────   │
│   /room            /socialware-dev  /socialware-     /socialware-        /socialware-app  │
│     │                   │            app-dev          app-install             │           │
│     ▼                   ▼                │                 │                  ▼           │
│   config.json      .socialware.md   .app.md           .app.md          Hook Pipeline     │
│   state.json       (template)       (developed)       (installed)      ┌──────────────┐  │
│                                          │                 │           │ pre_send     │  │
│                                          ▼                 │           │ execute      │  │
│                                     app-store/             │           │ after_write  │  │
│                                                            ▼           └──────┬───────┘  │
│                                                       Room (workspace)        │          │
│                                                                         Timeline (JSONL) │
│                         ┌──────────────┐      ┌──────────────┐ │
│                         │ config.json  │      │ append-only  │ │
│                         │ contracts/   │      │ Lamport clk  │ │
│                         │ state.json   │◄─────│ causal order │ │
│                         │ content/     │      └──────────────┘ │
│                         │ artifacts/   │                       │
│                         └──────────────┘                       │
│                                                                 │
│   P2P Layer (Simulated)                                        │
│   ─────────────────────                                        │
│   Shared Filesystem = Zenoh P2P Network                        │
│   Each Claude Code session = One Peer                          │
│   /switch = Single-session fallback                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. 术语表

| 术语 | 定义 |
|------|------|
| Socialware | 契约文件（`.socialware.md`），用四原语定义组织 |
| Socialware App | 开发并安装后的契约（`.app.md`）+ 运行时 workspace |
| App Store | 已开发但未安装的 App 存储目录（`workspace/app-store/`），注册信息在 `simulation/app-store/registry.json` |
| Room | 协作空间，可承载多个 Socialware |
| Namespace | Socialware 在 Room 中的命名前缀（如 `ew`, `ta`） |
| Timeline | Append-only JSONL，唯一真相源 |
| State | 从 Timeline 纯推导的 JSON 缓存 |
| Hook Pipeline | 消息处理三阶段管线：pre_send → execute → after_write |
| CBAC | Capability-Based Access Control，基于能力的访问控制 |
| Lamport Clock | 逻辑时钟，用于因果排序 |
| Content Object | 消息的实际内容载体 |
| Ref | Timeline 中的引用条目，指向 Content Object |
| Artifact | Tool 执行的副产物，存储在 `artifacts/` |
