# Socialware 产品形态定义

> 本文档定义 Socialware 生态中的产品形态、概念边界及其在模拟环境中的映射关系。

---

## 1. 核心概念

| 概念 | 定义 | 产品形态 | 类比 |
|------|------|----------|------|
| **Contract Template** | 组织蓝图，定义 Role / Flow / Commitment / Arena | `.socialware.md` 文件，可分发 | npm package / Docker image 定义 |
| **Room** | 持久化协作空间 | 基础设施单元（Timeline + CRDT + P2P） | Discord server / Slack workspace |
| **Socialware (installed)** | Contract 实例，在 Room 中激活 | Room 配置中的一个 namespace 条目 | 在 server 中安装的 Bot |
| **App** | 面向用户的交互命令集 | 由已安装 Socialware 定义的 commands、renderers、state panels | Bot 的 slash commands + UI panels |
| **External Tools** | 绑定到 App actions 的执行器 | 本地运行的 MCP / CLI / API 服务 | IDE 插件 / 本地工具链 |

### 关键区分

- **Room ≠ App**：Room 是空间，App 是空间内的命令集。Room 提供 Timeline 和状态基础设施，App 提供用户交互界面。
- **一个 Room 可以安装多个 Socialware**，每个 Socialware 提供不同的 namespace，互不冲突。
- **Contract Template ≠ Room**：Template 是蓝图，Room 是实例。同一份 Template 可以部署到多个 Room。
- **Template 名 ≠ App 名**：二者解耦。例如 `two-role-submit-approve.socialware.md` 安装后的 App 命名为 `doc-review.alice.two-role-submit-approve.app.md`。

---

## 2. 概念关系图

```
                        ┌─────────────────────┐
                        │  Contract Template   │
                        │  (.socialware.md)    │
                        │  状态: 模板 (只读)    │
                        └──────────┬──────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
             ┌───────────┐ ┌───────────┐ ┌───────────┐
             │  Room A   │ │  Room B   │ │  Room C   │
             │  (实例)    │ │  (实例)    │ │  (实例)    │
             └─────┬─────┘ └───────────┘ └───────────┘
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
     ┌─────────┐ ┌────┐ ┌────┐
     │ ns: ew  │ │ ta │ │ rp │    ← 多 namespace 共存
     │ .app.md │ │    │ │    │
     └─────────┘ └────┘ └────┘
          │
     ┌────┴────┐
     │ Timeline │  ← 所有 namespace 消息混合，namespace 前缀区分
     │ State    │  ← 单一 state.json，多 namespace flow_states
     └─────────┘
```

> 一个 Template 可以实例化到多个 Room；一个 Room 内可安装多个 Socialware，每个占据一个独立 namespace。

---

## 3. 生命周期时序

```
Room/Users          Socialware Dev    App Dev          App Install
     │                 │                  │                  │
     │ ① /room create  │                  │                  │
     │────────────────▶│                  │                  │
     │ 输出: 空 Room +   │                  │                  │
     │ Identity 文件    │                  │                  │
     │                 │                  │                  │
     │                 │ ② /socialware-dev │                  │
     │                 │─────────────────▶│                  │
     │                 │ 输出: Template    │                  │
     │                 │ (.socialware.md) │                  │
     │                 │ ③ /socialware-app-dev                │
     │                 │ 填 §5 工具        │                  │
     │                 │─────────▶        │                  │
     │                 │ 输出: app-store/  │                  │
     │                 │ {App}.{Dev}.     │                  │
     │                 │ {Sw}.app.md      │                  │
     │                 │                  │                  │
     │                 │  ④ /socialware-app-install           │
     │                 │                  │─────────────────▶│
     │                 │                  │ 填 §1 用户        │
     │                 │                  │ 输出: 已安装 App   │
     │                 │                  │                  │
     │                 │                  │  ⑤ /socialware-app│
     │                 │                  │                  │
     │                 │                  │  用户交互          │
     │                 │                  │  Timeline 增长    │
     │                 │                  │  State 派生       │
```

---

## 4. 制品出口

### 4.1 Socialware Dev → Contract Template

- **输入**：组织需求描述
- **工具**：`/socialware-dev`
- **输出**：`simulation/socialware/{name}.socialware.md`
  - 状态：`模板`
  - §5（绑定信息）全部标记为 `_待实现_`
- **约束**：Template 创建后为 **READ-ONLY**，不可修改

### 4.2 Room Management → Empty Room

- **输入**：Room 名称 + 创建者 Identity
- **工具**：`/room`
- **输出**：`simulation/workspace/rooms/{name}/`（空 Room，含 config.json）
  - config.json 初始结构：`{ membership: {...}, socialware: { installed: [], roles: {} } }`

### 4.3 Socialware App Dev → Developed App

- **输入**：Template + 工具绑定决策
- **工具**：`/socialware-app-dev`
- **输出**：`workspace/app-store/{AppName}.{DeveloperName}.{SocialwareName}.app.md`（状态：`已开发`，§5 已填工具，§1 仍为 `_待绑定_`）
- **注册**：在 `simulation/app-store/registry.json` 中创建条目

### 4.4 Socialware App Install → Installed App

- **输入**：Developed App + Room + 角色绑定决策
- **工具**：`/socialware-app-install`
- **输出**：
  - `workspace/rooms/{room}/contracts/{AppName}.{DeveloperName}.{SocialwareName}.app.md`（状态：`已安装`，§1 已填持有者）
  - 更新 `config.json`（`socialware.installed` 追加条目）

### 4.5 Socialware App Runtime → 用户交互

- **输入**：已安装的 Room
- **工具**：`/socialware-app`
- **输出**：Timeline 持续增长，State 实时派生

---

## 5. 同 Room 多 Namespace 交互

一个 Room 可同时安装多个 Socialware，例如 `ew`（EventWeaver）、`ta`（TaskArena）、`rp`（ResPool）三者共存：

### Timeline（混合消息流）

所有 namespace 的消息混合存储在同一 Timeline JSONL 文件中，通过 `ext.command.namespace` 区分：

```jsonl
{"ref_id":"msg-001","author":"alice:Alice@local","clock":1,"ext":{"command":{"namespace":"ew","action":"branch.create"},"reply_to":null},...}
{"ref_id":"msg-002","author":"alice:Alice@local","clock":2,"ext":{"command":{"namespace":"ta","action":"task.submit"},"reply_to":null},...}
{"ref_id":"msg-003","author":"bob:Bob@local","clock":3,"ext":{"command":{"namespace":"rp","action":"resource.request"},"reply_to":null},...}
{"ref_id":"msg-004","author":"alice:Alice@local","clock":4,"ext":{"command":{"namespace":"ew","action":"merge.request"},"reply_to":{"ref_id":"msg-001"}},...}
```

### State Cache（单一 state.json，多 namespace）

key 为 subject Ref 的 `ref_id`，通过 `flow` 字段中的 namespace 前缀区分：

```json
{
  "flow_states": {
    "msg-001": {
      "flow": "ew:branch_lifecycle",
      "state": "active",
      "subject_author": "alice:Alice@local"
    },
    "msg-003": {
      "flow": "ta:task_lifecycle",
      "state": "committed",
      "subject_author": "alice:Alice@local"
    },
    "msg-005": {
      "flow": "rp:resource_lifecycle",
      "state": "available",
      "subject_author": "bob:Bob@local"
    }
  }
}
```

### config.json

```json
{
  "socialware": {
    "installed": [
      {"app_id": "event-weaver.alice.event-weaver", "namespace": "ew", "contract": "event-weaver.alice.event-weaver.app.md", "template": "event-weaver.socialware.md"},
      {"app_id": "task-arena.alice.two-role-submit-approve", "namespace": "ta", "contract": "task-arena.alice.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"},
      {"app_id": "res-pool.bob.resource-pool", "namespace": "rp", "contract": "res-pool.bob.resource-pool.app.md", "template": "resource-pool.socialware.md"}
    ]
  }
}
```

### 跨 Namespace 引用

跨 namespace 引用 = 查询同一 `state.json`。例如，`ew:merge.execute` 需要检查 `ta:task_lifecycle` 是否有实例处于 `committed` 状态——只需遍历 `flow_states`，找到 `flow` 字段以 `ta:` 开头且 `state=="committed"` 的条目。

---

## 6. 外挂工具模型

外部工具在本地运行，只有结果（消息）同步到 Timeline。核心原则：

- **工具不入 Room**：工具在每个 peer 的本地环境中运行（MCP server、CLI 脚本、API 调用等）
- **只同步消息**：工具的执行结果作为 Message 写入 Timeline，其他 peer 只看到结果
- **不同 peer 可用不同工具**：就像 Git——你可以用任何编辑器，只要最终 commit 内容一致
- **工具绑定在 App 层**：`.app.md` 中定义 action 到 tool 的映射，但 tool 的具体实现由各 peer 自行决定

```
Peer A (MCP tool)           Peer B (CLI tool)
      │                           │
      │  tool.execute()           │  bash script
      │         │                 │       │
      ▼         ▼                 ▼       ▼
  ┌───────── Timeline (append-only, shared) ─────────┐
  │  msg1: result from A    msg2: result from B       │
  └───────────────────────────────────────────────────┘
```

---

## 7. 热重启

Timeline 是 append-only 的持久化日志。热重启流程：

```
关闭 Session
    │
    ▼
Timeline (持久化, 不丢失)
    │
    ▼
重新打开 /socialware-app
    │
    ▼
Replay Timeline → 重建 State
    │
    ▼
继续交互（从最新状态恢复）
```

关键保证：
- Timeline **永不丢失**（append-only log）
- State 是 Timeline 的 **纯函数派生**，随时可重建
- 热重启后状态与关闭前 **完全一致**

---

## 8. P2P 模拟

### 模式一：Multi-session（推荐）

每个 Claude Code session = 一个 peer。共享文件系统 = P2P 网络。

```
Session 1 (alice:Alice@local)    Session 2 (bob:Bob@local)
      │                               │
      ├── 读写 Room 目录 ──────────────┤
      │     (shared filesystem)        │
      │                               │
      │  Timeline / State 通过文件共享  │
```

- 优势：真实模拟多 peer 并发
- 约束：需要多个终端窗口

### 模式二：Single-session（降级方案）

使用 `/switch` 命令在同一 session 内切换 Identity。

```
/switch alice:Alice@local  →  以 alice 身份操作
/switch bob:Bob@local     →  以 bob 身份操作
```

- 优势：单终端即可运行
- 限制：无法模拟真正的并发

---

## 9. 与模拟环境的映射

| 真实产品组件 | 模拟环境对应 |
|-------------|-------------|
| ezagent client | Claude Code + Skill |
| Contract Template 分发 | `simulation/socialware/{name}.socialware.md` |
| Room | `simulation/workspace/rooms/{name}/` 目录 |
| 同 Room 多 Socialware | 同一 Room 目录下多个 `contracts/{AppName}.{DeveloperName}.{SocialwareName}.app.md` |
| P2P Zenoh 同步 | 共享文件系统（multi-session）或 `/switch`（single-session） |
| External MCP/API 工具 | `bash: echo "mock:..."` |
| Hook Pipeline | Claude Code 模拟 `pre_send` / `execute` / `after_write` |
| State Cache 重建 | `rebuild-state.py` |
| 热重启 | 关闭 → 重新打开 `/socialware-app` |

---

## 附录：术语速查

| 术语 | 全称 | 含义 |
|------|------|------|
| namespace (ns) | — | Socialware 在 Room 中的唯一标识符 |
| Timeline | — | Append-only 消息日志，Room 的持久化层 |
| State | State Cache | 从 Timeline 派生的当前状态快照 |
| CRDT | Conflict-free Replicated Data Type | 无冲突复制数据类型 |
| Hook Pipeline | — | 消息处理管线：pre_send → execute → after_write |
