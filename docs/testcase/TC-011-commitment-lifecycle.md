# TC-011: Commitment 生命周期

> **测试目标**：验证 Commitment 的完整生命周期——inactive → active → fulfilled / violated
> **前置依赖**：TC-004（已有基础运行时）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：001, 002, 003

---

## 场景：验证审批 Commitment（C1: 审批者需在规定时间内回复）

### Step 1: 初始状态验证

- **操作**：App 安装后读取 `state.json`
- **前置依赖**：TC-003 已完成
- **验证**：Commitment 初始为 inactive
- **验收标准**：
  - `commitments` 包含 `da:C1`
  - `commitments["da:C1"].status` = `inactive`
  - 无 `triggered_by` 和 `triggered_at` 字段（或为 null）

### Step 2: 触发 Commitment（submit → C1 激活）

- **操作**：@alice 执行 `da:submit`（提交任务）
- **前置依赖**：Step 1
- **验证**：Commitment 被触发激活
- **验收标准**：
  - `commitments["da:C1"].status` 从 `inactive` 变为 `active`
  - `commitments["da:C1"].triggered_by` = `msg-001`（submit 的 ref_id）
  - `commitments["da:C1"].triggered_at` 为有效 ISO 8601 时间戳
  - 触发条件与 §3 中定义的一致（如"当任务进入 submitted 状态时"）

### Step 3: 验证 Commitment 与 Flow 联动

- **操作**：检查 §3 中 C1 的定义与 §2 Flow 的关联
- **前置依赖**：Step 2
- **验证**：触发条件正确关联
- **验收标准**：
  - C1 的触发条件引用 §2 中的某个 Flow state（如 `submitted`）
  - 当 Flow 进入该状态时，C1 自动激活
  - C1 的当事方（如 R2 → R1）与 §1 角色一致

### Step 4: 履行 Commitment（approve → C1 fulfilled）

- **操作**：@bob 在截止时间前执行 `da:approve`
- **前置依赖**：Step 2
- **验证**：Commitment 被标记为已履行
- **验收标准**：
  - `commitments["da:C1"].status` 从 `active` 变为 `fulfilled`
  - Flow instance 状态变为 `approved`
  - `/commitments` 命令显示 C1 = fulfilled

### Step 5: 验证 fulfilled 是终态

- **操作**：尝试再次触发已 fulfilled 的 C1
- **前置依赖**：Step 4
- **验证**：fulfilled 后 C1 不再可操作
- **验收标准**：
  - 新的 submit（msg-003）应触发**新的** C1 实例或**同一** C1 回到 active
  - 具体行为取决于 Commitment 定义：
    - 如果 C1 是 per-instance：每个 flow instance 有独立的 C1 状态
    - 如果 C1 是 global：状态在整个 namespace 共享

### Step 6: 违反 Commitment（超时未响应）

- **操作**：@alice 提交新任务，@bob 在模拟超时后仍未审批
- **前置依赖**：Step 1
- **验证**：Commitment 被标记为已违反
- **验收标准**：
  - 模拟时间推进超过截止时间（如 48h）
  - `commitments["da:C1"].status` 变为 `violated`
  - `/commitments` 命令显示 C1 = violated
  - 系统记录违反事件

### Step 7: reject 也满足 Commitment

- **操作**：@alice 提交任务，@bob 在截止前 reject（驳回也是一种回复）
- **前置依赖**：Step 1
- **验证**：reject 同样算作 Commitment 履行
- **验收标准**：
  - C1 要求"审批者在 N 时间内回复"
  - reject 是一种回复 → C1 status = `fulfilled`
  - 不因为结果是 reject 就标记为 violated

### Step 8: 多 Commitment 验证（如有）

- **操作**：如果模板定义了多个 Commitment（C1, C2），验证它们独立运行
- **前置依赖**：模板包含多个 Commitment
- **验证**：各 Commitment 独立追踪
- **验收标准**：
  - C1 和 C2 的 status 独立变化
  - C1 fulfilled 不影响 C2 的状态
  - 各自的触发条件和截止时间独立计算

### Step 9: 通过 /rebuild 验证 Commitment 可重建

- **操作**：删除 state.json 后执行 /rebuild
- **前置依赖**：Step 4 或 Step 6
- **验证**：Commitment 状态从 Timeline 正确重建
- **验收标准**：
  - 重建后 `commitments["da:C1"]` 与原始一致
  - 触发时间和触发者信息正确恢复
  - fulfilled/violated 状态正确推导
