# TC-005: Hook Pipeline 验证

> **测试目标**：验证消息处理三阶段 Pipeline——pre_send 三项检查 + execute + after_write
> **前置依赖**：TC-004（已有基础运行时）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：001, 004

---

## 场景：逐步验证 Hook Pipeline 的每个阶段

### Step 1: Role Check — 通过

- **操作**：alice（持有 R1/提交者）执行 `da:submit`
- **前置依赖**：TC-004 Step 1（App 已启动）
- **验证**：Role Check 通过
- **验收标准**：
  - alice 在 `role_map` 中有 `da:R1`（`role_map["da:R1"]` = `"alice:Alice@local"`）
  - `da:submit` 要求 R1（提交者）
  - 匹配成功，检查通过

### Step 2: Role Check — 拒绝

- **操作**：bob（仅持有 R2/审批者）尝试执行 `da:submit`
- **前置依赖**：Step 1
- **验证**：Role Check 拒绝
- **验收标准**：
  - bob 在 `role_map` 中仅有 `da:R2`（`role_map["da:R2"]` = `"bob:Bob@local"`）
  - `da:submit` 要求 R1
  - bob 不持有 R1，操作被拒绝
  - Timeline 中**不**新增任何 entry
  - 显示明确的错误信息，包含角色不匹配原因

### Step 3: CBAC Check — `any` 类型

- **操作**：alice 执行 `da:submit`（CBAC=any）
- **前置依赖**：Step 1
- **验证**：任何持有 required_role 的人都可执行
- **验收标准**：
  - Flow 表中 submit 的 CBAC 为 `any`
  - alice 持有 R1 → CBAC 检查通过
  - 如果另一个 R1 持有者存在，同样可以 submit

### Step 4: CBAC Check — `author` 类型

- **操作**：alice 提交任务（msg-A），bob 驳回（msg-B），alice 执行 revise（CBAC=author）
- **前置依赖**：Step 3
- **验证**：只有 flow instance 的 subject_author 才能 revise
- **验收标准**：
  - revise 的 CBAC 为 `author`
  - alice 是 msg-A 的 subject_author → 可以 revise
  - 如果 bob 尝试 revise msg-A → CBAC 拒绝（bob 不是 author）
  - 错误信息明确说明"仅原始提交者可执行此操作"

### Step 5: Flow Check — 合法转换

- **操作**：在 `_none_` 状态执行 `submit`（→ submitted）
- **前置依赖**：Step 1
- **验证**：状态转换合法
- **验收标准**：
  - 当前状态 `_none_` + action `submit` → 在 §2 Flow 表中找到匹配行
  - Next State 为 `submitted`
  - Flow Check 通过

### Step 6: Flow Check — 非法转换

- **操作**：在 `submitted` 状态尝试执行 `submit`（不在 Flow 表中）
- **前置依赖**：Step 5
- **验证**：非法状态转换被拒绝
- **验收标准**：
  - 当前状态 `submitted` + action `submit` → Flow 表中无匹配行
  - Flow Check 拒绝
  - Timeline 中**不**新增 entry
  - 错误信息包含当前状态和尝试的 action

### Step 7: Execute Phase — manual 工具

- **操作**：执行一个绑定为 `manual` 的 action
- **前置依赖**：pre_send 全部通过
- **验证**：manual 工具正确执行
- **验收标准**：
  - 提示用户输入内容
  - 用户输入被捕获为 Content Object
  - Content Object 写入 `content/sha256_{hash}.json`
  - Content Object 的 `body` 包含用户输入

### Step 8: Execute Phase — bash 工具（如有）

- **操作**：如果 App 中有 bash 绑定的 action，执行它
- **前置依赖**：pre_send 全部通过
- **验证**：bash 命令正确执行
- **验收标准**：
  - Shell 命令被执行
  - stdout/stderr 被捕获
  - 输出写入 Content Object
  - 执行失败时（exit code ≠ 0）有错误处理

### Step 9: After_write Phase — Timeline 追加

- **操作**：观察 pre_send + execute 通过后的 after_write 阶段
- **前置依赖**：Step 7
- **验证**：Ref 正确追加到 Timeline
- **验收标准**：
  - `timeline/shard-001.jsonl` 新增一行
  - 新行包含完整的 Ref 字段：ref_id, author, content_type, content_id, created_at, status, clock, signature, ext
  - `content_id` 指向刚写入的 Content Object
  - `clock` = `last_clock + 1`

### Step 10: After_write Phase — State 更新

- **操作**：观察 after_write 中的 State 更新
- **前置依赖**：Step 9
- **验证**：state.json 正确更新
- **验收标准**：
  - `flow_states` 中对应 flow instance 的 `state` 已更新
  - `last_clock` 已递增
  - `peer_cursors` 中当前 Identity 的 cursor 已更新
  - Commitment 状态按需更新（如 submit 触发 C1 激活）

### Step 11: After_write Phase — 广播通知

- **操作**：观察 after_write 中的广播行为
- **前置依赖**：Step 9
- **验证**：其他 peer 可发现新消息
- **验收标准**：
  - 切换到 bob（`/switch bob:Bob@local`）后显示收件箱
  - 收件箱包含刚才 alice 的操作
  - 收件箱消息包含 clock 值和操作摘要

### Step 12: Pipeline 中断 — pre_send 失败不写入

- **操作**：触发 pre_send 任一检查失败
- **前置依赖**：Step 1
- **验证**：Pipeline 在 pre_send 阶段中断，不进入 execute 和 after_write
- **验收标准**：
  - Timeline 行数未变
  - state.json 未修改
  - Content 目录未新增文件
  - last_clock 未变
