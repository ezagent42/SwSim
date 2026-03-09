# 004 — 本地外挂工具开发与使用

> **状态**：Draft v1
> **日期**：2026-03-09
> **作者**：Allen & Claude collaborative design

---

## 1. 概述

外挂工具（External Tools）是绑定到 Socialware Action 的本地执行器。工具在本地运行，只有结果（消息）通过 P2P 同步。

**核心原则**：Tool ≠ Contract。Tool = Side-effect。

契约定义「做什么」（状态转换），工具定义「怎么做」（具体执行）。同一个 Action 可以绑定不同的工具——就像 Git 不限制你用什么编辑器。

---

## 2. 工具类型

SwSim 支持五种工具类型：

### 2.1 `bash: {command}` — Shell 命令

直接执行本地 Shell 命令，捕获 stdout/stderr。

```markdown
| 工具 (Tool) | bash: python scripts/analyze.py --input {input_file} |
```

**特点**：
- 最灵活的工具类型
- 可调用任何本地安装的程序
- 输出捕获为 Content Object 的 body

**示例场景**：运行测试、编译代码、生成报告、调用 CLI 工具

### 2.2 `mcp: {server}/{tool}` — MCP Server 工具调用

调用 MCP (Model Context Protocol) server 提供的工具。

```markdown
| 工具 (Tool) | mcp: elfiee/analyze_code |
```

**特点**：
- 通过 MCP 协议调用
- 支持结构化输入输出
- 可与 AI Agent 工具链集成

**示例场景**：代码分析、文档生成、智能搜索

### 2.3 `api: {endpoint}` — HTTP API 调用

调用 HTTP API endpoint。

```markdown
| 工具 (Tool) | api: POST http://localhost:8080/review |
```

**特点**：
- 支持 RESTful API
- 可调用本地或远程服务
- 请求/响应以 JSON 格式处理

**示例场景**：调用外部服务、webhook 通知、第三方集成

### 2.4 `manual` — 手动输入

提示用户手动输入内容，无自动执行。

```markdown
| 工具 (Tool) | manual |
```

**特点**：
- 最简单的工具类型
- 依赖用户（人类或 AI）直接提供内容
- 适合需要主观判断的 Action

**示例场景**：审批意见、任务描述、自然语言反馈

### 2.5 `llm: {prompt_template}` — AI/LLM 调用

调用 LLM 生成内容，使用 prompt template。

```markdown
| 工具 (Tool) | llm: 根据以下代码变更生成 review 意见: {diff} |
```

**特点**：
- Prompt template 中用 `{variable}` 引用输入
- LLM 输出作为 Content Object 的 body
- 可与 Claude Code session 的 LLM 能力集成

**示例场景**：代码审查、文档摘要、智能建议

---

## 3. 非对称工具（Asymmetric Tools）

**不同 peer 可以有不同的工具绑定。**

这是 Socialware 的重要设计特性：工具是本地的，契约是共享的。

### 3.1 示例

```
@alice:local                         @bob:local
─────────────                        ────────────
ta:submit 绑定:                      ta:submit 绑定:
  Tool: mcp: elfiee/create_task        Tool: manual
  (Alice 有 elfiee MCP server)         (Bob 没有，手动输入)

ta:approve 绑定:                     ta:approve 绑定:
  Tool: llm: 自动审批...               Tool: manual
  (Alice 用 AI 辅助审批)               (Bob 人工审批)
```

### 3.2 规则

- **结果可见**：@bob 可以看到 @alice 的工具产出的消息和 artifacts
- **工具不可用**：@bob 不能执行 @alice 专有的 MCP 工具
- **契约一致**：状态转换规则对所有 peer 一致
- **类比**：就像 Git——你可以用 VS Code，我可以用 Vim，但 commit 格式是一致的

### 3.3 实现方式

每个 peer 维护自己的 `.app.md` 副本（或同一文件中标注 peer-specific 绑定）。契约部分（§1-§4）一致，绑定部分（§5）可以不同。

---

## 4. 工具在 Hook Pipeline 中的位置

工具**仅在 Phase 2: execute** 阶段运行：

```
Phase 1: pre_send (无工具参与)
├── Role Check        ← 纯契约逻辑
├── CBAC Check        ← 纯契约逻辑
├── Flow Check        ← 纯契约逻辑
└── Cross-NS Check    ← 纯契约逻辑

Phase 2: execute (工具在此运行)
├── 读取 §5 绑定的 Tool 配置
├── 执行 Tool (bash / mcp / api / manual / llm)
├── 捕获 Tool 输出
├── 生成 Content Object
└── 存储 Artifacts (如有)

Phase 3: after_write (无工具参与)
├── Append Ref to Timeline  ← 纯数据操作
├── Update State            ← 纯数据操作
└── Broadcast               ← 纯数据操作
```

**关键洞察**：工具执行被夹在契约检查（pre_send）和数据持久化（after_write）之间。即使工具失败，契约逻辑不受影响。工具是可替换的「执行器」。

---

## 5. Artifacts — 工具副产物

### 5.1 什么是 Artifacts

Artifacts 是 Tool 执行的副产物——文件、报告、代码补丁等。存储在 Room 的 `artifacts/` 目录。

```
workspace/rooms/{name}/artifacts/
├── task-001-spec.md           ← submit 工具生成的规格文档
├── task-001-review.md         ← approve 工具生成的审批意见
├── branch-feature-auth.patch  ← merge 工具生成的补丁
└── report-2026-03.pdf         ← 报告工具生成的 PDF
```

### 5.2 Artifacts 不是真相源

- **真相源是 Timeline**：Artifacts 只是便利存储
- **可重生成**：删除 artifacts → 重放 Timeline + 重新执行 Tool → artifacts 重建
- **不同步**：Artifacts 不通过 P2P 同步（只有 Timeline 同步）
- **引用方式**：Content Object 中通过 `artifacts` 字段引用路径

### 5.3 Artifact 命名约定

```
{instance_id}-{action}-{description}.{ext}
```

示例：`task-001-submit-spec.md`, `task-001-approve-review.md`

---

## 6. 开发自定义工具

### 6.1 MCP Server 工具

创建 MCP server，然后在 §5 中引用：

**步骤**：
1. 开发 MCP server（Python / TypeScript / Rust）
2. 在 Claude Code 配置中注册 MCP server
3. 在 §5 Context Bindings 中引用：`mcp: server_name/tool_name`

**示例**：

```python
# mcp_server/task_tools.py
from mcp import Server

server = Server("task_tools")

@server.tool("create_task")
async def create_task(title: str, description: str) -> dict:
    """创建任务并返回结构化结果"""
    return {
        "task_id": generate_id(),
        "title": title,
        "description": description,
        "created_at": now()
    }
```

在 §5 中绑定：

```markdown
| 工具 (Tool) | mcp: task_tools/create_task |
| 输入 (Input) | title: 任务标题, description: 任务描述 |
| 输出 (Output) | task_id, title, description, created_at |
```

### 6.2 Bash 脚本工具

编写脚本放在 `simulation/` 目录下，在 §5 中引用：

**步骤**：
1. 编写脚本（任何语言，需要可执行权限）
2. 在 §5 Context Bindings 中引用：`bash: ./scripts/my-tool.sh {args}`

**示例**：

```bash
#!/bin/bash
# simulation/scripts/run-tests.sh
# 执行项目测试并生成报告

cd "$1"
pytest --tb=short -q 2>&1 | tee "$2/test-report.txt"
echo "测试完成，报告已保存到 $2/test-report.txt"
```

在 §5 中绑定：

```markdown
| 工具 (Tool) | bash: ./scripts/run-tests.sh {project_path} {artifacts_dir} |
| 输入 (Input) | project_path: 项目路径, artifacts_dir: Artifact 输出目录 |
| 输出 (Output) | 测试结果摘要 + test-report.txt artifact |
```

### 6.3 LLM 工具

定义 prompt template，运行时注入上下文变量：

```markdown
| 工具 (Tool) | llm: 请审查以下代码变更并给出意见。变更内容:\n{diff}\n\n审查标准: 代码质量、安全性、可维护性。 |
| 输入 (Input) | diff: 代码变更的 diff 内容 |
| 输出 (Output) | 结构化的代码审查意见 |
```

---

## 7. 工具绑定最佳实践

### 7.1 一个 Action 一个工具

每个 Action 在 §5 中绑定**恰好一个**工具。如果需要组合多个操作，使用 bash 脚本或 MCP server 封装。

### 7.2 优先使用 manual

初始开发时，所有工具先绑定为 `manual`。验证契约逻辑正确后，逐步替换为自动化工具。这是 TDD 的思路——先验证协议，再加自动化。

### 7.3 工具与契约分离

工具实现不应包含业务逻辑（状态转换、权限检查）。这些逻辑由 Hook Pipeline 的 pre_send 阶段处理。工具只负责「执行」和「生成内容」。

### 7.4 幂等性

尽量让工具具备幂等性——重复执行应产生相同结果。这保证 Timeline 重放时的一致性。如果工具有外部副作用（如发送邮件），需要在重放时跳过。

---

## 8. 工具执行生命周期

```
用户输入: "提交任务：实现用户认证"
    │
    ▼
解析 Action: ta:task_lifecycle.submit
    │
    ▼
pre_send 检查:
├── Role Check: @alice 是否持有 R1? ✓
├── CBAC Check: any → 通过 ✓
├── Flow Check: _none_ → submit → submitted ✓
└── Cross-NS Check: 无依赖 ✓
    │
    ▼
execute (工具运行):
├── 读取 §5: Tool = manual
├── 执行: 提示用户输入任务详情
├── 用户输入: { title: "实现用户认证", desc: "JWT + OAuth2" }
├── 生成 Content Object → content/msg-001.json
└── 无 Artifact
    │
    ▼
after_write:
├── Append Ref → timeline/shard-001.jsonl
├── Update State: flow_states["msg-001"] = { flow: "ta:task_lifecycle", state: "submitted" }
├── Update Commitments: ta:C1 → active (deadline: 48h)
└── Broadcast: 通知 @bob 有新消息
```
