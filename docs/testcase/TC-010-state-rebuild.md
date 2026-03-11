# TC-010: State 重建

> **测试目标**：验证 `/rebuild` 命令从 Timeline 重建 state.json——证明 CRDT 属性
> **前置依赖**：TC-004（已有运行记录的 Timeline）
> **测试 Skill**：`/socialware-app`（`/rebuild` 命令）
> **覆盖 Spec**：001, 005

---

## 场景：删除 state.json 后从 Timeline 完整重建

### Step 1: 执行若干操作产生丰富 Timeline

- **操作**：alice submit(msg-001) → bob approve(msg-002) → alice submit(msg-003) → bob reject(msg-004) → alice revise(msg-005) → bob approve(msg-006)
- **前置依赖**：TC-003 已完成
- **验证**：Timeline 包含 6 条记录
- **验收标准**：
  - Timeline 有 6 行
  - clock 从 1 到 6
  - 2 个 flow instances：msg-001（approved）, msg-003（approved）
  - `last_clock` = 6

### Step 2: 备份当前 state.json

- **操作**：复制 `state.json` 为 `state.json.bak`
- **前置依赖**：Step 1
- **验证**：备份文件存在
- **验收标准**：
  - `state.json.bak` 的内容与 `state.json` 完全相同
  - 备份包含完整的 flow_states, role_map, commitments, last_clock, peer_cursors

### Step 3: 删除 state.json 并重建

- **操作**：删除 `state.json`，执行 `/rebuild`
- **前置依赖**：Step 2
- **验证**：重建成功完成
- **验收标准**：
  - `/rebuild` 报告处理了 6 条 Timeline entries
  - 新的 `state.json` 被创建
  - 新文件是有效 JSON

### Step 4: 对比重建结果

- **操作**：对比 `state.json` 和 `state.json.bak`
- **前置依赖**：Step 3
- **验证**：重建结果与原始 State 完全一致
- **验收标准**：
  - `flow_states` 完全相同（key、flow、state、subject_author、last_action、last_ref）
  - `role_map` 完全相同（来自 config.json，不是从 timeline 推导）
  - `commitments` 完全相同（status、triggered_by、triggered_at）
  - `last_clock` 完全相同
  - `peer_cursors` 完全相同

### Step 5: 验证 flow_states 重建细节

- **操作**：逐个检查重建的 flow_states
- **前置依赖**：Step 3
- **验证**：每个 flow instance 的状态正确
- **验收标准**：
  - msg-001: `flow`=`da:task_lifecycle`, `state`=`approved`, `subject_author`=`alice:Alice@local`
  - msg-003: `flow`=`da:task_lifecycle`, `state`=`approved`, `subject_author`=`alice:Alice@local`
  - 每个 instance 的 `last_action` 和 `last_ref` 指向最后执行的操作

### Step 6: 验证 Commitment 重建

- **操作**：检查重建的 commitments
- **前置依赖**：Step 3
- **验证**：Commitment 状态正确推导
- **验收标准**：
  - 如果 C1 在 submit 时触发（active），且在 approve 后 fulfilled → status=`fulfilled`
  - `triggered_by` 和 `triggered_at` 与原始一致
  - Commitment 状态转换链与 Timeline 事件序列一致

### Step 7: 重建后继续运行

- **操作**：重建完成后，alice 提交新任务
- **前置依赖**：Step 3
- **验证**：重建后的 state 可正常用于后续操作
- **验收标准**：
  - 新 submit 操作成功
  - clock = 7（紧接重建后的 last_clock+1）
  - 新 flow instance 正确创建
  - 重建后的 state.json 与运行时 state 无冲突

### Step 8: 部分 Timeline 重建（可选高级测试）

- **操作**：只保留 Timeline 前 3 行（msg-001 到 msg-003），重建 state
- **前置依赖**：Step 1
- **验证**：部分 Timeline 重建的结果正确
- **验收标准**：
  - msg-001 flow instance 状态 = `approved`（因为 msg-002 是 approve）
  - msg-003 flow instance 状态 = `submitted`（因为没有后续操作）
  - `last_clock` = 3
  - 与原始 state 在 clock=3 时刻的状态一致

### Step 9: CRDT 幂等性验证

- **操作**：连续执行 2 次 `/rebuild`
- **前置依赖**：Step 3
- **验证**：多次重建结果相同
- **验收标准**：
  - 第一次重建的 state.json 和第二次重建的 state.json 完全相同
  - 证明 `State = f(Timeline)` 是确定性函数
  - 无论重建多少次，结果不变

### Step 10: 使用 rebuild-state.py 脚本

- **操作**：直接运行 `python .claude/skills/socialware-app/scripts/rebuild-state.py simulation/workspace/rooms/doc-review`
- **前置依赖**：Step 1
- **验证**：脚本输出与 /rebuild 命令结果一致
- **验收标准**：
  - 脚本正确读取所有 `contracts/*.app.md`
  - 脚本正确解析 `timeline/*.jsonl`
  - 脚本按 clock 排序重放
  - 输出的 state.json 与 /rebuild 命令结果完全一致
