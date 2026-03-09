---
name: room
description: "Create, list, and manage Rooms — collaboration spaces that host Socialware Apps. Use before /socialware-app-dev to choose or create a target Room."
---

# Room — 协作空间管理

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
   ├── contracts/     # 已安装的 .app.md
   ├── config.json    # Room 配置
   ├── timeline/
   │   └── shard-001.jsonl
   ├── content/
   ├── artifacts/
   └── state.json     # 初始状态
   ```
3. 询问 Room 创建者身份（@entity:local）
4. 生成初始 config.json:
   ```json
   {
     "room_id": "room-{name}-001",
     "name": "{Name}",
     "created_by": "@{entity}:local",
     "created_at": "{ISO8601}",
     "membership": {
       "policy": "invite",
       "members": {
         "@{entity}:local": "owner"
       }
     },
     "socialware": {
       "installed": [],
       "roles": {}
     }
   }
   ```
5. 生成空 state.json:
   ```json
   {
     "flow_states": {},
     "role_map": {},
     "commitments": {},
     "last_clock": 0,
     "peer_cursors": {}
   }
   ```
6. 如果创建者的 identity 文件不存在，创建 `simulation/workspace/identities/@{entity}.json`

### `/room list`

列出所有 Room:

1. 扫描 `simulation/workspace/rooms/` 下所有目录
2. 读取每个 Room 的 config.json
3. 展示表格:
   ```
   | Room | 成员 | 已安装 Socialware | 消息数 | 最后活动 |
   |------|------|-------------------|--------|---------|
   | project-alpha | @alice, @bob | ew, ta, rp | 42 | 2026-03-09 |
   ```

### `/room show {name}`

展示 Room 详情:

1. 读取 config.json
2. 读取 state.json（概要）
3. 列出已安装的 Socialware（namespace + 契约文件）
4. 列出成员和角色
5. 展示 Timeline 统计（消息数, 最后 clock）

### `/room join {name} @{entity}`

将成员加入 Room:

1. 检查 Room 是否存在
2. 检查 identity 文件是否存在，不存在则创建
3. 将 identity 添加到 config.json 的 membership.members
4. 在 `simulation/workspace/rooms/{name}/identities/` 创建成员引用
5. 初始化 peer_cursors

## 关键原则

- **Room 先于 Socialware**: 先有空间，再安装 App
- **Room 可以为空**: 没有安装任何 Socialware 的 Room 就是一个空协作空间
- **一个 Room 多个 Socialware**: 通过 namespace 区分
- **成员管理**: Room 有自己的成员列表，Socialware 的 Role 是在成员之上的应用层权限
