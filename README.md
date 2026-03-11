# SwSim — Socialware 契约文件模型模拟

## 什么是 Socialware

Socialware 是一份**契约文件**（`.socialware.md`），用四个原语定义一个组织：

| 原语 | 含义 | 类比 |
|------|------|------|
| **Role** | 节点——参与者的角色定义 | 组织架构图的节点 |
| **Flow** | 状态机——工作流的状态转换 | 业务流程图 |
| **Commitment** | 义务——角色间的契约承诺 | SLA / 合同条款 |
| **Arena** | 边界——协作的作用域与约束 | 部门 / 项目空间 |

**核心公式**：Socialware = 组织约束的 IM 协议。Organization = App。

同样的人 + 不同的组织（不同的 Role/Flow/Commitment/Arena）= 不同的 App。

## 什么是 Socialware App

Socialware App = 绑定后的契约（`.app.md`）+ 运行时 workspace。

```
Template (.socialware.md) + Identity bindings + Tool bindings = Runnable App (.app.md)
```

模板是组织的抽象设计，App 是模板的具体实例——绑定了真实身份和工具后，可以在 Room 中运行。

## 五步开发模型

### 1. `/room` — 创建协作空间（+ 身份）

- 输入：Room 名称 + 创建者身份
- 输出：Room 目录结构 + config.json + identity 文件
- 工作内容：创建 Room，创建身份（身份入口），添加成员

### 2. `/socialware-dev` — 设计组织图

- 输入：组织需求描述
- 输出：模板文件（`.socialware.md`）
- 工作内容：定义 Role、Flow、Commitment、Arena

### 3. `/socialware-app-dev` — 开发 App（填工具）

- 输入：模板
- 输出：`app-store/{app-id}.app.md`（已开发，§5 已填工具，§1 仍为 `_待绑定_`）
- 工作内容：复制模板到 app-store，为每个 Action 绑定工具

### 4. `/socialware-app-install` — 安装 App 到 Room（绑用户）

- 输入：app-store 中的已开发 App + 目标 Room
- 输出：`rooms/{room}/contracts/{app-id}.app.md`（已安装，§1 已填持有者）
- 工作内容：选择 namespace，绑定 Identity 到 Role，安装到 Room

### 5. `/socialware-app` — 文字游戏运行时

- 输入：已安装的 App
- 输出：Timeline 中的持久化交互记录
- 工作内容：以某个 Role 身份运行，执行 Flow，履行 Commitment

## Room 模型

**Room ≠ App**。

Room 是一个**协作空间**，可以承载多个 Socialware。每个安装的 Socialware 提供一个 namespace 的命令集。多个 namespace 共存于同一个 Room 的 `state.json` 中。

```
Room "alpha"
├── ta.app.md        (namespace: ta)    → /ta.submit, /ta.approve
├── standup.app.md   (namespace: su)    → /su.report, /su.summarize
└── state.json       (合并所有 namespace 的状态)
```

## 目录结构

```
SwSim/
├── .claude/               # Claude Code configuration
│   ├── skills/            # Skill definitions
│   │   ├── socialware-dev/
│   │   ├── socialware-app-dev/
│   │   ├── socialware-app-install/
│   │   ├── socialware-app/
│   │   └── room/
│   └── scripts/           # Hook scripts
├── docs/
│   ├── exp-plan.md        # End-to-end experiment plan
│   ├── prd.md             # Product form definition
│   └── spec/
│       ├── 001-architecture.md
│       ├── 002-socialware-contract.md
│       ├── 003-socialware-app-contract.md
│       ├── 004-local-apps.md
│       ├── 005-user-journey.md
│       ├── 006-p2p-simulation.md
│       └── 007-developer-integration.md
├── simulation/
│   ├── contracts/         # Socialware templates (.socialware.md, read-only)
│   └── workspace/
│       ├── identities/    # Global identities
│       ├── app-store/     # Developed apps (.app.md, awaiting install)
│       └── rooms/
│           └── {room_name}/
│               ├── identities/   # Room members
│               ├── contracts/    # Installed apps (.app.md)
│               ├── config.json
│               ├── timeline/
│               ├── content/
│               ├── artifacts/
│               └── state.json
└── README.md
```

## Quick Start

### 第一步：设计组织

```
/socialware-dev
```

描述你的组织需求，Skill 会引导你定义 Role、Flow、Commitment、Arena，输出 `.socialware.md` 模板文件到 `simulation/contracts/`。

### 第二步：创建 Room

```
/room create my-project
```

创建协作空间，添加成员（Identity）。Room 是 Socialware 的运行容器——先有空间，再安装 App。

### 第三步：开发 App

```
/socialware-app-dev
```

选择模板，为每个 Action 绑定工具，生成 `.app.md` 到 `app-store/`。

### 第四步：安装到 Room

```
/socialware-app-install
```

从 app-store 选择已开发 App，选择目标 Room，绑定 Identity 到 Role，安装到 Room 的 `contracts/` 目录。

### 第五步：运行

```
/socialware-app
```

以某个角色身份进入 Room，开始文字游戏式的交互。所有操作记录到 Timeline（append-only JSONL），State 从 Timeline 纯推导。

## P2P 多用户通信

### Multi-session 模式（推荐）

每个 peer 一个独立的 Claude Code 会话，共享文件系统 = P2P 网络。

**一键启动**：

```bash
# tmux 自动创建多 pane（n identity → 2n pane: peer + watcher）
.claude/skills/socialware-app/scripts/start-p2p.sh project-alpha alice:Alice@local bob:Bob@local

# 如果 session 已存在，使用 --force 销毁并重建
.claude/skills/socialware-app/scripts/start-p2p.sh --force project-alpha alice:Alice@local bob:Bob@local
```

```
┌─────────────────────┬─────────────────────┐
│ Peer: alice:Alice@local │ Peer: bob:Bob@local │
│ Room: project-alpha │ Room: project-alpha │
│ /socialware-app     │ /socialware-app     │
│                     │                     │
│ > 提交任务...       │ > /inbox            │
│ [clock:3] 已提交    │ 📬 1 条新消息:      │
│                     │ [3] alice → submit  │
└─────────────────────┴─────────────────────┘
```

**通信机制**：

| 操作 | 实现 |
|------|------|
| 发送消息 | append 到 `timeline/shard-xxx.jsonl` |
| 接收消息 | 读取 timeline 中 clock > peer_cursor 的行 |
| 实时通知 | `watch-timeline.sh`（inotifywait 或 2s 轮询） |
| 主动查询 | `/inbox` 命令 |
| 并发控制 | Lamport clock + 用户驱动的天然序列化 |
| 状态恢复 | `/rebuild` 从 timeline 重建 state.json |

**脚本**：

- `scripts/start-p2p.sh` — tmux 多 pane 启动
- `scripts/watch-timeline.sh` — 实时消息通知

详见 `docs/spec/006-p2p-simulation.md`。

### Single-session 模式（fallback）

单个 session 中使用 `/switch entity:Nickname@local` 切换身份，模拟多方交互。切换时自动显示收件箱。

## 核心洞察

> 同样的人 + 不同的组织（不同的 Role/Flow/Commitment/Arena）= 不同的 App。

Socialware 将「组织」从隐性的社会契约变为显性的可执行文件。改变组织结构，就是改变 App 的行为——而不需要写一行代码。
