# 007 — 开发者接入指南：从模板到真实工具

> **状态**：Draft v1
> **日期**：2026-03-10
> **作者**：Allen & Claude collaborative design

---

## 1. 概述

本文档面向**拿到 Socialware 模板（`.socialware.md`）的开发者**——你有真实的工具（CLI 二进制、MCP Server、HTTP API），想要接入 Socialware 的协作流程。

**核心理解**：Socialware 模板定义「做什么」（组织结构 + 工作流），你决定「怎么做」（绑定什么工具）。同一份模板，不同开发者可以绑定完全不同的工具——就像 Git 不限制你用什么编辑器。

---

## 2. 接入全景

```
你收到一份 .socialware.md 模板
    │
    ▼
阅读模板：理解 Role / Flow / Commitment / Arena
    │
    ▼
评估工具：你本地有什么？CLI? MCP Server? API? 还是先用 manual?
    │
    ▼
创建/加入 Room (/room)
    │
    ▼
绑定安装 (/socialware-app-dev)：为每个 Action 选择工具 → 生成 .app.md
    │
    ▼
运行 (/socialware-app)：Hook Pipeline 的 execute 阶段调用你绑定的工具
```

---

## 3. 第一步：阅读模板

收到模板后，关注以下章节：

### 3.1 §1 Roles — 你需要扮演哪个角色？

```markdown
| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | 开发者 | create_branch, push, archive | _待绑定_ |
| R2 | 审查者 | request_merge, merge | _待绑定_ |
```

问自己：我是 R1 还是 R2？我需要具备哪些 capabilities 对应的工具？

### 3.2 §2 Flows — 工作流是什么？

```markdown
| Current State | Action | Next State | Required Role | CBAC |
|---------------|--------|------------|---------------|------|
| _none_ | branch.create | active | R1 | any |
| active | merge.request | merge_pending | R1 | author |
| merge_pending | merge.execute | merged | R2 | any |
```

问自己：每个 Action 对应我的工具的哪个命令？

### 3.3 §5 Context Bindings — 需要绑定什么？

模板中 §5 的所有工具都是 `_待绑定_`。这就是你需要填入的内容。

```markdown
### Action: branch_lifecycle.branch.create

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | _待绑定_ |           ← 你的 CLI 命令 / MCP 工具 / API 端点
| 输入 (Input) | _待绑定_ |          ← 你的工具需要什么参数
| 输出 (Output) | _待绑定_ |         ← 你的工具返回什么
| 消息模板 (Message Template) | _待绑定_ |
| 依赖 (Requires) | _无_ |
```

---

## 4. 第二步：评估你的工具

### 4.1 工具类型速查

| 你有什么 | 绑定为 | 示例 |
|---------|--------|------|
| CLI 二进制 | `bash: ./ew-cli {command} {args}` | `bash: ./ew-cli branch create --name {name}` |
| MCP Server | `mcp: {server}/{tool}` | `mcp: ew-server/create_branch` |
| HTTP API | `api: {method} {url}` | `api: POST http://localhost:9090/branches` |
| AI/LLM | `llm: {prompt_template}` | `llm: 根据以下需求生成分支名: {description}` |
| 什么都没有 | `manual` | 手动输入内容 |

### 4.2 混合绑定

你不需要对所有 Action 使用同一种工具类型。常见模式：

```
branch.create   → bash: ./ew-cli branch create --name {name}   ← 有 CLI
merge.request   → manual                                        ← 需要人工判断
merge.execute   → api: POST http://localhost:9090/merge         ← 有 API
branch.archive  → bash: ./ew-cli branch archive --id {id}      ← 有 CLI
```

### 4.3 渐进式接入

推荐的接入策略——**先 manual，后自动化**：

```
Phase 1: 全部 manual → 验证 Flow 逻辑正确
Phase 2: 核心操作替换为 bash/mcp/api → 验证工具集成
Phase 3: 所有操作自动化 → 生产就绪
```

这是 TDD 思路：先验证协议，再加工具。

---

## 5. 第三步：绑定安装

### 5.1 创建/加入 Room

```
/room create my-project
/room join my-project @alice
```

### 5.2 运行绑定

```
/socialware-app-dev
```

Skill 引导你完成：
1. 选择模板（从 `simulation/contracts/` 中选）
2. 选择 namespace（如 `ew`）
3. 绑定 Role → Identity（你是谁，队友是谁）
4. **逐个 Action 绑定工具**（这是核心步骤）

### 5.3 绑定示例

**Action: branch.create**

Skill 问你：

```
Action: branch_lifecycle.branch.create
  需要角色: R1 (开发者)
  工具类型? [bash / mcp / api / manual / llm]: bash
  命令: ./ew-cli branch create --name {name} --desc {description}
  输入参数: name: 分支名, description: 分支描述
  输出: 分支创建确认 (branch_id, name, status)
  消息模板: 🌿 @{author} 创建了分支: {name}
```

生成的 §5 绑定：

```markdown
### Action: branch_lifecycle.branch.create

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | bash: ./ew-cli branch create --name {name} --desc {description} |
| 输入 (Input) | name: 分支名, description: 分支描述 |
| 输出 (Output) | branch_id, name, status |
| 消息模板 (Message Template) | 🌿 @{author} 创建了分支: {name} |
| 依赖 (Requires) | _无_ |
| 委托 (Delegates) | _无_ |
| 资源 (Requests) | _无_ |
```

---

## 6. 第四步：运行

### 6.1 启动

```
/socialware-app
Room: my-project
Identity: @alice:local
```

### 6.2 Hook Pipeline 调用你的工具

当你说"创建一个 hotfix 分支"时：

```
用户输入: "创建一个 hotfix 分支"
    │
    ▼
解析: ew:branch.create
    │
    ▼
pre_send (纯契约检查，不涉及你的工具):
├── Role Check: @alice 持有 R1? ✓
├── CBAC Check: any → 通过 ✓
├── Flow Check: _none_ → branch.create → active ✓
    │
    ▼
execute (调用你的工具):
├── 读取 §5: Tool = bash: ./ew-cli branch create --name {name}
├── 执行: bash ./ew-cli branch create --name hotfix --desc "紧急修复"
├── 捕获 stdout: { "branch_id": "br-001", "name": "hotfix", "status": "active" }
├── 生成 Content Object → content/sha256_{hash}.json
    │
    ▼
after_write (纯数据操作):
├── Append Ref → timeline/shard-001.jsonl
├── Update State: flow_states["msg-001"] = { flow: "ew:branch_lifecycle", state: "active" }
└── Broadcast: 通知其他 peer
```

**关键**：你的工具只在 execute 阶段运行。契约检查（pre_send）和状态持久化（after_write）与你的工具无关。即使你的工具失败，契约逻辑不受影响。

---

## 7. 非对称协作

### 7.1 同一 Room，不同工具

你和队友可以对同一个 Action 使用不同的工具：

```
@alice:local (有 ew-cli)              @bob:local (无 ew-cli)
─────────────────────                 ───────────────────
ew:branch.create 绑定:                ew:branch.create 绑定:
  Tool: bash: ./ew-cli branch create    Tool: manual
  (自动执行)                            (手动输入)

ew:merge.execute 绑定:                ew:merge.execute 绑定:
  Tool: api: POST localhost:9090/merge  Tool: manual
  (API 调用)                            (手动输入)
```

### 7.2 规则

- **结果可见**：@bob 可以看到 @alice 的工具产出的消息（Content Object 在 Timeline 中）
- **工具不共享**：@bob 不能执行 @alice 本地的 CLI
- **契约一致**：§1-§4（Role / Flow / Commitment / Arena）对所有 peer 完全相同
- **只有 §5 不同**：每个 peer 维护自己的 `.app.md` 副本，§5 绑定可以不同

### 7.3 实现方式

每个 peer 在自己的 Room 副本中有自己的 `.app.md`：

```
@alice 的 workspace:
  rooms/my-project/contracts/ew.app.md  → §5 绑定 bash/api

@bob 的 workspace:
  rooms/my-project/contracts/ew.app.md  → §5 绑定 manual
```

在 SwSim 模拟环境（共享文件系统）中，两个 peer 使用同一份 `.app.md`——此时以 §5 中更通用的绑定（通常是 `manual`）为准，或者在 §5 中标注 peer-specific 绑定。

---

## 8. 三种接入场景详解

### 8.1 场景 A：CLI 二进制接入

**前提**：你有一个 EventWeaver CLI（`ew-cli`），支持子命令。

**绑定映射**：

| Socialware Action | CLI 命令 |
|-------------------|---------|
| `branch.create` | `./ew-cli branch create --name {name}` |
| `branch.activate` | `./ew-cli branch activate --id {branch_id}` |
| `merge.request` | `./ew-cli merge request --branch {branch_id} --target main` |
| `merge.execute` | `./ew-cli merge execute --request {merge_id}` |
| `branch.archive` | `./ew-cli branch archive --id {branch_id}` |

**§5 绑定**：

```markdown
### Action: branch_lifecycle.branch.create

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | bash: ./ew-cli branch create --name {name} --desc {description} |
| 输入 (Input) | name: 分支名, description: 分支描述 |
| 输出 (Output) | JSON: { branch_id, name, status, created_at } |
| 消息模板 (Message Template) | 🌿 @{author} 创建了分支: {name} |
```

**注意**：
- CLI 必须输出可解析的结果（JSON 或文本），用于生成 Content Object 的 body
- 如果 CLI 返回非零退出码，execute 阶段失败，不写入 Timeline
- CLI 路径可以是绝对路径或相对于 Room workspace 的路径

### 8.2 场景 B：MCP Server 接入

**前提**：你运行了一个 EventWeaver MCP Server，已在 Claude Code 中注册。

**绑定映射**：

| Socialware Action | MCP Tool |
|-------------------|---------|
| `branch.create` | `mcp: ew-server/create_branch` |
| `merge.request` | `mcp: ew-server/request_merge` |
| `merge.execute` | `mcp: ew-server/execute_merge` |

**§5 绑定**：

```markdown
### Action: branch_lifecycle.branch.create

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | mcp: ew-server/create_branch |
| 输入 (Input) | name: string, description: string |
| 输出 (Output) | { branch_id: string, name: string, status: string } |
| 消息模板 (Message Template) | 🌿 @{author} 创建了分支: {name} |
```

**MCP Server 注册**（在 Claude Code 配置中）：

```json
{
  "mcpServers": {
    "ew-server": {
      "command": "./ew-server",
      "args": ["--port", "3001"]
    }
  }
}
```

**优势**：
- MCP 提供结构化输入输出，不需要解析 stdout
- Claude Code 原生支持 MCP 调用
- 可与 AI Agent 工具链无缝集成

### 8.3 场景 C：HTTP API 接入

**前提**：你运行了一个 EventWeaver HTTP 服务（如 `localhost:9090`）。

**绑定映射**：

| Socialware Action | HTTP 端点 |
|-------------------|---------|
| `branch.create` | `POST /api/branches` |
| `merge.request` | `POST /api/merges` |
| `merge.execute` | `PUT /api/merges/{id}/execute` |

**§5 绑定**：

```markdown
### Action: branch_lifecycle.branch.create

| 属性 | 值 |
|------|-----|
| 工具 (Tool) | api: POST http://localhost:9090/api/branches |
| 输入 (Input) | JSON body: { "name": "{name}", "description": "{description}" } |
| 输出 (Output) | JSON response: { branch_id, name, status } |
| 消息模板 (Message Template) | 🌿 @{author} 创建了分支: {name} |
```

**注意**：
- API 需要在绑定时运行（或在 execute 时启动）
- 请求/响应以 JSON 格式处理
- 可调用本地或远程服务

---

## 9. 工具输出 → Content Object 映射

无论使用哪种工具类型，execute 阶段的工具输出都会被转换为 Content Object：

```
工具输出                              Content Object
────────                             ──────────────
bash stdout (JSON):                  body: { 解析后的 JSON }
bash stdout (文本):                  body: { "text": "原始文本" }
mcp 返回值:                          body: { MCP tool result }
api response body:                   body: { HTTP response JSON }
manual 用户输入:                      body: { "text": "用户输入内容" }
llm 生成文本:                        body: { "text": "LLM 输出" }
```

**规则**：
- JSON 输出 → 直接作为 body
- 非 JSON 输出 → 包装为 `{ "text": "..." }`
- 工具失败（非零退出码、HTTP 错误、MCP 异常）→ 不写入 Timeline，报错

---

## 10. 与现有 spec 的关系

| Spec | 本文的补充 |
|------|-----------|
| 002 (Contract) | 002 定义模板格式，本文说明开发者如何阅读模板 |
| 003 (App) | 003 定义 App 格式，本文说明 §5 如何填入真实工具 |
| 004 (Local Apps) | 004 定义工具类型和机制，本文提供具体接入流程和示例 |
| 005 (User Journey) | 005 是通用旅程，本文针对"有真实工具的开发者" |
| 006 (P2P) | 006 定义通信协议，本文说明非对称工具在 P2P 中的协作 |
