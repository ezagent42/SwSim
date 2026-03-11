---
name: socialware-dev
description: "Design a new Socialware organization — generates contract template files (.socialware.md) through guided Q&A defining Role, Flow, Commitment, Arena."
---

# Socialware Dev — 契约模板生成

## 启动前置

1. 如果存在 `simulation/workspace/.active-session.json`，删除它（退出 runtime 模式）。
2. **身份确认**: 扫描 `simulation/workspace/identities/*.json`，列出可用身份。
   - 如果无身份 → 提示用户先用 `/room create` 或手动创建身份文件。
   - 如果有身份 → 让用户选择以哪个身份操作（即模板的 `开发者`）。

## 你在创建什么

**你在设计一个 Socialware——一份定义组织结构的契约文件**。

Socialware 是一份 `.socialware.md` 文件，用四个原语描述组织图：
- **Role**: 组织中的位置（不是人）和能力
- **Flow**: 状态机，定义动作如何推进状态
- **Commitment**: 角色间可追踪的承诺
- **Arena**: 谁可以参与

产出的契约是**可分享、可组合的产品**。它可以被不同的 App Dev 各自绑定成不同的 App，也可以被其他 Socialware 通过引用组合。

## 制品

- **产出**: `simulation/contracts/{name}.socialware.md`（状态: 模板，开发者: 当前身份）
- 文件扩展名: `.socialware.md`
- 命名: 用户自选描述性名称（如 `two-role-submit-approve.socialware.md`）
- 这份文件是 **Socialware 产品**——可分发给不同的 App Dev 各自绑定
- App Dev 阶段会 **复制** 此模板到 app-store 中再开发，模板本身保持不变
- 契约格式: 见 @reference/contract-spec.md

## 流程

每次只问一个问题，按序收集:

1. **场景**: 这个组织做什么？有哪些角色（位置，不是人）？
2. **§1 Roles**: 整理角色表（R-ID, 名称, 能力），持有者全部 `_待绑定_`
3. **§2 Flows**: 每个流程的状态机，**严格遵守以下格式**：
   - 5 列：`当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束`
   - **要求角色**列必须用 R-ID（`R1`, `R2`），不能用角色名（~~submitter~~）
   - **能力约束**列只能是三选一：`any` / `author` / `author | role:{R}`，不能写能力名（~~submit~~）
   - **subject 动作**（创建 Flow 实例的第一个动作）的当前状态写 `_none_`
   - 示例：
     ```
     | 当前状态   | 动作    | 下一状态   | 要求角色 | 能力约束 |
     |-----------|---------|-----------|---------|---------|
     | _none_    | submit  | submitted | R1      | any     |
     | submitted | approve | approved  | R2      | any     |
     | submitted | reject  | rejected  | R2      | any     |
     | rejected  | revise  | submitted | R1      | author  |
     ```
4. **§3 Commitments**: 角色间的承诺，**严格使用以下表格格式**：
   ```
   | C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限 |
   |------|------|--------|--------|---------|------|
   | C1 | {具体可衡量的义务} | R{n} | R{m} | {trigger} | _待绑定_ |
   ```
   - C-ID: C1, C2, ...
   - 债务人/债权人: 使用 R-ID
   - 时限: 模板阶段统一用 `_待绑定_`
   - **承诺必须具体可衡量**：包含 `{动作} + {量化指标} + {条件}`
   - 如果用户给出模糊描述（如"及时审批"），主动追问：具体多长时间？什么算完成？
   - 示例对比：
     - ❌ `及时审批`
     - ✅ `在提交后 24 小时内完成审批（approve 或 reject）`
5. **§4 Arena**: 进入策略
6. **§5 Context Bindings**: 自动生成骨架（从 Flow 提取动作），**严格使用列表格式**（与 contract-spec.md 一致）：
   ```markdown
   ## §5 Context Bindings

   ### on: {action}
   - 前置: {role} [+ 状态={state}]
   - 工具: _待实现_
   - 输入: _待实现_
   - 输出: _待实现_
   - 消息模板: _待实现_
   - 依赖: _待实现_ 或 _无_
   - 委托: _待实现_ 或 _无_
   - 资源: _待实现_ 或 _无_
   ```
   - 依赖/委托/资源: 如果设计层有需求用 `_待实现_`，确实没有用 `_无_`
   - **禁止使用表格格式**——列表格式是唯一合法格式
7. **命名**: 让用户为模板文件命名（描述性名称，如 `two-role-submit-approve`）
8. **确认**: 展示预览，写入文件（头部自动填入 `开发者: {当前身份}`）

## 完成提示

模板设计完成后，提示用户下一步：

> 模板已保存到 `simulation/contracts/`。下一步用 `/socialware-app-dev` 基于此模板开发 App（填入工具绑定）。

**完整流程参考**: `/room` → `/socialware-dev` → `/socialware-app-dev` → `/socialware-app-install` → `/socialware-app`

## 关键原则

- **只定义图，不填 context**: §5 工具全部 `_待实现_`
- **§5 格式统一**: 必须使用 `### on: {action}` 列表格式（见 contract-spec.md），禁止使用表格格式
- **§5 标记**: 模板用 `_待实现_`（等待 App Dev 填入工具），不是 `_待绑定_`
- **§1 持有者标记**: 用 `_待绑定_`（等待 App Install 填入用户）
- **承诺必须可衡量**: 不接受模糊描述，主动追问量化指标
- **角色 = 位置**: 同一人可持有多个角色
- **Flow = 状态机**: 必须有明确状态和转换
- **Commitment = 可追踪的义务**
- **依赖/委托/资源**: 在模板中声明抽象需求（`_待实现_`），不是 `_无_`
- **文件扩展名**: `.socialware.md`，不是 `.contract.md`
- **身份格式**: `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`），无 `@` 前缀
