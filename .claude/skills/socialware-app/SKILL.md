---
name: socialware-app
description: "Run an installed Socialware contract — text-game runtime with persistent Timeline, Flow state machines, role checks, Commitment tracking, and P2P simulation."
---

# Socialware App — 契约运行时模拟

## 启动前置

1. 如果存在 `simulation/workspace/.active-session.json`，删除它（清除旧 session）。
2. **身份确认**: 扫描 `simulation/workspace/identities/*.json`，列出可用身份。
   - 如果无身份 → 提示用户先用 `/room create` 创建身份。
   - 如果有身份 → 让用户选择以哪个身份操作。
   - **该身份必须是目标 Room 的成员**（启动时验证 config.json membership）。
3. 创建 `simulation/workspace/.active-session.json`（启用 inbox hook）:
```json
{
  "room": "{room}",
  "identity": "{username}:{nickname}@{namespace}",
  "started_at": "{ISO8601}"
}
```

## 你在运行什么

**你在运行一个 Socialware App——一个由契约定义的组织**。

运行时体验：
- 以某个身份（alice:Alice@local）参与组织
- 通过自然语言触发动作
- Runtime 检查角色权限和 Flow 状态，执行绑定的工具
- 每个动作产生一条消息，追加到 Timeline（append-only JSONL）
- 所有状态从 Timeline 纯派生——删除 state.json 后可从消息重建
- 多会话模式: 每个 Claude Code 会话 = 一个 peer
- 单会话模式: `/switch` 切换身份

## 参考

- 数据格式: @../socialware-app-dev/reference/data-formats.md
- State 重建: @scripts/rebuild-state.py
- P2P 协议: `docs/spec/006-p2p-simulation.md`
- P2P 启动: @scripts/start-p2p.sh
- Timeline 监听: @scripts/watch-timeline.sh

## P2P 多用户启动

### 方式一：tmux 多 pane（推荐）

```bash
# 一键启动 2 个 peer（n 个 identity → 2n 个 pane: peer + watcher）
./scripts/start-p2p.sh project-alpha alice:Alice@local bob:Bob@local

# 如果 session 已存在，使用 --force 销毁并重建
./scripts/start-p2p.sh --force project-alpha alice:Alice@local bob:Bob@local
```

每个 identity 占 2 个 pane：上方 Claude Code 会话（peer），下方 watch-timeline.sh（watcher, 20% 高度）。
pane 之间通过共享文件系统通信：Alice 写入 timeline → Bob 的 watcher 检测到新消息。
不加 `--force` 再次运行会 attach 到已有 session。

### 方式二：手动多终端

分别在不同终端启动 `claude`，各自执行 `/socialware-app` 选择同一 Room 和不同身份。

### 方式三：单会话 /switch（Fallback）

如果不方便开多终端，在同一个会话中用 `/switch {username}:{nickname}@{namespace}` 切换身份。

## 启动

1. 询问用户: 进入哪个 Room？以哪个身份？（多会话模式下可从环境变量 `SWSIM_ROOM` 和 `SWSIM_IDENTITY` 读取）
2. 读取 `simulation/workspace/rooms/{room}/config.json`
3. 确认身份在 Room 成员列表中
4. 读取所有已安装的 `contracts/*.app.md`
5. 加载 state.json（不存在则从 timeline 重建）
6. **创建 `.active-session.json`**（启用 UserPromptSubmit hook 的 inbox 检查）
7. 打印启动面板:

```
══════════════════════════════════════════════════
  {Room Name} — Socialware Runtime
══════════════════════════════════════════════════
  Room: {room_id}
  身份: {username}:{nickname}@{namespace}
  角色: {ns1:role1}, {ns2:role2}, ...
  可用动作: {ns1:action1}, {ns2:action2}, ...
  已安装: {ns1} ({name1}), {ns2} ({name2}), ...
  Timeline: {n} 条消息, clock={c}
──────────────────────────────────────────────────
```

## 动作执行（Hook Pipeline）

```
用户输入 → 解析为 {namespace}:{action}
  │
  [pre_send]
  ├─ 角色检查: config.json → socialware.roles
  ├─ 能力约束(CBAC): any → 通过; author → 沿 reply_to 链回溯, 比对 author
  ├─ Flow 检查: state.json → flow_states
  ├─ 跨 namespace: 同 state.json 内不同 namespace 的 flow_states
  │
  [execute] — 按 §5 绑定的工具类型执行
  ├─ manual:  提示用户输入内容，等待用户打字
  ├─ bash:    执行 Shell 命令，捕获 stdout/stderr
  ├─ mcp:     调用 MCP Server 工具，捕获返回值
  ├─ api:     发送 HTTP 请求，捕获 response body
  ├─ llm:     用 prompt template 填入变量，Claude 自主生成内容（无需用户输入）
  ├─ 工具输出 → 生成 Content Object → content/sha256_{hash}.json
  │
  [after_write]
  ├─ 追加 Ref → timeline/{shard}.jsonl
  ├─ 更新 state.json（flow_states, commitments, clock, cursor）
  └─ 广播消息（终端打印）
```

## 特殊命令

| 命令 | 说明 |
|------|------|
| `/help` | 可用动作和当前状态 |
| `/status` | 所有 Flow 实例状态 |
| `/roles` | 角色分配表 |
| `/commitments` | Commitment 状态 |
| `/inbox` | 未读消息（clock > peer_cursor 的条目） |
| `/switch {username}:{nickname}@{namespace}` | 单会话模式: P2P 身份切换 |
| `/history` | 消息历史 |
| `/timeline` | 原始 timeline JSONL |
| `/rebuild` | 从 timeline 重建 state.json |
| `/quit` | 退出（持久化 peer_cursor，删除 .active-session.json） |

## /switch — 单会话 P2P 模拟（Fallback）

1. 读 `peer_cursors[target]` = 上次见过的 clock
2. Filter timeline: clock > cursor → inbox
3. 打印收件箱
4. 更新 cursor，切换 author
5. 更新 `.active-session.json` 中的 identity

> 多会话模式下不需要 /switch。每个 Claude Code 会话以不同身份启动即可。

## /quit — 退出

1. 持久化当前 peer_cursor 到 state.json
2. **删除 `simulation/workspace/.active-session.json`**（停用 inbox hook）
3. 打印退出信息

## /rebuild — CRDT 验证

运行 `scripts/rebuild-state.py <room_dir>`，删除 state.json 并从 timeline 纯派生重建。

## 跨 namespace

- 同 Room 内: 读同一个 state.json 的不同 namespace 前缀
- 跨 Room: 读 `workspace/rooms/{ref}/state.json`（未来支持）
- 不存在 → 警告但不阻塞

## 并发写入

多会话模式下，两个 peer 可能同时写入。写入时必须：

1. 读取 state.json → 获取 last_clock
2. new_clock = last_clock + 1
3. 写入 timeline + 更新 state.json
4. 更新自己的 peer_cursor

Claude Code 会话是用户驱动的（同步），实际并发概率极低。
如果 state.json 意外损坏 → `/rebuild` 从 timeline 重建。

## 完成提示

运行结束后（用户执行 `/quit`），提示：

> Session 已结束。如需重新进入，执行 `/socialware-app` 选择 Room 和身份即可。

**完整流程参考**: `/room` → `/socialware-dev` → `/socialware-app-dev` → `/socialware-app-install` → `/socialware-app`

## 关键原则

- **Timeline 是 truth**: state.json 可删除重建
- **append-only**: timeline 只追加
- **Lamport clock**: 每条新消息 clock = max(已见) + 1
- **模拟不是假装**: bash 真执行，只有 P2P 是模拟的
- **多会话优先**: 每个 peer 一个 Claude Code 会话，共享文件系统
- **消息通知**: watch-timeline.sh 实时监听，/inbox 主动查询
- **session 生命周期**: 启动创建 `.active-session.json`，退出删除
- **身份格式**: `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`），无 `@` 前缀
