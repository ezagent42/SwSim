# TC-009: 多 Namespace 共存

> **测试目标**：验证同一 Room 中 3 个 Socialware App 共存——多 namespace 独立运行 + 跨 namespace 引用
> **前置依赖**：TC-003（掌握 App 安装流程）
> **测试 Skill**：`/socialware-app-dev` + `/socialware-app`
> **覆盖 Spec**：001, 003, 005

---

## 场景：在 alpha Room 中安装 TaskArena(ta)、EventWeaver(ew)、ResPool(rp) 三个 App

### Step 1: 创建 Room 和成员

- **操作**：`/room create alpha`（@alice 创建），`/room join alpha @bob`
- **前置依赖**：无
- **验证**：Room 和成员就绪
- **验收标准**：
  - `workspace/rooms/alpha/` 目录结构完整
  - `config.json` 中 @alice=owner, @bob=member

### Step 2: 安装第一个 App (ta)

- **操作**：`/socialware-app-dev`，模板=two-role-submit-approve，Room=alpha，namespace=ta
- **前置依赖**：Step 1，模板 `two-role-submit-approve.socialware.md` 存在
- **验证**：ta.app.md 安装成功
- **验收标准**：
  - `contracts/ta.app.md` 存在
  - `config.json` 的 `socialware.installed` 包含 `"ta"`
  - `socialware.roles` 中 @alice 包含 ta 角色，@bob 包含 ta 角色

### Step 3: 安装第二个 App (ew)

- **操作**：`/socialware-app-dev`，模板=event-weaver（假设已有），Room=alpha，namespace=ew
- **前置依赖**：Step 1，模板存在
- **验证**：ew.app.md 安装成功
- **验收标准**：
  - `contracts/ew.app.md` 存在
  - `socialware.installed` 变为 `["ta", "ew"]`
  - `socialware.roles` 中角色列表**累加**（不覆盖 ta 的角色）

### Step 4: 安装第三个 App (rp)

- **操作**：`/socialware-app-dev`，模板=resource-pool（假设已有），Room=alpha，namespace=rp
- **前置依赖**：Step 1，模板存在
- **验证**：rp.app.md 安装成功
- **验收标准**：
  - `contracts/rp.app.md` 存在
  - `socialware.installed` 变为 `["ta", "ew", "rp"]`
  - `socialware.roles` 中角色列表再次**累加**

### Step 5: 验证 config.json 多 namespace 状态

- **操作**：读取 `config.json`
- **前置依赖**：Step 4
- **验证**：三个 namespace 共存
- **验收标准**：
  - `socialware.installed` = `["ta", "ew", "rp"]`
  - `socialware.roles["@alice:local"]` 包含 ta、ew、rp 前缀的角色
  - `socialware.roles["@bob:local"]` 包含 ta、ew、rp 前缀的角色
  - 角色格式为 `{ns}:{role_name}`

### Step 6: 运行 ta namespace 操作

- **操作**：@alice 执行 `ta:submit`
- **前置依赖**：Step 4
- **验证**：ta namespace 操作独立
- **验收标准**：
  - Timeline entry 的 `ext.command.namespace` = `ta`
  - `flow_states["msg-001"].flow` = `ta:task_lifecycle`
  - 不影响 ew 或 rp 的状态

### Step 7: 运行 ew namespace 操作

- **操作**：@alice 执行 `ew:create_branch`（或 ew 对应的 subject action）
- **前置依赖**：Step 4
- **验证**：ew namespace 操作独立
- **验收标准**：
  - Timeline entry 的 `ext.command.namespace` = `ew`
  - `flow_states["msg-002"].flow` = `ew:branch_lifecycle`（或对应 flow 名）
  - ta 的 flow_states 不受影响

### Step 8: 共存的 state.json

- **操作**：读取 `state.json`
- **前置依赖**：Step 7
- **验证**：多 namespace 的 flow_states 共存
- **验收标准**：
  - `flow_states` 中有 ta 和 ew 的 flow instances
  - 可通过 `flow` 字段的 namespace 前缀区分：`ta:xxx` vs `ew:xxx`
  - `role_map` 包含所有 namespace 的角色
  - `last_clock` 是全局的（跨 namespace 共享）

### Step 9: 跨 Namespace 前置检查

- **操作**：执行一个需要跨 namespace 引用的 action（如 `ew:merge` 依赖 `ta:task_lifecycle` 处于某状态）
- **前置依赖**：Step 6, Step 7
- **验证**：pre_send 中的跨 namespace 检查正确
- **验收标准**：
  - Cross-NS Check 读取 state.json 中其他 namespace 的 flow_states
  - 按 `flow` 字段前缀过滤：`v["flow"].startswith("ta:")`
  - 如果前置条件满足 → 操作通过
  - 如果前置条件不满足 → 操作被拒绝，错误信息说明缺少的前置状态

### Step 10: Namespace 命名空间隔离

- **操作**：验证不同 namespace 的操作命令不冲突
- **前置依赖**：Step 5
- **验证**：命令空间隔离
- **验收标准**：
  - `ta:submit` 和 `ew:submit`（如果都有 submit action）是不同的操作
  - 用户执行 `submit` 时需明确指定 namespace
  - 如果只有一个 namespace 有 submit，可以自动推断
  - `/status` 分 namespace 展示 flow instances

### Step 11: 同一模板不同 Namespace

- **操作**：再次用 `two-role-submit-approve.socialware.md` 安装到 alpha Room，namespace=ta2
- **前置依赖**：Step 2
- **验证**：同一模板可以多次安装
- **验收标准**：
  - `contracts/ta2.app.md` 存在
  - `socialware.installed` 包含 `"ta"` 和 `"ta2"`
  - ta 和 ta2 的 flow instances 完全独立
  - 角色绑定可以不同（ta2 的审批者可以是 @alice，而 ta 的审批者是 @bob）
