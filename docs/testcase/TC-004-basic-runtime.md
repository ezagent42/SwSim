# TC-004: 基础运行时

> **测试目标**：验证单 namespace 完整 Flow 执行——从启动 App 到完成全部状态转换
> **前置依赖**：TC-003（App 已绑定安装）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：003, 005

---

## 场景：在 doc-review Room 执行完整审批流程

### Step 1: 启动 App Runtime

- **操作**：执行 `/socialware-app`，选择 Room=doc-review，Identity=@alice:local
- **前置依赖**：TC-003 已完成（da.app.md 已安装）
- **验证**：启动面板正确显示
- **验收标准**：
  - 显示 Room 名称：doc-review
  - 显示 Identity：@alice:local
  - 显示角色：da:R1（提交者）
  - 显示可用操作：da:submit, da:revise
  - 显示 Lamport Clock：0
  - 显示活跃 Flow Instances：（空）

### Step 2: 提交任务（subject action）

- **操作**：以 @alice:local 身份提交任务，标题"审核 Q1 报告"
- **前置依赖**：Step 1
- **验证**：Timeline 和 State 更新
- **验收标准**：
  - Timeline `shard-001.jsonl` 新增一行，ref_id 为 `msg-001`
  - Ref 的 `ext.command.namespace` = `da`
  - Ref 的 `ext.command.action` = `task.submit`（或对应 action 名）
  - Ref 的 `ext.reply_to` = `null`（subject action）
  - Ref 的 `clock` = `1`
  - Content Object 写入 `content/sha256_{hash}.json`
  - `state.json` 的 `flow_states` 新增 key `msg-001`
  - `flow_states["msg-001"].flow` = `da:task_lifecycle`
  - `flow_states["msg-001"].state` = `submitted`
  - `flow_states["msg-001"].subject_author` = `@alice:local`
  - `last_clock` = `1`

### Step 3: 验证 Content Object

- **操作**：读取 `content/sha256_{hash}.json`
- **前置依赖**：Step 2
- **验证**：Content Object 格式完整
- **验收标准**：
  - `content_id` 以 `sha256:` 开头
  - `type` = `immutable`
  - `author` = `@alice:local`
  - `body` 包含提交的任务内容
  - `format` 有值
  - `created_at` 为有效 ISO 8601
  - `signature` = `sim:not-verified`

### Step 4: 切换身份审批（approve）

- **操作**：切换到 @bob:local（`/switch @bob`），审批 msg-001
- **前置依赖**：Step 2
- **验证**：状态正确转换
- **验收标准**：
  - Timeline 新增一行，ref_id 为 `msg-002`
  - Ref 的 `ext.reply_to.ref_id` = `msg-001`（指向被审批的任务）
  - Ref 的 `ext.command.action` = `task.approve`（或对应 action 名）
  - Ref 的 `clock` = `2`
  - `flow_states["msg-001"].state` 从 `submitted` 变为 `approved`
  - `flow_states["msg-001"].last_action` = `task.approve`
  - `flow_states["msg-001"].last_ref` = `msg-002`
  - `last_clock` = `2`

### Step 5: 验证终态

- **操作**：读取 `state.json`，确认 Flow 到达终态
- **前置依赖**：Step 4
- **验证**：`approved` 是终态，无后续可用 action
- **验收标准**：
  - `flow_states["msg-001"].state` = `approved`
  - 对 msg-001 执行任何后续 action（如再次 approve）应被拒绝
  - `/status` 命令显示 msg-001 为 approved

### Step 6: 驳回场景（reject）

- **操作**：@alice 提交新任务 msg-003，@bob 驳回
- **前置依赖**：Step 1
- **验证**：reject 分支正确工作
- **验收标准**：
  - @alice submit → `flow_states["msg-003"].state` = `submitted`，clock = 3
  - @bob reject → `flow_states["msg-003"].state` = `rejected`，clock = 4
  - msg-003 的 reject Ref 的 `ext.reply_to.ref_id` = `msg-003`

### Step 7: 修改并重新提交（revise）

- **操作**：@alice 对被驳回的 msg-003 执行 revise
- **前置依赖**：Step 6
- **验证**：revise 将状态从 rejected 拉回 submitted
- **验收标准**：
  - `flow_states["msg-003"].state` 从 `rejected` 变为 `submitted`
  - Ref 的 `ext.reply_to.ref_id` = `msg-003`（指向原始 flow instance）
  - clock = 5
  - revise 后 @bob 可再次 approve 或 reject

### Step 8: 验证 Timeline 完整性

- **操作**：读取 `timeline/shard-001.jsonl`
- **前置依赖**：Step 7
- **验证**：所有操作都已记录
- **验收标准**：
  - Timeline 共 5 行（msg-001 到 msg-005）
  - 每行是有效 JSON
  - clock 值严格递增：1, 2, 3, 4, 5
  - 每行的 `status` = `active`
  - 每行的 `signature` = `sim:not-verified`
  - reply_to 链正确：msg-002→msg-001, msg-004→msg-003, msg-005→msg-003

### Step 9: 验证 peer_cursors

- **操作**：检查 `state.json` 的 `peer_cursors`
- **前置依赖**：Step 7
- **验证**：两个 peer 的 cursor 正确
- **验收标准**：
  - `peer_cursors["@alice:local"]` = 最后 @alice 操作时的 clock
  - `peer_cursors["@bob:local"]` = 最后 @bob 操作时的 clock
  - 所有 cursor 值 ≤ `last_clock`
