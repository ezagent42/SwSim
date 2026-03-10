# TC-006: CBAC 权限控制

> **测试目标**：验证 Capability-Based Access Control 三种类型——any / author / author|role:{R}
> **前置依赖**：TC-004（已有基础运行时和 Flow Instance）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：001, 002, 003

---

## 场景：针对每种 CBAC 类型的正向和负向测试

### Step 1: 准备多 Flow Instance

- **操作**：@alice 提交 2 个任务（msg-001, msg-003），产生 2 个 Flow Instance
- **前置依赖**：TC-004 Step 1
- **验证**：2 个 Flow Instance 都处于 submitted 状态
- **验收标准**：
  - `flow_states["msg-001"].state` = `submitted`，`subject_author` = `@alice:local`
  - `flow_states["msg-003"].state` = `submitted`，`subject_author` = `@alice:local`

### Step 2: `any` — 正向测试

- **操作**：@bob 对 msg-001 执行 `approve`（CBAC=any，Required Role=R2）
- **前置依赖**：Step 1
- **验证**：任何持有 R2 的人都可审批
- **验收标准**：
  - @bob 持有 R2 → CBAC `any` 检查通过
  - `flow_states["msg-001"].state` = `approved`

### Step 3: `any` — 负向测试（角色不匹配）

- **操作**：@alice（仅 R1）尝试对 msg-003 执行 `approve`（Required Role=R2）
- **前置依赖**：Step 1
- **验证**：虽然 CBAC=any，但 Role Check 先拒绝
- **验收标准**：
  - @alice 不持有 R2
  - 操作被拒绝（Role Check 在 CBAC Check 之前）
  - 错误信息包含"角色不匹配"
  - Timeline 无新增

### Step 4: `author` — 正向测试

- **操作**：@bob 驳回 msg-003，然后 @alice 执行 `revise`（CBAC=author）
- **前置依赖**：Step 1
- **验证**：subject_author 可执行 author CBAC 操作
- **验收标准**：
  - msg-003 的 `subject_author` = `@alice:local`
  - @alice 执行 revise → CBAC `author` 检查通过
  - `flow_states["msg-003"].state` 从 `rejected` 变为 `submitted`

### Step 5: `author` — 负向测试

- **操作**：@bob 尝试对 msg-003 执行 `revise`（CBAC=author）
- **前置依赖**：Step 4（msg-003 处于 rejected）
- **验证**：非 author 被拒绝
- **验收标准**：
  - msg-003 的 `subject_author` = `@alice:local`
  - @bob ≠ @alice → CBAC `author` 检查失败
  - 操作被拒绝
  - 错误信息包含"仅原始作者可执行"
  - Timeline 无新增

### Step 6: `author|role:{R}` — author 路径

- **操作**：假设某 action 的 CBAC 为 `author | role:R2`，@alice（subject_author）执行该 action
- **前置依赖**：需要一个包含 `author|role:{R}` CBAC 的 Flow
- **验证**：author 身份满足条件
- **验收标准**：
  - @alice 是 flow instance 的 subject_author
  - 即使 @alice 不持有 R2，也因 author 身份通过
  - 操作成功执行

### Step 7: `author|role:{R}` — role 路径

- **操作**：同一 action，@bob（持有 R2，非 author）执行
- **前置依赖**：Step 6
- **验证**：持有指定角色的人也能通过
- **验收标准**：
  - @bob 不是 flow instance 的 subject_author
  - @bob 持有 R2 → `role:R2` 条件满足
  - 操作成功执行

### Step 8: `author|role:{R}` — 两者都不满足

- **操作**：@charlie（既非 author 也不持有 R2）尝试执行该 action
- **前置依赖**：Step 6（需要 @charlie 加入 Room 并持有其他角色）
- **验证**：两个条件都不满足则拒绝
- **验收标准**：
  - @charlie 既非 subject_author 也不持有 R2
  - CBAC 检查失败
  - 操作被拒绝
  - 错误信息包含两个条件的说明

### Step 9: CBAC 回溯验证

- **操作**：对多层 reply_to 链的 action 验证 author 回溯
- **前置依赖**：TC-004 Step 7（msg-001 → approve(msg-002) → 新任务 msg-003 → reject(msg-004) → revise(msg-005)）
- **验证**：author CBAC 沿 reply_to 链回溯到 subject action 的 author
- **验收标准**：
  - msg-005 (revise) 的 `ext.reply_to.ref_id` = `msg-003`
  - 回溯到 msg-003 的 `subject_author` = `@alice:local`
  - 不是检查 msg-005 的 author，而是检查 flow instance 的 subject_author
