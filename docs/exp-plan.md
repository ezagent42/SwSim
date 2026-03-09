# Socialware 端到端实验计划

> 本文档设计两轮递进式实验，验证 Socialware 从 Template 创建到多 namespace 协作的完整生命周期。

---

## 实验总览

| 轮次 | 名称 | 目标 | 复杂度 |
|------|------|------|--------|
| Round 1 | SimpleApproval | 基础验证：单 Template、单 Room、单 namespace 的完整生命周期 | 2 Role, 1 Flow |
| Round 2 | Multi-namespace Room | 组合验证：同 Room 多 Socialware、跨 namespace 引用、多 session P2P | 3 Template, 3 namespace |

---

## Round 1: SimpleApproval（基础验证）

### 目标

验证完整生命周期：Template 创建 → Room 创建 → App 绑定安装 → 用户运行 → State 重建。使用最简单的 2-role 审批流。

### 步骤

#### Step 1: `/socialware-dev` — 设计审批 Contract Template

设计一个 2-role 审批合约模板：

- **Roles**:
  - `poster`：提交文档，发起审批
  - `approver`：审阅文档，批准或驳回
- **Flow**: `approval_lifecycle`
  ```
  pending ──approve──▶ approved
     │
     └──reject───▶ rejected
  ```
- **Commitment**: `C1` — approver 必须在 24h 内完成审阅
- **Arena**: 持有任意 Role 即可进入
- **输出**: `simulation/contracts/two-role-submit-approve.socialware.md`
  - 状态：`模板`
  - §5 绑定信息全部标记为 `_待绑定_`

#### Step 2: `/room create doc-review` — 创建 Room

- 创建 Room `doc-review`
- 添加成员：`@alice:local`、`@bob:local`
- **输出**: `simulation/workspace/rooms/doc-review/`
  - `config.json`: 包含 membership + 空 socialware.installed
  - `identities/`: Room 成员引用
  - `timeline/shard-001.jsonl`: 空文件
  - `state.json`: 初始空状态

#### Step 3: `/socialware-app-dev` — 绑定并安装

- **Template**: `two-role-submit-approve.socialware.md`
- **Namespace**: `da`（doc-approval）
- **角色绑定**:
  - `@alice:local` = `poster`
  - `@bob:local` = `approver`
- **工具绑定**:
  - `submit` action → manual（手动输入）
  - `approve` / `reject` action → bash（命令行确认）
- **输出**:
  - `workspace/rooms/doc-review/contracts/da.app.md`（状态：`已绑定`）
  - `config.json` 更新：`socialware.installed: ["da"]`

#### Step 4: `/socialware-app` — 运行

执行完整审批流程：

1. `@alice:local` 提交一份文档
   - Timeline 追加：`{ ns: "da", action: "doc.submit", author: "@alice:local" }`
   - Flow state: `da:approval_lifecycle:doc-001` → `pending`
   - Commitment `C1` 激活：`@bob:local` 24h 审阅倒计时开始
2. `/switch @bob`（或切换到独立 session）
3. `@bob:local` 查看 inbox，看到待审文档
4. `@bob:local` 执行 approve
   - Timeline 追加：`{ ns: "da", action: "doc.approve", author: "@bob:local" }`
   - Flow state: `da:approval_lifecycle:doc-001` → `approved`
   - Commitment `C1` 完成

#### Step 5: `/rebuild` — CRDT 验证

1. 备份当前 `state.json`
2. 删除 `state.json`
3. 执行 `rebuild-state.py`，从 Timeline 重建 State
4. 对比重建后的 `state.json` 与备份：**必须完全一致**

### 验证矩阵

| 检查项 | 预期结果 |
|--------|----------|
| Template 未被修改 | `simulation/contracts/two-role-submit-approve.socialware.md` 内容与创建时完全一致 |
| Room 目录结构 | `workspace/rooms/doc-review/` 包含 identities/, contracts/, timeline/, content/, artifacts/, config.json, state.json |
| Room config 正确 | config.json 包含 membership.members 有 @alice:local 和 @bob:local |
| 绑定副本存在 | `workspace/rooms/doc-review/contracts/da.app.md` 存在，状态为 `已绑定` |
| config.json 更新 | `socialware.installed: ["da"]`，`socialware.roles` 包含角色映射 |
| 命名解耦 | 模板名 `two-role-submit-approve` ≠ namespace 名 `da`，互不影响 |
| Timeline 完整性 | `timeline/shard-001.jsonl` 中所有消息具有正确的 Lamport clock 递增序列 |
| Ref 格式正确 | 每条 Ref 包含 ref_id, author, clock, ext.command.namespace="da" |
| State 重建一致性 | 删除 state.json → rebuild-state.py 重建 → 与原始完全匹配 |
| Commitment 追踪 | `da:C1` 在 submit 时激活（status=active），在 approve 时完成（status=fulfilled） |
| Identity 文件存在 | `workspace/identities/@alice.json` 和 `@bob.json` 存在 |

---

## Round 2: Multi-namespace Room（组合验证）

### 目标

验证同一 Room 内多 Socialware 共存、跨 namespace 引用、多 session P2P 协作、以及全量 State 重建。

### 步骤

#### Step 1: 设计三个 Contract Template

**Template 1: EventWeaver**
- Roles: `emitter`、`brancher`、`merger`、`observer`、`admin`
- Flow: `branch_lifecycle`
  ```
  created ──activate──▶ active ──request_merge──▶ merge_pending ──merge──▶ merged
                           │
                           └──archive──▶ archived
  ```
- 输出: `simulation/contracts/event-weaver.socialware.md`

**Template 2: TaskArena**
- Roles: `poster`、`worker`、`reviewer`
- Flow: `task_lifecycle`
  ```
  open ──assign──▶ in_progress ──submit──▶ review ──approve──▶ committed
                                              │
                                              └──reject──▶ in_progress
  ```
- 输出: `simulation/contracts/task-arena.socialware.md`

**Template 3: ResPool**
- Roles: `requester`、`allocator`
- Flow: `resource_lifecycle`
  ```
  available ──request──▶ reserved ──allocate──▶ in_use ──release──▶ available
                            │
                            └──cancel──▶ available
  ```
- 输出: `simulation/contracts/res-pool.socialware.md`

#### Step 2: `/room create project-alpha` — 创建 Room

- 创建 Room `project-alpha`
- 添加 3 名成员：`@alice:local`、`@bob:local`、`@carol:local`
- **输出**: `simulation/workspace/rooms/project-alpha/`

#### Step 3: 安装三个 Socialware 到同一 Room

分别执行三次 `/socialware-app-dev`：

| Namespace | Template | 角色绑定 |
|-----------|----------|----------|
| `ew` | event-weaver.socialware.md | @alice:local=brancher, @bob:local=merger, @carol:local=observer |
| `ta` | task-arena.socialware.md | @alice:local=poster, @bob:local=worker, @carol:local=reviewer |
| `rp` | res-pool.socialware.md | @alice:local=requester, @bob:local=allocator |

**输出**:
- `workspace/rooms/project-alpha/contracts/ew.app.md`
- `workspace/rooms/project-alpha/contracts/ta.app.md`
- `workspace/rooms/project-alpha/contracts/rp.app.md`
- `config.json`: `socialware.installed: ["ew", "ta", "rp"]`

#### Step 4: 准备跨 Namespace 状态

在正式跨 namespace 测试前，先推进各 namespace 的 Flow 到指定状态：

1. **ta namespace**：创建 task-001，推进到 `committed`
   - @alice 提交 task → @bob 领取 → @bob 提交成果 → @carol 审核通过
   - 最终状态：`ta:task_lifecycle:task-001` = `committed`

2. **rp namespace**：创建 resource-001，推进到 `available`
   - @bob 创建资源 → 初始状态即为 `available`
   - 最终状态：`rp:resource_lifecycle:res-001` = `available`

#### Step 5: 跨 Namespace 交互测试

**场景**：`ew:merge.execute` 需要检查 `ta:task_lifecycle:task-001` 处于 `committed` 状态后才能执行 merge。

执行流程：
1. @alice 创建 branch-001（`ew:branch_lifecycle:branch-001` → `active`）
2. @alice 请求 merge（`ew:branch_lifecycle:branch-001` → `merge_pending`）
3. @bob 执行 merge：
   - **前置检查**：读取 `state.json`，确认 `ta:task_lifecycle:task-001` == `committed`
   - **通过**：执行 merge，`ew:branch_lifecycle:branch-001` → `merged`
4. 验证：单一 `state.json` 中跨 namespace 查询正常工作

#### Step 6: Multi-session P2P 测试

使用 `start-p2p.sh` 启动 tmux 多 pane 模拟：

```bash
.claude/skills/socialware-app/scripts/start-p2p.sh project-alpha @alice @bob
```

**tmux pane 1 — @alice**:
1. 自动启动 `/socialware-app`，进入 Room `project-alpha`
2. 创建新 branch：`ew:branch_lifecycle:branch-002` → `created` → `active`
3. 提交新 task：`ta:task_lifecycle:task-002` → `open`

**tmux pane 2 — @bob**:
1. 自动启动 `/socialware-app`，进入 Room `project-alpha`
2. 执行 `/inbox`，看到 @alice 创建的 branch 和 task
3. 领取 task-002：`ta:task_lifecycle:task-002` → `in_progress`
4. 请求 merge branch-002

**可选：启动 Timeline 监听器**（第三个 pane）:
```bash
.claude/skills/socialware-app/scripts/watch-timeline.sh project-alpha @observer
```

**验证**：
- `/inbox` 正确显示其他 peer 的新消息（基于 peer_cursors）
- watch-timeline.sh 实时打印 Timeline 变化通知
- 两个 session 的操作不冲突，Lamport clock 序列正确递增
- 关闭 @bob 会话 → 重新打开 → `/inbox` 显示期间错过的消息

#### Step 7: `/rebuild` — 全量重建

1. 备份当前 `state.json`
2. 删除 `state.json`
3. 执行 `rebuild-state.py`
4. 验证重建后的 `state.json` 包含所有三个 namespace 的 flow_states：
   - `ew:*` 系列状态
   - `ta:*` 系列状态
   - `rp:*` 系列状态
5. 对比：**必须与备份完全一致**

#### Step 8: 迭代验证

1. 修改某个 Contract 的 Flow 逻辑（例如给 `task_lifecycle` 增加一个 `blocked` 状态）
2. 重新执行 `/rebuild`
3. 验证新逻辑正确生效，旧数据兼容

### 验证矩阵

| 检查项 | 预期结果 |
|--------|----------|
| 3 个 Template 存在 | `simulation/contracts/` 下有 3 个 `.socialware.md` 文件，状态均为 `模板` |
| 3 个 App 安装在 Room 中 | `contracts/ew.app.md`、`ta.app.md`、`rp.app.md` 均存在，状态为 `已绑定` |
| config.json 多 namespace | `socialware.installed: ["ew", "ta", "rp"]`，roles 包含所有角色映射 |
| 单一 state.json | 包含 `ew:*`、`ta:*`、`rp:*` 三组 flow_states |
| Namespace 前缀正确 | Timeline 中每条 Ref 的 `ext.command.namespace` 与对应 Socialware 匹配 |
| 跨 namespace 引用 | `ew:merge.execute` 正确检查 `ta:task_lifecycle` 状态为 `committed` |
| 跨 namespace 失败 | 当 `ta:task_lifecycle` 不在 `committed` 时，`ew:merge.execute` 被阻止 |
| Multi-session 启动 | `start-p2p.sh` 成功创建 tmux session，两个 pane 各自以不同身份运行 |
| /inbox 同步 | Peer B 的 `/inbox` 正确显示 Peer A 的新消息 |
| watch-timeline.sh | 实时打印其他 peer 的 Timeline 变化通知 |
| 断连恢复 | 关闭 Peer B → 重新打开 → `/inbox` 显示期间 Peer A 的所有操作 |
| Lamport clock 连续 | 两个 session 交替操作后，Timeline 中 clock 严格递增 |
| 全量重建 | rebuild-state.py 重建后 state.json 与原始完全匹配，覆盖所有 3 个 namespace |
| 迭代兼容 | 修改 Flow 定义后 `/rebuild` 正确应用新逻辑，旧数据不丢 |

---

## 附录：执行顺序与制品关系

### 制品依赖图

```
Round 1:

  Step 1                    Step 2                Step 3                    Step 4           Step 5
  /socialware-dev           /room create          /socialware-app-dev       /socialware-app  /rebuild
       │                        │                       │                       │               │
       ▼                        ▼                       ▼                       ▼               ▼
  contracts/                rooms/doc-review/     rooms/doc-review/         timeline/shard-001.jsonl    state.json
  two-role-submit-          config.json           contracts/da.app.md       (消息追加)        (重建验证)
  approve.socialware.md     (空 Room)             config.json (更新)


Round 2:

  Step 1                    Step 2                Step 3                      Step 4-6          Step 7
  /socialware-dev ×3        /room create          /socialware-app-dev ×3      /socialware-app   /rebuild
       │                        │                       │                         │               │
       ▼                        ▼                       ▼                         ▼               ▼
  contracts/                rooms/project-alpha/  rooms/project-alpha/        timeline/shard-001.jsonl     state.json
  ├─ event-weaver.sw.md     config.json           contracts/                  (多 ns 消息)      (全量重建)
  ├─ task-arena.sw.md       (空 Room)             ├─ ew.app.md
  └─ res-pool.sw.md                               ├─ ta.app.md
                                                   └─ rp.app.md
                                                   config.json (3 ns)
```

### 制品清单

| 阶段 | 产出制品 | 路径 | 创建者 |
|------|----------|------|--------|
| R1-S1 | 审批 Template | `simulation/contracts/two-role-submit-approve.socialware.md` | `/socialware-dev` |
| R1-S2 | doc-review Room | `simulation/workspace/rooms/doc-review/` | `/room` |
| R1-S3 | da App | `workspace/rooms/doc-review/contracts/da.app.md` | `/socialware-app-dev` |
| R1-S4 | Timeline 数据 | `workspace/rooms/doc-review/timeline/shard-001.jsonl` | `/socialware-app` |
| R1-S4 | State 快照 | `workspace/rooms/doc-review/state.json` | `/socialware-app` |
| R2-S1 | EventWeaver Template | `simulation/contracts/event-weaver.socialware.md` | `/socialware-dev` |
| R2-S1 | TaskArena Template | `simulation/contracts/task-arena.socialware.md` | `/socialware-dev` |
| R2-S1 | ResPool Template | `simulation/contracts/res-pool.socialware.md` | `/socialware-dev` |
| R2-S2 | project-alpha Room | `simulation/workspace/rooms/project-alpha/` | `/room` |
| R2-S3 | ew/ta/rp Apps | `workspace/rooms/project-alpha/contracts/*.app.md` | `/socialware-app-dev` |
| R2-S4~6 | Timeline 数据 | `workspace/rooms/project-alpha/timeline/shard-001.jsonl` | `/socialware-app` |
| R2-S7 | 重建 State | `workspace/rooms/project-alpha/state.json` | `rebuild-state.py` |

### 两轮实验的递进关系

```
Round 1 (基础验证)                         Round 2 (组合验证)
─────────────────                         ─────────────────
单 Template                         ──▶   3 Templates
单 Room                             ──▶   单 Room (但内容更丰富)
单 Namespace                        ──▶   3 Namespaces 共存
/switch 身份切换                     ──▶   Multi-session P2P
单 Flow 重建                        ──▶   跨 Namespace 全量重建
无跨 Namespace 依赖                  ──▶   跨 Namespace 前置条件检查
```

> Round 1 确认基础机制可用后，Round 2 验证组合场景的正确性和可扩展性。
