---
name: room
description: "Create, list, and manage Rooms — collaboration spaces that host Socialware Apps. Use before /socialware-app-install to install an App."
---

# Room — 协作空间管理

## 启动前置

## 你在管理什么

**Room 是协作空间**——一个可以安装多个 Socialware 的持久化环境。

Room ≠ App。Room 是空间，App 是空间中可运行的指令集。一个 Room 可以安装多个 Socialware，每个提供不同 namespace 的指令。

## 命令

### `/room create {name}`

创建新 Room:

1. 检查 `simulation/workspace/rooms/{name}/` 是否已存在
2. 创建目录结构:
   ```
   simulation/workspace/rooms/{name}/
   ├── identities/    # Room 成员
   ├── socialware-app/ # 已安装的 .app.md
   ├── config.json    # Room 配置
   ├── timeline/
   │   └── shard-001.jsonl
   ├── content/
   ├── artifacts/
   └── state.json     # 初始状态
   ```
3. 询问 Room 创建者身份，提示格式为 `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`）
4. 生成初始 config.json:
   ```json
   {
     "room_id": "room-{name}-001",
     "name": "{Name}",
     "created_by": "{username}:{nickname}@{namespace}",
     "created_at": "{ISO8601}",
     "membership": {
       "policy": "invite",
       "members": {
         "{username}:{nickname}@{namespace}": "owner"
       }
     },
     "socialware-app": {
       "installed": [],
       "roles": {}
     }
   }
   ```
5. 生成空 state.json（注意：为 owner 初始化 `peer_cursors`）:
   ```json
   {
     "flow_states": {},
     "role_map": {},
     "commitments": {},
     "last_clock": 0,
     "peer_cursors": {
       "{username}:{nickname}@{namespace}": 0
     }
   }
   ```
6. 如果创建者的 identity 文件不存在，创建 `simulation/workspace/identities/{username}@{namespace}.json`：
   ```json
   {
     "entity_id": "{username}:{nickname}@{namespace}",
     "pubkey_sim": "sim:placeholder",
     "created_at": "{ISO8601}"
   }
   ```
7. 在 `simulation/workspace/rooms/{name}/identities/` 创建成员引用 `{username}@{namespace}.json`（与全局 identity 相同内容）

### `/room list`

列出所有 Room:

1. 扫描 `simulation/workspace/rooms/` 下所有目录
2. 读取每个 Room 的 config.json
3. 展示表格:
   ```
   | Room | 成员 | 已安装 Socialware | 消息数 | 最后活动 |
   |------|------|-------------------|--------|---------|
   | project-alpha | alice, bob | ew, ta, rp | 42 | 2026-03-09 |
   ```

### `/room show {name}`

展示 Room 详情:

1. 读取 config.json
2. 读取 state.json（概要）
3. 列出已安装的 Socialware（app-id + namespace + 契约文件）
4. 列出成员和角色
5. 展示 Timeline 统计（消息数, 最后 clock）

### `/room join {name} {username}:{nickname}@{namespace}`

将成员加入 Room:

1. 检查 Room 是否存在
2. 检查 `simulation/workspace/identities/{username}@{namespace}.json` 是否存在，不存在则创建（格式同 create 步骤 6）
3. 将 identity 添加到 config.json 的 `membership.members`：`"{username}:{nickname}@{namespace}": "member"`
4. 在 `simulation/workspace/rooms/{name}/identities/` 创建成员引用 `{username}@{namespace}.json`（与全局 identity 相同内容）
5. 在 state.json 的 `peer_cursors` 中初始化：`"{username}:{nickname}@{namespace}": 0`

### `/room clean-sessions`

清理残留的 session 文件（用户未执行 `/quit` 直接关闭终端时产生）:

1. 扫描 `simulation/workspace/rooms/*/.session.*.json`
2. 列出所有找到的 session 文件，显示 room、identity、started_at
3. 询问用户确认删除（全部删除 or 选择性删除）
4. 删除选中的 session 文件
5. 展示结果

```
发现 2 个残留 session:
  1. rooms/doc-review/.session.alice.json  (alice:Alice@local, 启动于 2026-03-11T10:00:00Z)
  2. rooms/project-alpha/.session.bob.json (bob:Bob@local, 启动于 2026-03-11T11:00:00Z)

删除全部？(y/n/选择编号)
```

## 参考

- 初始化脚本: @init-workspace.sh

## 完成提示

Room 创建/加入完成后，根据当前状态提示用户下一步：

- **如果 `simulation/socialware/` 中无模板** → 提示：
  > Room 已就绪。下一步用 `/socialware-dev` 设计一个 Socialware 模板。
- **如果有模板但 `simulation/app-store/` 中无 App** → 提示：
  > Room 已就绪。下一步用 `/socialware-app-dev` 基于模板开发 App。
- **如果 app-store 中有已开发的 App** → 提示：
  > Room 已就绪。下一步用 `/socialware-app-install` 将已开发的 App 安装到此 Room 中。

**完整流程参考**: `/room` → `/socialware-dev` → `/socialware-app-dev` → `/socialware-app-install` → `/socialware-app`

## 关键原则

- **Room 先于 Socialware**: 先有空间，再安装 App
- **Room 可以为空**: 没有安装任何 Socialware 的 Room 就是一个空协作空间
- **一个 Room 多个 Socialware**: 通过 namespace 区分
- **成员管理**: Room 有自己的成员列表，Socialware 的 Role 是在成员之上的应用层权限
- **身份格式**: `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`），无 `@` 前缀
