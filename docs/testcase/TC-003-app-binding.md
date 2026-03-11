# TC-003: App 开发与安装

> **测试目标**：验证 `/socialware-app-dev`（工具绑定 → app-store）+ `/socialware-app-install`（角色绑定 → Room）完整流程
> **前置依赖**：TC-001（模板已创建）, TC-002（Room 已创建，成员已加入）
> **测试 Skill**：`/socialware-app-dev` + `/socialware-app-install`
> **覆盖 Spec**：003, 007

---

## 场景：将审批模板开发并安装到 doc-review Room

### Phase 1: App 开发（`/socialware-app-dev`）——工具绑定 → app-store

### Step 1: 启动开发流程

- **操作**：执行 `/socialware-app-dev`
- **前置依赖**：`simulation/contracts/two-role-submit-approve.socialware.md` 存在
- **验证**：Skill 列出可用模板
- **验收标准**：
  - 模板列表包含 `two-role-submit-approve.socialware.md`

### Step 2: 选择模板和 App-ID

- **操作**：选择模板=two-role-submit-approve，app-id=da
- **前置依赖**：Step 1
- **验证**：Skill 展示模板概要（Role, Flow, Commitment, Arena）
- **验收标准**：
  - App-ID 为描述性名称（此处用 `da`）
  - 展示的概要与模板文件内容一致
  - **注意**：Namespace 不在此阶段选择，而是在 App Install 阶段选择

### Step 3: 绑定工具（§5）

- **操作**：逐个 action 选择工具类型
  - task_lifecycle.submit → manual
  - task_lifecycle.approve → manual
  - task_lifecycle.reject → manual
  - task_lifecycle.revise → manual
- **前置依赖**：Step 2
- **验证**：每个 action 的 §5 binding 被填充
- **验收标准**：
  - 每次只处理一个 action（一次一个 binding）
  - Tool 值为 5 种有效类型之一：bash / mcp / api / manual / llm
  - Input/Output 有具体描述（不再是 `_待实现_`）
  - 消息模板有具体格式
  - 依赖从 `_待实现_` 变为具体引用或确认 `_无_`

### Step 4: 验证 app-store 中的已开发 App

- **操作**：读取 `simulation/workspace/app-store/da.app.md`
- **前置依赖**：Step 3
- **验证**：文件格式和内容完整
- **验收标准**：
  - 文件存放在 `simulation/workspace/app-store/` 目录
  - 文件名为 `{app-id}.app.md`（即 `da.app.md`），不是模板名
  - Header 中状态为「已开发」
  - Header 包含来源模板名、App-ID
  - §1 Holder 仍为 `_待绑定_`（角色绑定在安装阶段完成）
  - §2 Flows 与模板完全相同（未修改任何状态转换）
  - §3 Commitments 与模板完全相同
  - §4 Arena 与模板完全相同
  - §5 所有 Tool 已填入（不再有 `_待实现_`）
  - §6 Simulation Environment 存在

### Step 5: 验证模板未被修改

- **操作**：读取 `simulation/contracts/two-role-submit-approve.socialware.md`
- **前置依赖**：Step 4
- **验证**：模板内容与 TC-001 创建时完全一致
- **验收标准**：
  - §1 Holder 仍为 `_待绑定_`
  - §5 Tool 仍为 `_待实现_`
  - 文件无任何修改

### Phase 2: App 安装（`/socialware-app-install`）——角色绑定 → Room

### Step 6: 启动安装流程

- **操作**：执行 `/socialware-app-install`
- **前置依赖**：Step 4（app-store 中有 da.app.md），`rooms/doc-review/` 存在且有 alice 和 bob
- **验证**：Skill 列出可用 Room 和 app-store 中的可用 App
- **验收标准**：
  - Room 列表包含 `doc-review`
  - App 列表包含 `da`（来自 app-store）

### Step 7: 选择 Room、Namespace 并绑定角色

- **操作**：选择 Room=doc-review，Namespace=da，R1(提交者) → alice:Alice@local，R2(审批者) → bob:Bob@local
- **前置依赖**：Step 6
- **验证**：Namespace 和角色绑定被接受
- **验收标准**：
  - Namespace 为 2-4 字母（da），在此阶段选择
  - 每个 Holder 必须是 Room 成员（在 config.json 的 membership.members 中）
  - 同一人可持有多个角色（如果测试中需要）

### Step 8: 验证安装到 Room 的 .app.md

- **操作**：读取 `workspace/rooms/doc-review/contracts/da.app.md`
- **前置依赖**：Step 7
- **验证**：文件格式和内容完整
- **验收标准**：
  - 文件名为 `{app-id}.app.md`（即 `da.app.md`），不是模板名
  - Header 中状态为「已安装」
  - Header 包含来源模板名、App-ID、Namespace、Room 名
  - §1 Holder 全部为具体 Identity（alice:Alice@local, bob:Bob@local）
  - §2 Flows 与模板完全相同（未修改任何状态转换）
  - §3 Commitments 与模板完全相同
  - §4 Arena 与模板完全相同
  - §5 所有 Tool 已填入（不再有 `_待实现_`）
  - §6 Simulation Environment 存在

### Step 9: 验证 config.json 更新

- **操作**：读取 `workspace/rooms/doc-review/config.json`
- **前置依赖**：Step 8
- **验证**：Socialware 注册信息
- **验收标准**：
  - `socialware.installed` 包含 `{"app_id": "da", "namespace": "da", "contract": "da.app.md", "template": "two-role-submit-approve.socialware.md"}`
  - `socialware.roles` 中包含 `"da:R1": "alice:Alice@local"`（或对应 R-ID）
  - `socialware.roles` 中包含 `"da:R2": "bob:Bob@local"`（或对应 R-ID）

### Step 10: 验证 state.json 更新

- **操作**：读取 `workspace/rooms/doc-review/state.json`
- **前置依赖**：Step 8
- **验证**：role_map 和 commitments 初始化
- **验收标准**：
  - `role_map` 包含 alice 和 bob 的角色映射
  - `commitments` 包含 `da:C1`，状态为 `inactive`
  - `flow_states` 仍为空（还没有执行任何动作）

### Step 11: 命名解耦验证

- **操作**：确认模板名和 namespace 完全独立
- **前置依赖**：Step 8
- **验证**：
  - 模板文件名：`two-role-submit-approve.socialware.md`
  - App-ID：`da`
  - App 文件名：`da.app.md`（以 app-id 命名，格式为 `{app-id}.app.md`）
  - Namespace：`da`（在 install 阶段选择，可与 app-id 不同）
  - 三者（模板名、app-id、namespace）互相独立
- **验收标准**：同一模板可以用不同 app-id 多次开发，也可以在不同 Room 以不同 namespace 安装

### Step 12: 契约状态流转验证

- **操作**：确认契约经过了完整的三态流转
- **前置依赖**：Step 8
- **验证**：状态链完整
- **验收标准**：
  - 模板（`.socialware.md`）状态为「模板」
  - app-store 中的 App（`app-store/da.app.md`）状态为「已开发」
  - Room 中的 App（`contracts/da.app.md`）状态为「已安装」
  - 三态流转：模板 → 已开发 → 已安装
