# TC-008: 多会话 P2P

> **测试目标**：验证 tmux 多 pane 模式——独立 session + watch-timeline + 并发写入安全
> **前置依赖**：TC-004（已有基础运行时）
> **测试 Skill**：`/socialware-app`
> **辅助脚本**：`.claude/skills/socialware-app/scripts/start-p2p.sh` + `.claude/skills/socialware-app/scripts/watch-timeline.sh`
> **覆盖 Spec**：006

---

## 场景：Alice 和 Bob 在独立终端中同时运行

### Step 1: 启动 tmux P2P 环境

- **操作**：在 SwSim 项目根目录执行：
  ```bash
  .claude/skills/socialware-app/scripts/start-p2p.sh doc-review alice:Alice@local bob:Bob@local
  ```
  如果 session 已存在，使用 `--force` 重建：
  ```bash
  .claude/skills/socialware-app/scripts/start-p2p.sh --force doc-review alice:Alice@local bob:Bob@local
  ```
- **前置依赖**：TC-003 已完成（App 已安装到 Room）
- **验证**：tmux session 创建，4 个 pane（2 peer + 2 watcher）
- **验收标准**：
  - tmux session 名称为 `swsim-doc-review`
  - 4 个 pane：2 个 peer pane + 2 个 watcher pane（每个 identity 占 2 个 pane）
  - 左上 pane：alice 的 Claude Code 会话，自动执行 `/socialware-app room=doc-review identity=alice:Alice@local`
  - 右上 pane：bob 的 Claude Code 会话，自动执行 `/socialware-app room=doc-review identity=bob:Bob@local`
  - 左下 pane：alice 的 watcher（`watch-timeline.sh`，过滤自己消息）
  - 右下 pane：bob 的 watcher
  - 用 `Ctrl-b + 方向键` 切换 pane
  - 不加 `--force` 再次运行会 attach 到已有 session（不重建）

### Step 2: 验证两个 session 独立

- **操作**：分别在两个 pane 中执行 `/roles`
- **前置依赖**：Step 1
- **验证**：各 session 身份独立
- **验收标准**：
  - Alice pane：显示 alice:Alice@local 的角色（如 da:R1/提交者）
  - Bob pane：显示 bob:Bob@local 的角色（如 da:R2/审批者）
  - 两个 session 读取的是同一个 Room 的 config.json

### Step 3: Alice 提交任务

- **操作**：切到 Alice pane（Ctrl-b + ←），提交任务"多人协作测试"
- **前置依赖**：Step 1
- **验证**：消息写入共享 Timeline
- **验收标准**：
  - Timeline `shard-001.jsonl` 新增 entry
  - clock = 1
  - Content Object 写入 `content/`

### Step 4: Bob 发现新消息

- **操作**：切到 Bob pane（Ctrl-b + →），执行 `/inbox`
- **前置依赖**：Step 3
- **验证**：Bob 能读取到 Alice 写入的消息
- **验收标准**：
  - Bob 读取 Timeline 中 clock > `peer_cursors["bob:Bob@local"]` 的 entries
  - 显示 Alice 的提交消息
  - Bob 的 peer_cursor 更新

### Step 5: watch-timeline 实时监控（可选）

- **操作**：在另一个终端运行：
  ```bash
  .claude/skills/socialware-app/scripts/watch-timeline.sh doc-review
  ```
- **前置依赖**：Step 3
- **验证**：新消息实时显示
- **验收标准**：
  - `watch-timeline.sh` 监控 `timeline/shard-*.jsonl` 文件变化
  - Alice 写入后，实时显示新 entry
  - 格式化输出包含 clock、author、action 等关键信息

### Step 6: Bob 审批

- **操作**：在 Bob pane 中审批 Alice 的任务
- **前置依赖**：Step 4
- **验证**：跨 session 的状态转换
- **验收标准**：
  - Timeline 新增 msg-002，clock = 2
  - `ext.reply_to.ref_id` = `msg-001`
  - `flow_states["msg-001"].state` = `approved`
  - 两个 session 的 `state.json` 视图一致（因为是同一文件）

### Step 7: Alice 看到结果

- **操作**：切回 Alice pane，执行 `/inbox`
- **前置依赖**：Step 6
- **验证**：Alice 收到审批通知
- **验收标准**：
  - 收件箱显示 Bob 的审批消息
  - `/status` 显示 msg-001 = approved
  - `peer_cursors["alice:Alice@local"]` 更新

### Step 8: 并发写入安全

- **操作**：Alice 和 Bob 几乎同时提交新任务（在各自 pane 中快速操作）
- **前置依赖**：Step 2
- **验证**：共享文件不损坏
- **验收标准**：
  - 两条消息都成功写入 Timeline（不丢失）
  - Timeline 中每行各自完整（不交错）
  - clock 值不冲突（Lamport clock 保证唯一递增）
  - `state.json` 更新无损坏（JSON 有效）

### Step 9: Lamport Clock 因果排序

- **操作**：验证并发写入后的 clock 值
- **前置依赖**：Step 8
- **验证**：Lamport clock 正确维护
- **验收标准**：
  - 每个 peer 写入前：`local_clock = max(local_clock, last_seen_clock) + 1`
  - Timeline 中同一 peer 的 clock 严格递增
  - 不同 peer 的 clock 可能相同（并发），此时用 peer_id 字典序打破平局
  - 因果关系保持：如果 msg B 是对 msg A 的 reply，则 B.clock > A.clock

### Step 10: 断开重连

- **操作**：关闭 Bob 的 pane（Ctrl-b 然后输入 `:kill-pane`），Alice 继续操作，然后新开终端重新启动 Bob
- **前置依赖**：Step 7
- **验证**：Bob 重连后能追上进度
- **验收标准**：
  - Bob 关闭期间 Alice 的操作正常写入
  - Bob 重新启动 `/socialware-app` 后
  - 收件箱显示所有 Bob 离线期间的消息
  - `peer_cursors["bob:Bob@local"]` 仍是断开前的值
  - Bob 操作后 cursor 正确更新

### Step 11: 清理

- **操作**：退出 tmux session
  ```bash
  tmux kill-session -t swsim-doc-review
  ```
- **前置依赖**：测试完成
- **验证**：环境清理
- **验收标准**：
  - tmux session 已关闭
  - Room 目录文件保留（timeline、state 等）
