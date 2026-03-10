# 006 — P2P 多用户通信模拟

> **状态**：Draft v1
> **日期**：2026-03-09

---

## 1. 概述

SwSim 使用**共享文件系统**模拟 P2P 网络。每个 peer 是一个独立的 Claude Code 会话（运行在 tmux pane 或独立终端中），通过读写同一个 Room 目录实现"通信"。

本文档定义多用户通信的完整协议：启动、消息传递、通知、并发控制、会话管理。

---

## 2. 通信模型

### 2.1 核心等价

| P2P 概念 | 文件系统操作 |
|----------|-------------|
| 发送消息 | append 一行到 `timeline/shard-xxx.jsonl` |
| 接收消息 | 读取 timeline 中 clock > peer_cursor 的行 |
| 消息广播 | 写入共享文件（所有 peer 可读） |
| 在线通知 | `inotifywait` 监听 timeline 目录，或 2s 轮询 |
| 节点发现 | 读取 `config.json` 的 `membership.members` |
| 身份验证 | 读取 `workspace/identities/@{entity}.json` |

### 2.2 消息传递流程

```
Peer A (Alice)                           Peer B (Bob)
─────────────                            ──────────
1. 用户输入动作
2. pre_send 检查 ✓
3. 执行工具
4. 获取文件锁 (flock)                     （等待锁释放）
5. 追加 Ref → timeline/shard-001.jsonl
6. 更新 state.json
7. 释放文件锁
8. 打印消息到终端                     9. watch-timeline 检测到变化
                                     10. 打印通知: "[clock:N] @alice → ns:action"
                                     11. 用户执行 /inbox 查看详情
                                     12. 或直接执行后续动作
```

---

## 3. 启动方式

### 3.1 tmux 多 pane 启动（推荐）

使用 `start-p2p.sh` 一键启动：

```bash
# 启动 2 个 peer
.claude/skills/socialware-app/scripts/start-p2p.sh project-alpha @alice @bob

# 启动 3 个 peer
.claude/skills/socialware-app/scripts/start-p2p.sh project-alpha @alice @bob @charlie
```

效果：
```
┌─────────────────────┬─────────────────────┐
│ === Peer: @alice    │ === Peer: @bob      │
│ Room: project-alpha │ Room: project-alpha │
│                     │                     │
│ claude code session │ claude code session │
│ /socialware-app     │ /socialware-app     │
│ identity=@alice     │ identity=@bob       │
└─────────────────────┴─────────────────────┘
```

操作：
- `Ctrl-b + 方向键` 切换 pane
- `Ctrl-b + z` 放大/缩小当前 pane
- `tmux kill-session -t swsim-project-alpha` 关闭

### 3.2 手动多终端

```bash
# Terminal 1
cd /path/to/SwSim
claude
# 然后输入: /socialware-app, 选择 room=project-alpha, identity=@alice

# Terminal 2
cd /path/to/SwSim
claude
# 然后输入: /socialware-app, 选择 room=project-alpha, identity=@bob
```

### 3.3 Claude Code Subagent（自动化测试）

```
主 session:
  Agent A: /socialware-app room=project-alpha identity=@alice
  Agent B: /socialware-app room=project-alpha identity=@bob

  主 session 协调 A/B 的动作顺序
```

适用于自动化端到端测试——主 session 编排两个 subagent 的交互。

---

## 4. 消息通知机制

### 4.1 实时通知（inotifywait）

在独立 pane 或后台运行 `watch-timeline.sh`：

```bash
.claude/skills/socialware-app/scripts/watch-timeline.sh project-alpha @bob
```

输出：
```
══════════════════════════════════════
  Timeline Watcher
  Room: project-alpha
  监听身份: @bob
══════════════════════════════════════

14:23:05 [clock:3] @alice:local → ew:branch.create
14:23:18 [clock:4] @alice:local → ta:task.post
```

过滤自己发的消息，只显示其他 peer 的动作。

### 4.2 /inbox 命令

在 socialware-app runtime 中：

```
> /inbox

收件箱 (自 clock=2 以来的新消息):
──────────────────────────────────────
  [clock:3] 🌿 @alice:local 创建了分支: hotfix (ew:branch.create)
  [clock:4] 📋 @alice:local 提交了任务: 实现认证 (ta:task.post)
```

基于 `peer_cursors[当前identity]` 过滤。

### 4.3 启动时自动检查

每次 `/socialware-app` 启动或 peer 重新连接时：

```
══════════════════════════════════════════════════
  project-alpha — Socialware Runtime
══════════════════════════════════════════════════
  身份: @bob:local
  ...

  📬 3 条未读消息（自 clock=2 以来）:
    [clock:3] @alice:local → ew:branch.create
    [clock:4] @alice:local → ta:task.post
    [clock:5] @alice:local → ta:task.submit
──────────────────────────────────────────────────
```

---

## 5. 并发控制

### 5.1 问题

两个 peer 同时写入 timeline 和 state.json 可能导致：
- Timeline 行交错/截断
- state.json 互相覆盖

### 5.2 方案：文件锁（flock）

每次写入操作使用 `flock` 排他锁：

```bash
# 伪代码：写入 timeline
flock -x "${ROOM_DIR}/.write.lock" -c '
  echo "${REF_JSON}" >> timeline/shard-001.jsonl
  # 更新 state.json
  python3 -c "import json; ..."
'
```

锁文件：`workspace/rooms/{room}/.write.lock`

### 5.3 Lamport Clock 保证

即使并发写入，Lamport clock 保证因果序：

```
写入前:
  1. 读取 state.json → last_clock
  2. new_clock = last_clock + 1
  3. 获取 flock
  4. 再次读取 last_clock（可能已被其他 peer 更新）
  5. new_clock = max(new_clock, last_clock + 1)
  6. 写入 timeline + state.json
  7. 释放 flock
```

### 5.4 冲突恢复

如果 state.json 损坏：
```bash
# 从 timeline 重建 state（CRDT 保证）
python3 .claude/skills/socialware-app/scripts/rebuild-state.py simulation/workspace/rooms/{room}
```

Timeline 是 append-only 的，不会损坏（最坏情况是最后一行截断，可用 `jq` 检测）。

---

## 6. 会话生命周期

### 6.1 加入

```
Peer 启动
  → 读取 config.json，确认身份在成员列表中
  → 读取 state.json，获取 peer_cursors[self]
  → 计算未读消息（timeline 中 clock > cursor 的条目）
  → 显示未读收件箱
  → 更新 peer_cursors[self] = last_clock
  → 进入交互循环
```

### 6.2 交互

```
用户输入
  → 解析 namespace:action
  → pre_send（角色/CBAC/Flow 检查）
  → execute（工具执行）
  → flock 获取写锁
  → 写 Content Object → content/sha256_{hash}.json
  → 追加 Ref → timeline/shard-xxx.jsonl
  → 更新 state.json（flow_states + commitments + clock + cursor）
  → flock 释放写锁
  → 打印消息到当前终端
  → 其他 peer 的 watcher 检测到变化并通知
```

### 6.3 离开

```
/quit
  → 更新 peer_cursors[self] = last_clock（持久化"已读"位置）
  → 写入 state.json
  → 退出
```

下次启动时，从 `peer_cursors[self]` 恢复，显示期间错过的消息。

---

## 7. tmux Session 布局建议

### 2 人协作

```
┌─────────────────────┬─────────────────────┐
│ @alice (主操作)     │ @bob (主操作)       │
│ /socialware-app     │ /socialware-app     │
└─────────────────────┴─────────────────────┘
```

### 3 人 + 监控

```
┌─────────────┬─────────────┬─────────────┐
│ @alice      │ @bob        │ @charlie    │
│ socialware  │ socialware  │ socialware  │
│ -app        │ -app        │ -app        │
├─────────────┴─────────────┴─────────────┤
│ watch-timeline.sh (全局消息监控)         │
└─────────────────────────────────────────┘
```

### 开发调试

```
┌─────────────────────┬─────────────────────┐
│ @alice              │ @bob                │
│ /socialware-app     │ /socialware-app     │
├─────────────────────┼─────────────────────┤
│ tail -f timeline/   │ cat state.json|jq   │
│ shard-001.jsonl|jq  │                     │
└─────────────────────┴─────────────────────┘
```

---

## 8. 与真实 P2P 的映射

| SwSim 模拟 | 真实 ezagent P2P |
|-----------|-----------------|
| tmux pane | 独立设备上的 ezagent 节点 |
| 共享文件系统 | Zenoh pub/sub + multicast scouting |
| flock 文件锁 | CRDT 合并（YATA 算法，无锁） |
| inotifywait | Zenoh subscription callback |
| peer_cursors | Vector clock + 增量同步 |
| start-p2p.sh | Zenoh 网络自动发现（scouting） |
| watch-timeline.sh | Zenoh 实时消息订阅 |
| /inbox | 离线消息队列（Zenoh 持久化存储） |

### 模拟简化

- 真实 CRDT 无需锁（并发安全），模拟用 flock 代替
- 真实 Zenoh 自动发现 peer，模拟用 config.json 成员列表代替
- 真实系统用 vector clock，模拟用 Lamport clock（足够，因为 flock 序列化了写入）
