---
name: socialware-app-dev
description: "Develop a Socialware App based on an existing contract template — fill §5 tool bindings and save to app-store. Use /socialware-app-install to install into a Room."
---

# Socialware App Dev — 基于模板开发 App

## 启动前置

1. 如果存在 `simulation/workspace/.active-session.json`，删除它（退出 runtime 模式）。
2. **身份确认**: 扫描 `simulation/workspace/identities/*.json`，列出可用身份。
   - 如果无身份 → 提示用户先用 `/room create` 或手动创建身份文件。
   - 如果有身份 → 让用户选择以哪个身份操作（即 App 的 `开发者`）。

## 你在创建什么

**你在基于一份 Socialware 模板（组织蓝图）开发一个 App——填入具体的工具绑定**。

模板是只读的蓝图（`.socialware.md`），App 是新生成的可运行包（`.app.md`）。你不会修改模板——你会复制它，填入具体的工具实现，生成一个新的 App 文件保存到 app-store。

**注意**：App Dev 只负责工具绑定（§5），**不负责**用户绑定（§1）和安装到 Room。那是 `/socialware-app-install` 的工作。

过程:
- 选择一份模板（`simulation/contracts/*.socialware.md`）
- 为 App 取一个描述性 ID（如 `doc-review-workflow`）
- 给每个动作绑定具体的工具
- 声明跨契约引用（依赖/委托/资源）
- 生成 `{app-id}.app.md` 保存到 app-store

## 制品关系

```
输入（只读）                              输出（App 制品）
─────────                               ─────────────
simulation/contracts/                    simulation/workspace/app-store/
  {name}.socialware.md                     {app-id}.app.md  ← 已开发的 App
  状态: 模板                               状态: 已开发
  §5 全部 _待实现_                          §5 已填工具
  §1 全部 _待绑定_                          §1 仍然 _待绑定_（install 阶段填）
  ★ 不修改此文件                            namespace 未定（install 阶段选）
```

- **模板不变**: `simulation/contracts/{name}.socialware.md` 是 Socialware 产品，只读不改
- **App 输出到 app-store**: `simulation/workspace/app-store/{app-id}.app.md`
- **命名解耦**: 模板名、app-id、namespace 三者由用户在各阶段独立选择

## 流程

### Phase 1: 选择模板和命名

1. 列出可用模板（`simulation/contracts/*.socialware.md`），让用户选择
2. 让用户选择 App-ID（描述性名称，如 `doc-review-workflow`）
3. 读取模板，展示概要（Role, Flow, Commitment, Arena）

### Phase 2: 填充 Bindings（§5）

4. 逐个动作填充，每次一个，**严格使用列表格式**（与 contract-spec.md 和模板格式一致）:
   - 工具: 提示时**必须列出全部 5 种**，格式如下:
     ```
     工具类型（5 选 1）:
       manual        — 用户手动输入内容
       bash: {cmd}   — 执行 Shell 命令（如 bash: python analyze.py）
       mcp: {s}/{t}  — 调用 MCP Server 工具（如 mcp: ew-server/create_branch）
       api: {M} {url} — HTTP API 调用（如 api: POST http://localhost:8080/review）
       llm: {prompt}  — LLM 自主生成内容（如 llm: 根据 {diff} 生成审查意见）
     ```
   - 输入/输出
   - 消息模板
   - 依赖/委托/资源（从模板的 `_待实现_` 变为具体引用，或确认 `_无_`）
   - **输出格式必须为**:
     ```markdown
     ### on: {action}
     - 前置: {role} [+ 状态={state}]
     - 工具: manual 或 bash: {cmd} 或 mcp: {s}/{t} 或 ...
     - 输入: {description}
     - 输出: {description}
     - 消息模板: "{emoji} {author} {description}"
     - 依赖: _无_ 或 [{ns}:{flow} {state}](同 Room)
     - 委托: _无_ 或 [{ns}:{role}](同 Room)
     - 资源: _无_ 或 [{ns}:{arena}](同 Room)
     ```
   - **禁止使用表格格式**——列表格式是唯一合法格式，模板和 App 必须一致

### Phase 3: 跨契约引用声明

5. 如果有跨契约依赖，声明引用关系（依赖/委托/资源）
6. 具体的 mock 数据在 install 阶段处理

### Phase 4: 写入

7. 创建 `simulation/workspace/app-store/` 目录（如不存在）
8. 写入 `simulation/workspace/app-store/{app-id}.app.md`:
   - 头部: 状态 → `已开发`，App-ID，基于模板，`开发者: {当前身份}`
   - §1: 持有者保持 `_待绑定_`（不在此阶段填）
   - §5: 填入工具绑定
   - 不写 §6（安装阶段才写）
   - 不更新任何 Room 的 config.json 或 state.json

## 参考

- 数据格式: @reference/data-formats.md

## 完成提示

App 开发完成后，提示用户下一步：

> App 已保存到 app-store。下一步用 `/socialware-app-install` 将此 App 安装到 Room 中（绑定角色到具体用户）。

**完整流程参考**: `/room` → `/socialware-dev` → `/socialware-app-dev` → `/socialware-app-install` → `/socialware-app`

## 关键原则

- **不改变组织图**: 只填充 §5 工具绑定
- **不绑定用户**: §1 持有者保持 `_待绑定_`，那是 install 的工作
- **不选择 Room**: App Dev 不关心 Room，只关心工具实现
- **不确定 namespace**: namespace 在 install 阶段选择
- **一次一个 binding**
- **模板只读**: 永远不修改 `simulation/contracts/` 中的文件
- **输出到 app-store**: `simulation/workspace/app-store/{app-id}.app.md`
- **身份格式**: `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`），无 `@` 前缀
