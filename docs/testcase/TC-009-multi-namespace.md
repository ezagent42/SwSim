# TC-009: 多 Namespace 共存

> **测试目标**：验证同一 Room 中 3 个 Socialware App 共存——多 namespace 独立运行 + 跨 namespace 引用
> **前置依赖**：TC-003（掌握 App 安装流程）
> **测试 Skill**：`/socialware-app-dev` + `/socialware-app-install` + `/socialware-app`
> **覆盖 Spec**：001, 003, 005

---

## 场景：在 alpha Room 中安装 TaskArena(ta)、EventWeaver(ew)、ResPool(rp) 三个 App

### Step 1: 创建 Room 和成员

- **操作**：`/room create alpha`（alice 创建），`/room join alpha bob:Bob@local`
- **前置依赖**：无
- **验证**：Room 和成员就绪
- **验收标准**：
  - `workspace/rooms/alpha/` 目录结构完整
  - `config.json` 中 alice:Alice@local=owner, bob:Bob@local=member

### Step 2: 开发并安装第一个 App (ta)

- **操作**：`/socialware-app-dev`（模板=two-role-submit-approve，App-ID=`task-arena.alice.two-role-submit-approve`）→ `/socialware-app-install`（Room=alpha，namespace=ta，角色绑定）
- **前置依赖**：Step 1，模板 `two-role-submit-approve.socialware.md` 存在（位于 `simulation/socialware/`）
- **验证**：App 开发并安装成功，已注册到 `simulation/app-store/registry.json`
- **验收标准**：
  - `app-store/task-arena.alice.two-role-submit-approve.app.md` 存在（已开发，文件名 = `{AppName}.{DeveloperName}.{SocialwareName}.app.md`）
  - `simulation/app-store/registry.json` 中已注册该 App
  - `contracts/task-arena.alice.two-role-submit-approve.app.md` 存在（已安装）
  - `config.json` 的 `socialware.installed` 包含 `{"app_id": "task-arena.alice.two-role-submit-approve", "namespace": "ta", "contract": "task-arena.alice.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"}`
  - `socialware.roles` 中 alice 包含 ta 角色，bob 包含 ta 角色

### Step 3: 开发并安装第二个 App (ew)

- **操作**：`/socialware-app-dev`（模板=event-weaver，App-ID=`evt-weave.alice.event-weaver`）→ `/socialware-app-install`（从 registry.json 查询选择 App，Room=alpha，namespace=ew，角色绑定）
- **前置依赖**：Step 1，模板存在（位于 `simulation/socialware/`）
- **验证**：App 安装成功，已注册到 registry
- **验收标准**：
  - `contracts/evt-weave.alice.event-weaver.app.md` 存在
  - `socialware.installed` 变为 `[{"app_id": "task-arena.alice.two-role-submit-approve", "namespace": "ta", "contract": "task-arena.alice.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"}, {"app_id": "evt-weave.alice.event-weaver", "namespace": "ew", "contract": "evt-weave.alice.event-weaver.app.md", "template": "event-weaver.socialware.md"}]`
  - `socialware.roles` 中角色列表**累加**（不覆盖 ta 的角色）

### Step 4: 开发并安装第三个 App (rp)

- **操作**：`/socialware-app-dev`（模板=resource-pool，App-ID=`res-pool.alice.resource-pool`）→ `/socialware-app-install`（从 registry.json 查询选择 App，Room=alpha，namespace=rp，角色绑定）
- **前置依赖**：Step 1，模板存在（位于 `simulation/socialware/`）
- **验证**：App 安装成功，已注册到 registry
- **验收标准**：
  - `contracts/res-pool.alice.resource-pool.app.md` 存在
  - `socialware.installed` 变为 `[{"app_id": "task-arena.alice.two-role-submit-approve", "namespace": "ta", "contract": "task-arena.alice.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"}, {"app_id": "evt-weave.alice.event-weaver", "namespace": "ew", "contract": "evt-weave.alice.event-weaver.app.md", "template": "event-weaver.socialware.md"}, {"app_id": "res-pool.alice.resource-pool", "namespace": "rp", "contract": "res-pool.alice.resource-pool.app.md", "template": "resource-pool.socialware.md"}]`
  - `socialware.roles` 中角色列表再次**累加**

### Step 5: 验证 config.json 多 namespace 状态

- **操作**：读取 `config.json`
- **前置依赖**：Step 4
- **验证**：三个 namespace 共存
- **验收标准**：
  - `socialware.installed` = `[{"app_id": "task-arena.alice.two-role-submit-approve", "namespace": "ta", "contract": "task-arena.alice.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"}, {"app_id": "evt-weave.alice.event-weaver", "namespace": "ew", "contract": "evt-weave.alice.event-weaver.app.md", "template": "event-weaver.socialware.md"}, {"app_id": "res-pool.alice.resource-pool", "namespace": "rp", "contract": "res-pool.alice.resource-pool.app.md", "template": "resource-pool.socialware.md"}]`
  - `socialware.roles` 中包含 ta、ew、rp 前缀的 R-ID 键（如 `"ta:R1"`, `"ew:R1"`, `"rp:R1"` 等），值为 `alice:Alice@local` 或 `bob:Bob@local`
  - 角色格式为 `{ns}:{R-ID}`（如 `"ta:R1": "alice:Alice@local"`）

### Step 6: 运行 ta namespace 操作

- **操作**：alice 执行 `ta:submit`
- **前置依赖**：Step 4
- **验证**：ta namespace 操作独立
- **验收标准**：
  - Timeline entry 的 `ext.command.namespace` = `ta`
  - `flow_states["msg-001"].flow` = `ta:task_lifecycle`
  - 不影响 ew 或 rp 的状态

### Step 7: 运行 ew namespace 操作

- **操作**：alice 执行 `ew:create_branch`（或 ew 对应的 subject action）
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

### Step 11: 同一模板不同 App-ID 和 Namespace

- **操作**：`/socialware-app-dev`（模板=two-role-submit-approve，App-ID=`task-arena-v2.bob.two-role-submit-approve`，开发者=bob）→ `/socialware-app-install`（从 registry.json 查询选择 App，Room=alpha，namespace=ta2，角色绑定）
- **前置依赖**：Step 2
- **验证**：同一模板可以用不同 AppName/DeveloperName 多次开发（生成不同 app-id），并以不同 namespace 安装；App 注册到 registry
- **验收标准**：
  - `app-store/task-arena-v2.bob.two-role-submit-approve.app.md` 存在（已开发，文件名 = `{AppName}.{DeveloperName}.{SocialwareName}.app.md`）
  - `simulation/app-store/registry.json` 中同时包含 `task-arena.alice.two-role-submit-approve` 和 `task-arena-v2.bob.two-role-submit-approve` 两个条目
  - `contracts/task-arena-v2.bob.two-role-submit-approve.app.md` 存在（已安装）
  - `socialware.installed` 包含 `{"app_id": "task-arena.alice.two-role-submit-approve", ...}` 和 `{"app_id": "task-arena-v2.bob.two-role-submit-approve", "namespace": "ta2", "contract": "task-arena-v2.bob.two-role-submit-approve.app.md", "template": "two-role-submit-approve.socialware.md"}`
  - ta 和 ta2 的 flow instances 完全独立
  - 角色绑定可以不同（ta2 的审批者可以是 alice，而 ta 的审批者是 bob）
