# TC-007: 单会话 P2P

> **测试目标**：验证 `/switch` 身份切换 + inbox 收件箱机制
> **前置依赖**：TC-004（已有基础运行时和消息记录）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：006 (Section 6.2)

---

## 场景：单 session 内 Alice 和 Bob 交替协作

### Step 1: 以 alice 启动

- **操作**：执行 `/socialware-app`，Room=doc-review，Identity=alice:Alice@local
- **前置依赖**：TC-003 已完成
- **验证**：启动面板正确
- **验收标准**：
  - 当前 Identity 为 alice:Alice@local
  - 显示 alice 的角色和可用操作
  - `peer_cursors["alice:Alice@local"]` 初始为 0

### Step 2: alice 提交任务

- **操作**：alice 提交任务"审核 Q1 报告"
- **前置依赖**：Step 1
- **验证**：消息写入 Timeline
- **验收标准**：
  - Timeline 新增 msg-001，clock=1
  - `flow_states["msg-001"].state` = `submitted`
  - `peer_cursors["alice:Alice@local"]` 更新为 1

### Step 3: 切换到 bob

- **操作**：执行 `/switch bob:Bob@local`
- **前置依赖**：Step 2
- **验证**：身份切换成功，收件箱显示
- **验收标准**：
  - 当前 Identity 变为 bob:Bob@local
  - 显示 bob 的角色和可用操作（da:approve, da:reject）
  - **收件箱显示**：所有 clock > `peer_cursors["bob:Bob@local"]` 的消息
  - 收件箱包含：`[clock:1] alice:Alice@local 提交了任务: 审核 Q1 报告`

### Step 4: bob 审批

- **操作**：bob 审批 msg-001
- **前置依赖**：Step 3
- **验证**：审批成功
- **验收标准**：
  - Timeline 新增 msg-002，clock=2
  - `flow_states["msg-001"].state` = `approved`
  - `peer_cursors["bob:Bob@local"]` 更新为 2

### Step 5: 切换回 alice

- **操作**：执行 `/switch alice:Alice@local`
- **前置依赖**：Step 4
- **验证**：收件箱显示 bob 的审批
- **验收标准**：
  - 当前 Identity 变为 alice:Alice@local
  - 收件箱显示 clock > `peer_cursors["alice:Alice@local"]`（即 clock > 1）的消息
  - 收件箱包含：`[clock:2] bob:Bob@local 审批通过`
  - `peer_cursors["alice:Alice@local"]` 更新为 2

### Step 6: 多轮交互

- **操作**：alice 提交第二个任务 → /switch bob:Bob@local → bob 驳回 → /switch alice:Alice@local → alice revise
- **前置依赖**：Step 5
- **验证**：多轮切换中 peer_cursors 正确追踪
- **验收标准**：
  - 每次 `/switch` 后的收件箱仅显示自上次操作以来的**新**消息
  - 不重复显示已看过的消息
  - peer_cursors 在每次操作后正确递增
  - 所有状态转换正确

### Step 7: 收件箱为空的情况

- **操作**：alice 操作后立即 `/switch alice:Alice@local`（无新消息）
- **前置依赖**：Step 6
- **验证**：收件箱正确显示为空
- **验收标准**：
  - `peer_cursors["alice:Alice@local"]` 已是最新
  - 收件箱显示"无新消息"
  - 不显示历史消息

### Step 8: 验证 peer_cursors 持久化

- **操作**：读取 `state.json` 检查 peer_cursors
- **前置依赖**：Step 6
- **验证**：所有 cursor 值正确
- **验收标准**：
  - `peer_cursors["alice:Alice@local"]` = alice 最后操作的 clock
  - `peer_cursors["bob:Bob@local"]` = bob 最后操作的 clock
  - 两个 cursor 值可能不同（取决于最后操作的顺序）
