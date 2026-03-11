# TC-012: 热重启

> **测试目标**：验证关闭 session → 重新启动 → 状态完整恢复
> **前置依赖**：TC-004（已有运行记录）
> **测试 Skill**：`/socialware-app`
> **覆盖 Spec**：005

---

## 场景：模拟 session 中断后恢复运行

### Step 1: 运行一段操作产生状态

- **操作**：alice submit(msg-001) → bob approve(msg-002) → alice submit(msg-003)
- **前置依赖**：TC-003 已完成
- **验证**：State 有内容
- **验收标准**：
  - Timeline 有 3 行
  - `flow_states` 有 2 个 instances（msg-001:approved, msg-003:submitted）
  - `last_clock` = 3
  - `peer_cursors` 有 alice 和 bob 的值

### Step 2: 记录关闭前状态快照

- **操作**：读取并记录 state.json 和 timeline 的完整内容
- **前置依赖**：Step 1
- **验证**：快照已保存
- **验收标准**：
  - 记录 `flow_states` 的所有 key 和 value
  - 记录 `last_clock` 值
  - 记录 `peer_cursors` 的所有 key 和 value
  - 记录 Timeline 行数

### Step 3: 关闭 Session

- **操作**：关闭 Claude Code session（Ctrl+C 或关闭终端）
- **前置依赖**：Step 2
- **验证**：Session 已退出
- **验收标准**：
  - Claude Code 进程已终止
  - 文件系统上的所有文件保持不变

### Step 4: 验证文件持久化

- **操作**：检查关闭后的文件系统
- **前置依赖**：Step 3
- **验证**：所有文件完好
- **验收标准**：
  - `state.json` 存在且 JSON 有效
  - `timeline/shard-001.jsonl` 存在且行数不变
  - `config.json` 存在且未修改
  - `contracts/doc-audit.alice.two-role-submit-approve.app.md` 存在
  - `content/` 下的 Content Object 文件都在

### Step 5: 重新启动 Session

- **操作**：打开新的 Claude Code session，执行 `/socialware-app`，Room=doc-review，Identity=alice:Alice@local
- **前置依赖**：Step 4
- **验证**：启动面板显示正确的恢复状态
- **验收标准**：
  - 启动面板显示 `last_clock` = 3
  - 显示活跃 Flow Instances：msg-003 [da:task_lifecycle] — submitted
  - 显示已完成 Flow：msg-001 — approved
  - alice 的角色和可用操作正确显示
  - 可立即继续操作

### Step 6: 恢复后继续操作

- **操作**：bob 对 msg-003 执行 approve
- **前置依赖**：Step 5
- **验证**：操作从断点无缝继续
- **验收标准**：
  - clock = 4（紧接 last_clock=3 之后）
  - `flow_states["msg-003"].state` = `approved`
  - Timeline 新增第 4 行
  - 所有 Hook Pipeline 检查正常通过

### Step 7: 收件箱跨重启

- **操作**：重启后切换到 bob（`/switch bob:Bob@local`）
- **前置依赖**：Step 5
- **验证**：收件箱正确显示跨重启的未读消息
- **验收标准**：
  - `peer_cursors["bob:Bob@local"]` 保持重启前的值
  - 收件箱显示 bob 上次操作以来的所有新消息
  - 不因重启而丢失 cursor 位置

### Step 8: 修改契约后热重启

- **操作**：关闭 session → 编辑 `contracts/doc-audit.alice.two-role-submit-approve.app.md`（如修改某个 Tool 绑定）→ 重启
- **前置依赖**：Step 1
- **验证**：新契约生效
- **验收标准**：
  - 重启后读取的是修改后的 `doc-audit.alice.two-role-submit-approve.app.md`
  - 新的 Tool 绑定在后续操作中生效
  - 已有 Timeline entries 不受影响（它们已固化）
  - 新操作使用新绑定

### Step 9: 修改 Flow 后的兼容性

- **操作**：关闭 session → 在 doc-audit.alice.two-role-submit-approve.app.md 中增加一个新状态（如 `needs_info`）→ 重启
- **前置依赖**：Step 1
- **验证**：向后兼容的修改可以正常工作
- **验收标准**：
  - 新增状态不影响已有 flow instances
  - 已有 flow instances 的状态仍然有效
  - 新的 action（如 `request_info`）可在新操作中使用
  - 如果 Flow 修改不兼容（删除已有状态），应有警告
