# TC-003: App 绑定安装

> **测试目标**：验证 `/socialware-app-dev` 完整绑定流程——从选择模板到生成 `.app.md`
> **前置依赖**：TC-001（模板已创建）, TC-002（Room 已创建，成员已加入）
> **测试 Skill**：`/socialware-app-dev`
> **覆盖 Spec**：003, 007

---

## 场景：将审批模板安装到 doc-review Room

### Step 1: 启动绑定流程

- **操作**：执行 `/socialware-app-dev`
- **前置依赖**：`simulation/contracts/two-role-submit-approve.socialware.md` 存在，`rooms/doc-review/` 存在且有 @alice 和 @bob
- **验证**：Skill 列出可用 Room 和可用模板
- **验收标准**：
  - Room 列表包含 `doc-review`
  - 模板列表包含 `two-role-submit-approve.socialware.md`

### Step 2: 选择 Room、模板和 Namespace

- **操作**：选择 Room=doc-review，模板=two-role-submit-approve，namespace=da
- **前置依赖**：Step 1
- **验证**：Skill 展示模板概要（Role, Flow, Commitment, Arena）
- **验收标准**：
  - Namespace 为 2-4 字母（da）
  - 展示的概要与模板文件内容一致

### Step 3: 绑定角色

- **操作**：R1(提交者) → @alice:local，R2(审批者) → @bob:local
- **前置依赖**：Step 2
- **验证**：角色绑定被接受
- **验收标准**：
  - 每个 Holder 必须是 Room 成员（在 config.json 的 membership.members 中）
  - 同一人可持有多个角色（如果测试中需要）

### Step 4: 绑定工具（§5）

- **操作**：逐个 action 选择工具类型
  - task_lifecycle.submit → manual
  - task_lifecycle.approve → manual
  - task_lifecycle.reject → manual
  - task_lifecycle.revise → manual
- **前置依赖**：Step 3
- **验证**：每个 action 的 §5 binding 被填充
- **验收标准**：
  - 每次只处理一个 action（一次一个 binding）
  - Tool 值为 5 种有效类型之一：bash / mcp / api / manual / llm
  - Input/Output 有具体描述（不再是 `_待绑定_`）
  - 消息模板有具体格式
  - 依赖从 `_待绑定_` 变为具体引用或确认 `_无_`

### Step 5: 验证生成的 .app.md

- **操作**：读取 `workspace/rooms/doc-review/contracts/da.app.md`
- **前置依赖**：Step 4
- **验证**：文件格式和内容完整
- **验收标准**：
  - 文件名为 `{namespace}.app.md`（即 `da.app.md`），不是模板名
  - Header 中状态为「已绑定」
  - Header 包含来源模板名、Namespace、Room 名
  - §1 Holder 全部为具体 Identity（@alice:local, @bob:local）
  - §2 Flows 与模板完全相同（未修改任何状态转换）
  - §3 Commitments 与模板完全相同
  - §4 Arena 与模板完全相同
  - §5 所有 Tool 已填入（不再有 `_待绑定_`）
  - §6 Simulation Environment 存在

### Step 6: 验证模板未被修改

- **操作**：读取 `simulation/contracts/two-role-submit-approve.socialware.md`
- **前置依赖**：Step 5
- **验证**：模板内容与 TC-001 创建时完全一致
- **验收标准**：
  - §1 Holder 仍为 `_待绑定_`
  - §5 Tool 仍为 `_待绑定_`
  - 文件无任何修改

### Step 7: 验证 config.json 更新

- **操作**：读取 `workspace/rooms/doc-review/config.json`
- **前置依赖**：Step 5
- **验证**：Socialware 注册信息
- **验收标准**：
  - `socialware.installed` 包含 `"da"`
  - `socialware.roles` 中 `@alice:local` 包含 `"da:poster"` 或对应角色名
  - `socialware.roles` 中 `@bob:local` 包含 `"da:approver"` 或对应角色名

### Step 8: 验证 state.json 更新

- **操作**：读取 `workspace/rooms/doc-review/state.json`
- **前置依赖**：Step 5
- **验证**：role_map 和 commitments 初始化
- **验收标准**：
  - `role_map` 包含 @alice 和 @bob 的角色映射
  - `commitments` 包含 `da:C1`，状态为 `inactive`
  - `flow_states` 仍为空（还没有执行任何动作）

### Step 9: 命名解耦验证

- **操作**：确认模板名和 namespace 完全独立
- **前置依赖**：Step 5
- **验证**：
  - 模板文件名：`two-role-submit-approve.socialware.md`
  - App 文件名：`da.app.md`
  - 两者没有命名依赖关系
- **验收标准**：同一模板可以在不同 Room 以不同 namespace 安装（如 `ta.app.md`）
