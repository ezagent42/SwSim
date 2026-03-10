# TC-002: Room 管理

> **测试目标**：验证 `/room` 的 create / list / show / join 四个命令
> **前置依赖**：无
> **测试 Skill**：`/room`
> **覆盖 Spec**：005 (Section 2)

---

## 场景：创建 Room 并管理成员

### Step 1: 创建 Room

- **操作**：执行 `/room create doc-review`，创建者为 `@alice:local`
- **前置依赖**：无
- **验证**：`simulation/workspace/rooms/doc-review/` 目录结构
- **验收标准**：
  - 目录存在：`identities/`, `contracts/`, `timeline/`, `content/`, `artifacts/`
  - `timeline/shard-001.jsonl` 存在且为空文件
  - `config.json` 存在且 JSON 有效
  - `state.json` 存在且 JSON 有效

### Step 2: 验证 config.json 初始结构

- **操作**：读取 `simulation/workspace/rooms/doc-review/config.json`
- **前置依赖**：Step 1
- **验证**：字段完整性和格式
- **验收标准**：
  - `room_id` 格式为 `room-doc-review-{seq}`
  - `name` 为 `doc-review`
  - `created_by` 为 `@alice:local`
  - `created_at` 为有效 ISO 8601
  - `membership.policy` 为 `invite`
  - `membership.members` 包含 `"@alice:local": "owner"`
  - `socialware.installed` 为空数组 `[]`
  - `socialware.roles` 为空对象 `{}`

### Step 3: 验证 state.json 初始结构

- **操作**：读取 `simulation/workspace/rooms/doc-review/state.json`
- **前置依赖**：Step 1
- **验证**：字段完整性
- **验收标准**：
  - `flow_states` 为空对象 `{}`
  - `role_map` 为空对象 `{}`
  - `commitments` 为空对象 `{}`
  - `last_clock` 为 `0`
  - `peer_cursors` 为空对象 `{}`

### Step 4: 验证 Identity 文件

- **操作**：检查 `simulation/workspace/identities/@alice.json`
- **前置依赖**：Step 1
- **验证**：Identity 文件存在且格式正确
- **验收标准**：
  - `entity_id` 为 `@alice:local`
  - `pubkey_sim` 存在
  - `created_at` 为有效 ISO 8601

### Step 5: Room 列表

- **操作**：执行 `/room list`
- **前置依赖**：Step 1
- **验证**：输出包含刚创建的 Room
- **验收标准**：
  - 列表中包含 `doc-review`
  - 显示成员数 = 1
  - 显示已安装 Socialware = 0
  - 显示消息数 = 0

### Step 6: Room 详情

- **操作**：执行 `/room show doc-review`
- **前置依赖**：Step 1
- **验证**：详情展示完整
- **验收标准**：
  - 显示 Room 名称和创建时间
  - 显示成员列表（仅 @alice:local）
  - 显示已安装 Socialware = 空
  - 显示 Lamport Clock = 0

### Step 7: 加入 Room

- **操作**：执行 `/room join doc-review @bob:local`（@bob:local 加入）
- **前置依赖**：Step 1
- **验证**：成员正确添加
- **验收标准**：
  - `config.json` 的 `membership.members` 新增 `"@bob:local": "member"`
  - `simulation/workspace/identities/@bob.json` 存在
  - `rooms/doc-review/identities/` 下有 @bob 的引用
  - `state.json` 的 `peer_cursors` 新增 `"@bob:local": 0`

### Step 8: 重复创建检测

- **操作**：再次执行 `/room create doc-review`
- **前置依赖**：Step 1
- **验证**：报错提示 Room 已存在
- **验收标准**：不覆盖已有 Room，提示错误

### Step 9: 创建第二个 Room

- **操作**：执行 `/room create project-alpha`，创建者 `@alice:local`
- **前置依赖**：Step 1
- **验证**：第二个 Room 独立创建
- **验收标准**：
  - `simulation/workspace/rooms/project-alpha/` 完整存在
  - `/room list` 显示 2 个 Room
  - 两个 Room 的 config.json 独立，互不影响
