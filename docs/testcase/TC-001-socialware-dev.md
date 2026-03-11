# TC-001: Socialware 模板设计

> **测试目标**：验证 `/socialware-dev` 能通过引导式 Q&A 生成有效的 `.socialware.md` 模板文件
> **前置依赖**：无
> **测试 Skill**：`/socialware-dev`
> **覆盖 Spec**：002

---

## 场景：设计一个 2-role 审批工作流

### Step 1: 启动 Skill

- **操作**：执行 `/socialware-dev`，描述需求："设计一个双角色审批流——提交者提交文档，审批者审批或驳回"
- **前置依赖**：无
- **验证**：Skill 开始引导 Q&A，先询问场景和角色
- **验收标准**：Skill 逐步提问，一次一个问题，不跳步

### Step 2: 定义 Roles（§1）

- **操作**：回答角色问题：2 个角色，提交者（submit, revise）和审批者（approve, reject）
- **前置依赖**：Step 1
- **验证**：Skill 生成 §1 Roles 表格
- **验收标准**：
  - ID 为 R1, R2 格式
  - Capabilities 列表与输入一致
  - Holder 全部为 `_待绑定_`（不能是具体 Identity）

### Step 3: 定义 Flows（§2）

- **操作**：回答 Flow 问题：task_lifecycle 状态机（_none_ → submit → submitted → approve/reject → approved/rejected, rejected → revise → submitted）
- **前置依赖**：Step 2
- **验证**：Skill 生成 §2 Flow 转换表
- **验收标准**：
  - 5 列格式：Current State | Action | Next State | Required Role | CBAC
  - 第一行 Current State = `_none_`（subject action）
  - 每个 Required Role 引用 §1 中定义的 R-ID
  - CBAC 值仅为 `any`、`author` 或 `author | role:{R}` 之一
  - 无孤立状态（每个状态都能到达且可从某处进入）

### Step 4: 定义 Commitments（§3）

- **操作**：回答 Commitment 问题：审批者需在 48h 内回复
- **前置依赖**：Step 3
- **验证**：Skill 生成 §3 Commitments 表格
- **验收标准**：
  - ID 为 C1 格式
  - 当事方使用 R-ID 引用（如 R2 → R1）
  - 触发条件关联 §2 中的 Flow state
  - 截止时间格式清晰

### Step 5: 定义 Arena（§4）

- **操作**：回答 Arena 问题：role_based，持有 R1 或 R2 即可进入
- **前置依赖**：Step 4
- **验证**：Skill 生成 §4 Arena 表格
- **验收标准**：准入策略为 `role_based` / `anyone` / `invite_only` 之一

### Step 6: 生成 Bindings 骨架（§5）

- **操作**：Skill 自动从 §2 的 Flow 提取所有 action，生成 §5 骨架
- **前置依赖**：Step 5
- **验证**：§5 包含每个 action 的 binding 块
- **验收标准**：
  - 每个 Flow action 都有对应的 §5 binding 块
  - 工具 (Tool) 全部为 `_待实现_`
  - 输入/输出/消息模板全部为 `_待实现_`
  - 依赖/委托/资源为 `_待实现_` 或 `_无_`（视设计意图）
  - submit 的 Requires = `_无_`（无依赖）
  - approve/reject 的 Requires = `_待实现_`（需要检查 submitted 状态）

### Step 7: 命名和确认

- **操作**：命名模板为 `two-role-submit-approve`，确认预览
- **前置依赖**：Step 6
- **验证**：文件写入 `simulation/socialware/two-role-submit-approve.socialware.md`
- **验收标准**：
  - 文件路径正确：`simulation/socialware/two-role-submit-approve.socialware.md`
  - 扩展名为 `.socialware.md`（不是 `.contract.md` 或 `.app.md`）
  - Header 中状态为「模板」
  - 文件内容包含 §1-§5 全部章节
  - §1 Holder 全部为 `_待绑定_`
  - §5 Tool 全部为 `_待实现_`

### Step 8: 模板只读验证

- **操作**：尝试通过 `/socialware-app-dev` 或 `/socialware-app-install` 读取刚创建的模板（模板位于 `simulation/socialware/`）
- **前置依赖**：Step 7
- **验证**：模板能被正确列出和读取
- **验收标准**：模板出现在可用模板列表中，内容与创建时完全一致
