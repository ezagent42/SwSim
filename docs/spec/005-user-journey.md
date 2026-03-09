# 005 — 用户旅程：从创建 Room 到运行 App

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 旅程总览

```
创建/加入 Room  →  浏览 Socialware  →  安装 App  →  运行 App  →  多方协作
     │                  │                 │              │            │
   /room         contracts/目录    /socialware-app-dev  /socialware-app  /switch
```

本文档覆盖一个 P2P 节点从创建 Room 到运行 App 的完整用户旅程。

---

## 2. 创建/加入 Room（`/room` Skill）

Room 是协作空间，是所有 Socialware 运行的容器。

### 2.1 `/room create {name}` — 创建 Room

**操作**：在 `simulation/workspace/rooms/` 下创建 Room 目录结构。

```
simulation/workspace/rooms/{name}/
├── contracts/       ← 已安装的 App 契约
├── config.json      ← Room 配置（成员、namespace 注册）
├── state.json       ← 状态缓存（初始为空）
├── timeline/        ← Append-only 时间线
├── content/         ← Content Objects
└── artifacts/       ← 工具副产物
```

**初始 config.json**：

```json
{
  "room_id": "{name}",
  "name": "{name}",
  "created_at": "{ISO 8601}",
  "membership": {
    "members": [
      {
        "identity": "@{creator}:local",
        "display_name": "{Creator}",
        "joined_at": "{ISO 8601}"
      }
    ]
  },
  "socialware": {
    "installed": [],
    "roles": {}
  }
}
```

**初始 state.json**：

```json
{
  "version": 1,
  "last_clock": 0,
  "last_updated": "{ISO 8601}",
  "flow_states": {},
  "role_map": {},
  "commitments": {},
  "peer_cursors": {}
}
```

### 2.2 `/room list` — 列出所有 Room

**操作**：扫描 `simulation/workspace/rooms/` 下的所有目录，展示每个 Room 的摘要信息。

**输出格式**：

```
Room 列表:
──────────
1. alpha — 2 members, 2 apps installed (ta, ew), clock: 15
2. beta  — 1 member,  0 apps installed, clock: 0
3. gamma — 3 members, 1 app installed (su), clock: 42
```

### 2.3 `/room show {name}` — 查看 Room 详情

**操作**：读取 Room 的 config.json 和 state.json，展示完整信息。

**输出格式**：

```
Room: alpha
───────────
创建时间: 2026-03-09T10:00:00Z

成员:
  @alice:local (Alice) — joined 2026-03-09
  @bob:local (Bob) — joined 2026-03-09

已安装 Socialware:
  ta — TaskArena (two-role-submit-approve.socialware.md)
       R1(提交者) → @alice:local
       R2(审批者) → @bob:local
  ew — EventWeaver (event-weaver.socialware.md)
       R1(开发者) → @alice:local
       R2(审查者) → @bob:local
       R3(合并者) → @alice:local

活跃 Flow Instances (显示格式, state.json 中 key 为 ref_id):
  msg-001 [ta:task_lifecycle] — submitted (by @alice, clock: 1)
  msg-003 [ew:branch_lifecycle] — open (by @alice, clock: 3)

Lamport Clock: 5
```

### 2.4 `/room join {name}` — 加入 Room

**操作**（模拟环境）：将当前 Identity 添加到 Room 的 config.json 的 membership 中。

```json
{
  "identity": "@charlie:local",
  "display_name": "Charlie",
  "joined_at": "2026-03-09T12:00:00Z"
}
```

---

## 3. 浏览可用 Socialware

### 3.1 模板目录

所有可用的 Socialware 模板存放在 `simulation/contracts/`：

```
simulation/contracts/
├── two-role-submit-approve.socialware.md    ← 双角色提交-审批
├── event-weaver.socialware.md               ← 代码协作工作流
├── resource-pool.socialware.md              ← 资源管理
└── standup.socialware.md                    ← 每日站会
```

### 3.2 模板即产品

每个 `.socialware.md` 是一个**可分发的产品**：

- **分发方式**：Git 共享、文件复制、Room 内消息附件
- **只读**：模板一旦创建不修改
- **可复用**：同一模板可在多个 Room 中以不同 namespace 安装
- **自描述**：模板文件本身包含完整的组织定义

### 3.3 阅读模板

浏览模板时关注：

1. **§1 Roles**：有哪些角色？需要多少参与者？
2. **§2 Flows**：工作流的状态转换是什么？
3. **§3 Commitments**：角色间有什么义务？
4. **§4 Arena**：准入策略是什么？
5. **§5 Context Bindings**：需要绑定哪些依赖？（`_待绑定_` vs `_无_`）

---

## 4. 安装 Socialware 到 Room（`/socialware-app-dev` Skill）

### 4.1 安装流程

```
选择模板                选择 Room + Namespace         绑定                    完成
────────               ─────────────────────         ────                    ────
从 contracts/ 选模板    指定目标 Room + namespace 前缀  绑定 Identity + Tool    生成 .app.md + 更新 config.json
```

### 4.2 Step 1 — 选择模板

从 `simulation/contracts/` 中选择一个 `.socialware.md` 模板。

```
可用模板:
1. two-role-submit-approve.socialware.md — 双角色提交-审批
2. event-weaver.socialware.md — 代码协作工作流
3. standup.socialware.md — 每日站会

选择: 1
```

### 4.3 Step 2 — 选择 Namespace

为 App 选择一个 namespace 前缀（短缩写，在 Room 内唯一）。

```
Namespace 前缀 (2-4个字符): ta
```

**注意**：模板名和 namespace 是解耦的。模板 `two-role-submit-approve.socialware.md` 可以安装为 namespace `ta`。

### 4.4 Step 3 — 绑定 Identity 到 Role

将 Room 中的成员绑定到模板定义的角色：

```
角色绑定:
  R1 (提交者) → @alice:local
  R2 (审批者) → @bob:local
```

### 4.5 Step 4 — 绑定 Tool 到 Action

为每个 Action 选择工具类型和具体绑定：

```
工具绑定:
  task_lifecycle.submit  → manual
  task_lifecycle.approve → manual
  task_lifecycle.reject  → manual
  task_lifecycle.revise  → manual
```

### 4.6 Step 5 — 填写跨契约引用

如果 §5 中有 `_待绑定_` 的依赖/委托/资源，填入具体引用：

```
跨契约引用:
  task_lifecycle.approve.依赖 → [ta:task_lifecycle.submitted](state.json)
  task_lifecycle.reject.依赖  → [ta:task_lifecycle.submitted](state.json)
  (其他均为 _无_)
```

### 4.7 Step 6 — 生成文件

- 生成 `workspace/rooms/{room}/contracts/{ns}.app.md`
- 更新 `workspace/rooms/{room}/config.json`（添加 namespace 到 `socialware.installed`，添加 role_map）

---

## 5. 运行 App（`/socialware-app` Skill）

### 5.1 启动

指定 Room 和 Identity 启动 App Runtime：

```
/socialware-app

Room: alpha
Identity: @alice:local
```

### 5.2 启动面板

启动后显示当前状态面板：

```
╔══════════════════════════════════════════════════╗
║  Socialware App Runtime                          ║
║──────────────────────────────────────────────────║
║  Room:     alpha                                 ║
║  Identity: @alice:local                          ║
║  Clock:    5                                     ║
║──────────────────────────────────────────────────║
║  你的角色:                                        ║
║    ta:R1 (提交者) — submit, revise               ║
║    ew:R1 (开发者) — create_branch, push          ║
║    ew:R3 (合并者) — merge                        ║
║──────────────────────────────────────────────────║
║  可用操作:                                        ║
║    ta:submit  — 提交新任务                        ║
║    ta:revise  — 修改已驳回的任务 (需 author CBAC)  ║
║    ew:create_branch — 创建新分支                  ║
║    ew:push    — 推送代码到分支                     ║
║    ew:merge   — 合并分支                          ║
║──────────────────────────────────────────────────║
║  活跃 Flow Instances:                             ║
║    ta:task_lifecycle:task-001 — submitted         ║
║    ew:branch_lifecycle:feature-auth — open        ║
╚══════════════════════════════════════════════════╝
```

### 5.3 交互模式

用户用自然语言或命令与 App 交互：

```
用户: 我想提交一个新任务，标题是"实现用户认证模块"

解析:
  → Namespace: ta
  → Flow: task_lifecycle
  → Action: submit
  → Instance: task-002

执行 Hook Pipeline:
  pre_send:
    ✓ Role Check: @alice 持有 R1
    ✓ CBAC Check: any → 通过
    ✓ Flow Check: _none_ → submit → submitted
  execute:
    Tool: manual
    Input: { title: "实现用户认证模块", description: "..." }
    Output: Content Object → content/msg-006.json
  after_write:
    ✓ Append Ref → timeline/shard-001.jsonl (clock: 6)
    ✓ Update State: ta:task_lifecycle:task-002 = submitted
    ✓ Broadcast: 通知 @bob

结果:
  📋 @alice:local 提交了任务: 实现用户认证模块
```

### 5.4 消息持久化

所有消息持久化到 Timeline（append-only JSONL）。State 从 Timeline 纯推导。

```
timeline/shard-001.jsonl:
{"ref_id":"msg-006","author":"@alice:local","content_type":"immutable","content_id":"sha256:f4d5e6","created_at":"2026-03-09T14:00:00Z","status":"active","clock":6,"signature":"sim:not-verified","ext":{"reply_to":null,"command":{"namespace":"ta","action":"task.submit","invoke_id":"inv-006"},"channels":["main"]}}
```

---

## 6. 多方协作（Multi-Peer Collaboration）

### 6.1 Multi-Session 模式（推荐）

每个参与者开启独立的 Claude Code session，共享 `simulation/workspace/` 文件系统：

```
Terminal A (Alice)                    Terminal B (Bob)
──────────────────                    ─────────────────
$ claude                              $ claude
/socialware-app                       /socialware-app
Room: alpha                           Room: alpha
Identity: @alice:local                Identity: @bob:local

Alice 提交任务                         Bob 看到新消息（通过读取 timeline）
  → Timeline 追加 entry                 → 审批任务
  → State 更新                           → Timeline 追加 entry
  → Bob 下次读取时看到                    → State 更新
```

**文件系统 = P2P 网络**：
- Alice 写入 timeline → Bob 读取 timeline = 消息传递
- 共享 state.json = 状态同步
- 文件锁 = 并发控制

### 6.2 Single-Session 模式（Fallback）

单个 session 使用 `/switch` 切换身份：

```
/switch @alice:local
> 我是 Alice，提交任务...
(执行 ta:submit → Timeline 追加 entry)

/switch @bob:local
> 我是 Bob

收件箱 (自上次 @bob 操作以来的新消息):
──────────────────────────────────────
  [clock:6] 📋 @alice:local 提交了任务: 实现用户认证模块

> 审批这个任务，意见是"方案可行"
(执行 ta:approve → Timeline 追加 entry)
```

**收件箱机制**：
- 切换身份时，显示自上次该 Identity 操作以来的所有新 Timeline entries
- 基于 `peer_cursors` 跟踪每个 peer 的最后已读 clock

### 6.3 新消息发现

无论哪种模式，新消息的发现机制：

1. 读取 `state.json` 中的 `peer_cursors.{identity}`（integer，最后已读 clock）
2. 扫描 Timeline 中 clock 值大于上述值的 entries
3. 展示为「收件箱」

---

## 7. 跨 Namespace 交互

### 7.1 同一 Room 内的跨 Namespace

同一 Room 中安装了多个 Socialware，它们的 flow_states 共存于一个 state.json：

```
场景: ew:merge 需要检查 ta:task_lifecycle 的状态

用户: 合并 feature-auth 分支

解析:
  → ew:branch_lifecycle.merge

pre_send:
  ✓ Role Check: @alice 持有 ew:R3 (合并者)
  ✓ CBAC Check: any → 通过
  ✓ Flow Check: open → merge → merged
  ✓ Cross-NS Check:
      遍历 flow_states，找到 flow=="ta:task_lifecycle" 且 state=="committed" 的实例
      → 找到 msg-005: { flow: "ta:task_lifecycle", state: "committed" } → 通过

execute:
  Tool: bash: git merge feature-auth
  Output: 合并成功

after_write:
  ✓ Append Ref (clock: 16)
  ✓ Update State: ew:branch_lifecycle:feature-auth = merged
```

### 7.2 跨 Namespace 查询

所有查询都在同一个 state.json 内，使用不同的 namespace 前缀：

```python
# 跨 namespace 查询：读取 state.json，按 flow 字段中的 namespace 前缀过滤
import json

state = json.loads(open("state.json").read())

# 查询 ta namespace 的任务状态
ta_states = {k: v for k, v in state["flow_states"].items()
             if v["flow"].startswith("ta:")}

# 查询 ew namespace 的分支状态
ew_states = {k: v for k, v in state["flow_states"].items()
             if v["flow"].startswith("ew:")}

# 跨 namespace 前置检查：ew:merge 需要 ta:task_lifecycle 处于 committed
ta_committed = any(
    v["state"] == "committed"
    for v in ta_states.values()
    if v["flow"] == "ta:task_lifecycle"
)
```

**关键**：无需跨 Room 文件读取。所有 namespace 的状态在同一个文件中。

---

## 8. Hot Restart — 热重启

### 8.1 基本热重启

关闭 session → 重新打开 → 用 `/socialware-app` 重新启动：

```
# 关闭 session（Ctrl+C 或关闭终端）

# 重新打开
$ claude
/socialware-app
Room: alpha
Identity: @alice:local

# Timeline 持久化 → State 从文件加载 → 继续运行
# 启动面板显示最新状态
```

### 8.2 修改契约后热重启

可以修改契约/Hook 逻辑，然后重启：

```
步骤:
1. 关闭当前 session
2. 编辑 contracts/ta.app.md（修改 Flow 或绑定）
3. 重新启动 /socialware-app
4. 重放 Timeline → 新逻辑生效
```

**注意**：修改 Flow 定义可能导致已有 Timeline entries 与新规则冲突。建议只做向后兼容的修改（增加状态/action，不删除已有的）。

---

## 9. State Rebuild — 状态重建（`/rebuild`）

### 9.1 重建流程

```
/rebuild

步骤:
1. 删除 state.json
2. 创建空的初始 State
3. 按 Lamport clock 顺序遍历 Timeline 中的所有 entries
4. 对每个 entry:
   a. 提取 ext.command (namespace, action) 和 ext.reply_to
   b. subject 动作（reply_to=null）→ 创建 flow instance（key=ref_id）
   c. 后续动作 → 沿 reply_to 链回溯找到 flow instance → 状态转换
   d. 更新 flow_states, commitments, peer_cursors
5. 保存新的 state.json

结果:
  ✓ State 重建完成
  ✓ 处理了 42 条 Timeline entries
  ✓ 恢复了 5 个 flow instances
  ✓ 恢复了 3 个 active commitments
```

### 9.2 CRDT 证明

State Rebuild 证明了 CRDT 属性：

```
State = f(Timeline)

即:
  给定相同的 Timeline（消息集合），
  无论从哪个节点、什么时间点开始重建，
  都会得到相同的 State。
```

这意味着：
- **无需备份 State**：随时可从 Timeline 重建
- **跨 Peer 一致性**：所有 peer 从相同 Timeline 推导出相同 State
- **调试友好**：怀疑 State 不对？删除重建即可验证

### 9.3 重建脚本

完整实现见 `.claude/skills/socialware-app/scripts/rebuild-state.py`。

```bash
# 用法
python .claude/skills/socialware-app/scripts/rebuild-state.py \
    simulation/workspace/rooms/project-alpha

# 指定契约目录（默认读取 room 内的 contracts/）
python .claude/skills/socialware-app/scripts/rebuild-state.py \
    simulation/workspace/rooms/project-alpha \
    simulation/workspace/rooms/project-alpha/contracts
```

核心逻辑：
1. 读取 Room 中所有 `contracts/*.app.md`，解析每个 namespace 的 §2 Flow 转换表和 §3 Commitments
2. 读取 `timeline/*.jsonl`，按 Lamport clock 排序
3. 逐条重放：
   - subject 动作（`reply_to=null`）→ 创建新 flow instance
   - 后续动作 → 沿 `reply_to` 链回溯找到 flow instance → 执行状态转换
   - 触发 Commitment 事件
4. 输出重建的 `state.json`（flow_states + role_map + commitments + peer_cursors）

支持多 namespace：自动扫描 Room 内所有 `.app.md`，按文件名提取 namespace。

---

## 10. 完整用户旅程示例

以下是 Alice 和 Bob 从零开始的完整旅程：

```
=== Step 1: Alice 创建 Room ===
Alice> /room create alpha
✓ Room "alpha" 创建成功

=== Step 2: Bob 加入 Room ===
Bob> /room join alpha
✓ @bob:local 已加入 Room "alpha"

=== Step 3: Alice 浏览模板 ===
Alice> ls simulation/contracts/
  1. two-role-submit-approve.socialware.md

=== Step 4: Alice 安装 Socialware ===
Alice> /socialware-app-dev
模板: two-role-submit-approve.socialware.md
Room: alpha
Namespace: ta
角色绑定: R1 → @alice:local, R2 → @bob:local
工具绑定: 全部 manual
✓ ta.app.md 已安装到 Room "alpha"

=== Step 5: Alice 运行 App ===
Alice> /socialware-app
Room: alpha, Identity: @alice:local
(显示启动面板)

Alice> 提交任务：实现用户认证
✓ 📋 @alice:local 提交了任务: 实现用户认证 (clock: 1)

=== Step 6: Bob 运行 App ===
Bob> /socialware-app
Room: alpha, Identity: @bob:local

收件箱:
  [clock:1] 📋 @alice:local 提交了任务: 实现用户认证

Bob> 审批通过，方案可行
✓ ✅ @bob:local 审批通过: 方案可行 (clock: 2)

=== Step 7: Alice 看到审批结果 ===
Alice> (刷新/重连)

收件箱:
  [clock:2] ✅ @bob:local 审批通过: 方案可行

任务 task-001 状态: approved ✓

=== Step 8: 验证 State ===
Alice> /rebuild
✓ State 重建完成，与当前 state.json 一致
  CRDT 属性验证通过
```
