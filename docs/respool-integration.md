# ResPool → SwSim 接入设计文档

> **状态**：Draft v3（已对照实际 SwSim 实现修订）
> **日期**：2026-03-10
> **作者**：Allen & Claude collaborative design
> **来源**：基于 ezagent/socialware/respool 的迁移分析（ezagent 项目已暂停）
> **依赖**：与 [swsim-v2-arch.md](swsim-v2-arch.md) 保持同步

---

## 1. 概述

ResPool 是一个**资源池管理 Socialware**，原先在 ezagent 平台上以 `manifest.toml` + Agent 孵化器模式运行。

本文档定义如何将 ResPool 的**组织语义**（角色、工作流、承诺）迁移到 SwSim 的四原语模型，并以 `one` CLI（OneSystem）作为工具绑定，实现完整的资源生命周期管理。

### 1.1 核心判断

**ResPool 恰好是 spec 007（developer-integration）的典型场景**：

> "你有一个真实 CLI 工具 → 绑定为 `bash: one {command} {args}`"

迁移走标准三阶段流程：`/socialware-dev → /socialware-app-dev → /socialware-app-install`，再用 `/socialware-app` 验证。

### 1.2 丢弃的 ezagent 专有内容

以下内容属于 ezagent 平台层，在 SwSim 中**不需要迁移**：

| 内容 | 原因 |
|---|---|
| `manifest.toml` 格式 | 被 `.socialware.md` 四原语格式完全替代 |
| `agent_templates` / `auto_spawn` | ezagent Agent 孵化器机制，SwSim 无对应概念 |
| `max_concurrent` | ezagent 并发配置，SwSim 不需要 |
| `config.toml`（adapter/lifecycle/sandbox） | ezagent 运行时配置 |
| `EXT-04/06/09/15/17` | ezagent 扩展系统 |
| `event-weaver` 依赖 | ResPool 自洽，暂不依赖跨 namespace |

### 1.3 soul.md 的处理

原 Agent soul.md（creator/monitor/cleaner 的行为定义）**不是 `llm:` 工具，而是参考文档**：

- soul.md 描述"理解意图、执行 CLI" → 在 SwSim 中直接绑定 `bash: one ...`，真正执行
- soul.md 描述"格式化报告" → 绑定 `bash: one get ... -o json`，捕获输出
- 渐进策略：先全部绑定 `manual` 验证流程，再替换为 `bash: one ...`

---

## 2. 四原语设计

> 本节内容用于 `/socialware-dev` 阶段生成 `.socialware.md` 模板。
> - **Holder** 字段：`_待绑定_`（/socialware-app-install 阶段填入具体用户）
> - **Tool** 字段（§5）：`_待实现_`（/socialware-app-dev 阶段填入具体工具）

### 2.1 §1 Roles

| ID | 名称 | Capabilities | Holder |
|----|------|-------------|--------|
| R1 | admin | cleanup, role_grant, role_revoke | _待绑定_ |
| R2 | user | request, status | _待绑定_ |
| R3 | creator | resource.create, alloc.create | _待绑定_ |
| R4 | monitor | status.report | _待绑定_ |
| R5 | cleaner | resource.delete, alloc.release | _待绑定_ |

**角色对应**：

| SwSim Role | 原 ezagent | 持有者 | 操作者类型 |
|---|---|---|---|
| R1 admin | `rp:admin` | `admin@local`（人类用户，用户名 admin 仅演示用） | 人工（manual） |
| R2 user | `rp:user` | `user@local`（人类用户，用户名 user 仅演示用） | 人工（manual） |
| R3 creator | `rp:creator` + respool-creator Agent | `admin:creator@local`（admin 的 agent session） | CLI 执行（bash: one apply） |
| R4 monitor | `rp:monitor` + respool-monitor Agent | `user:monitor@local`（user 的 agent session） | CLI 查询（bash: one get） |
| R5 cleaner | `rp:cleaner` + respool-cleaner Agent | `admin:cleaner@local`（admin 的 agent session） | CLI 执行（bash: one delete/alloc release） |

> **设计原则**：agent session 必须归属明确的 user（`username:session-name@namespace`），不能作为独立账号存在。admin 负责资源创建和清理（R3/R5），user 负责资源监控（R4）。实际部署中 admin/user 应替换为真实用户名（如 alice/bob）。

### 2.2 §2 Flows

#### Flow: resource_lifecycle

资源从申请到删除的生命周期。

| Current State | Action | Next State | Required Role | CBAC |
|---|---|---|---|---|
| _none_ | request | requested | R2 | any |
| requested | resource.create | created | R3 | any |
| requested | reject | rejected | R1 | any |
| created | resource.delete | deleted | R5 | author \| role:R1 |

#### Flow: allocation_lifecycle

资源分配从创建到结算的生命周期。

| Current State | Action | Next State | Required Role | CBAC |
|---|---|---|---|---|
| _none_ | alloc.create | active | R3 | any |
| active | alloc.release | released | R5 | author \| role:R1 |
| released | alloc.settle | settled | R1 | any |
| released | alloc.dispute | disputed | R2 | author |

### 2.3 §3 Commitments

| ID | 当事方 | 义务 | 触发条件 | 截止时间 |
|----|--------|------|---------|---------|
| C1 | R3 → R4 | creator 创建资源后，monitor 更新状态报告 | resource_lifecycle.created | 触发后 10min |
| C2 | R5 → R2 | cleaner 删除资源前，须通知 user 确认 | resource_lifecycle.created | 操作前 |

### 2.4 §4 Arena

| 属性 | 值 |
|---|---|
| 准入策略 | role_based |
| 准入条件 | 必须被分配 R1/R2/R3/R4/R5 任一角色 |

---

## 3. Context Bindings 设计（§5）

> 本节内容用于 `/socialware-app-dev` 阶段填入 `.app.md`。
> 模板中所有 Tool 字段为 `_待实现_`，以下是推荐的实现绑定。
> §5 格式采用子标题 + 项目列表风格（与 spec 003 一致）。

### 工具选型原则

| 角色 | 操作者 | 推荐工具类型 |
|---|---|---|
| R1 admin、R2 user | 人工操作 | `manual` |
| R3 creator | 执行 OneSystem 资源创建 | `bash: one apply ...` |
| R4 monitor | 查询 OneSystem 资源状态 | `bash: one get ...` |
| R5 cleaner | 执行删除/释放 | `bash: one delete ...` / `bash: one alloc release ...` |

### on: request（R2 执行）

- 工具: manual
- 输入: 资源类型 + 规格描述（自然语言）
- 输出: 申请描述文本
- 消息模板: "📥 @{author} 申请资源: {description}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: resource.create（R3 执行）

- 工具: bash: one apply -f {yaml_file} -n {namespace}
- 输入: yaml_file: 资源 YAML 文件路径, namespace: 目标 NS
- 输出: JSON: { name, kind, hostname, status }
- 消息模板: "✅ @{author} 已创建资源: {name}（{kind}）"
- 依赖: rp:resource_lifecycle.requested
- 委托: _无_
- 资源: _无_

### on: reject（R1 执行）

- 工具: manual
- 输入: 驳回原因
- 输出: 驳回通知
- 消息模板: "❌ @{author} 驳回申请: {reason}"
- 依赖: rp:resource_lifecycle.requested
- 委托: _无_
- 资源: _无_

### on: resource.delete（R5 执行）

- 工具: bash: one delete {kind} {name}
- 输入: kind: 资源类型, name: 资源名
- 输出: 删除确认
- 消息模板: "🗑️ @{author} 已删除资源: {name}"
- 依赖: rp:resource_lifecycle.created
- 委托: _无_
- 资源: _无_

### on: alloc.create（R3 执行）

- 工具: bash: one alloc create --resource {kind}/{name} --amount {amount} --unit {unit} --consumer {consumer} --duration {duration}
- 输入: kind, name, amount, unit, consumer, duration
- 输出: JSON: { alloc_id, phase, amount, lease }
- 消息模板: "📌 @{author} 创建分配: {alloc_id}（{amount} {unit}，消费者: {consumer}）"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.release（R5 执行）

- 工具: bash: one alloc release {alloc_id} --reason {reason}
- 输入: alloc_id: 分配 ID, reason: completed | cancelled | timeout | exhausted
- 输出: 释放确认 + invoice_amount
- 消息模板: "🔓 @{author} 释放分配: {alloc_id}，原因: {reason}"
- 依赖: rp:allocation_lifecycle.active
- 委托: _无_
- 资源: _无_

### on: alloc.settle（R1 执行）

- 工具: bash: one alloc settle {alloc_id}
- 输入: alloc_id: 分配 ID
- 输出: 结算确认
- 消息模板: "💰 @{author} 完成结算: {alloc_id}"
- 依赖: rp:allocation_lifecycle.released
- 委托: _无_
- 资源: _无_

### on: alloc.dispute（R2 执行）

- 工具: bash: one alloc dispute {alloc_id} --reason {reason}
- 输入: alloc_id, reason
- 输出: 争议申请确认
- 消息模板: "⚠️ @{author} 对 {alloc_id} 提出争议: {reason}"
- 依赖: rp:allocation_lifecycle.released
- 委托: _无_
- 资源: _无_

### on: status（R4 执行，对应 monitor soul.md）

- 工具: bash: one get "*" -o json
- 输入: _无_
- 输出: 所有资源列表 JSON
- 消息模板: "📊 @{author} 资源状态报告（{total} 个资源）"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

---

## 4. 接入流程（三阶段）

### Step 1：定义模板（/socialware-dev）

```
/socialware-dev
```

描述："设计一个资源池管理 Socialware，5 个角色（admin/user/creator/monitor/cleaner），
两个工作流（resource_lifecycle 资源生命周期，allocation_lifecycle 分配生命周期）"

参考第 2 节的四原语设计完成 Q&A，产出：

```
simulation/socialware/rp-respool.socialware.md
```

此文件只读，Holder 全为 `_待绑定_`，Tool（§5）全为 `_待实现_`。

### Step 2：开发 App（/socialware-app-dev）

```
/socialware-app-dev
```

- 输入模板：`rp-respool.socialware.md`（从 `simulation/socialware/` 选择）
- App ID：`respool.alice.rp-respool`
  - AppName = `respool`（功能描述）
  - DeveloperName = `alice`（开发者用户名）
  - SocialwareName = `rp-respool`（模板名）
- 工具绑定：参考第 3 节（初期可全部 `manual`，验证流程后替换为 `bash: one ...`）

产出：

```
simulation/app-store/respool.admin.rp-respool.app.md   ← 已开发，§5 已填入
simulation/app-store/registry.json                      ← 新增注册条目
```

此文件工具已绑定，Holder 仍为 `_待绑定_`，可分发给不同 Room 各自安装。

### Step 3：安装部署（/socialware-app-install）

```
/socialware-app-install
```

- 来源 App：从 `simulation/app-store/registry.json` 查询选择 `respool.admin.rp-respool`
- 目标 Room：`respool-demo`（需先用 `/room create respool-demo` 创建）
- Namespace：`rp`
- 用户绑定：
  - R1 → `admin@local`（人类用户）
  - R2 → `user@local`（人类用户）
  - R3 → `admin:creator@local`（admin 用户的 agent session，admin 负责）
  - R4 → `user:monitor@local`（user 用户的 agent session，user 负责）
  - R5 → `admin:cleaner@local`（admin 用户的 agent session，admin 负责）

产出：

```
simulation/workspace/rooms/respool-demo/
  socialware-app/
    respool.admin.rp-respool.app.md    ← 已安装副本（§1 Holder 已填入具体 Identity）
  config.json    ← 更新：注册 App + 角色映射
  state.json     ← 更新：初始化 role_map + commitments
```

### Step 4：运行验证（/socialware-app）

```
/socialware-app
Room: respool-demo
Identity: user@local
```

验证路径：

```
user@local                 → rp:request（申请资源）
admin:creator@local → rp:resource.create（bash: one apply 创建资源）
admin:creator@local → rp:alloc.create（bash: one alloc create）
admin:cleaner@local     → rp:alloc.release（bash: one alloc release）
admin@local                → rp:alloc.settle
```

---

## 5. OneSystem CLI 前置条件

运行 `bash: one ...` 工具前，需确认 OneSystem 环境就绪：

```bash
# 检查 one CLI 是否安装
one --version

# 设置 context（如未配置）
one config set-context default \
  --server https://api.h2os.cloud \
  --oneauth-url https://one-auth.h2os.cloud

# 登录
one login -u {username} -p {password}

# 验证
one whoami
```

CLI 参考：`.claude/skills/skills/onesystem/onesystem-cli.md`

---

## 6. 渐进式接入建议

参考 spec 007 推荐的接入策略：

```
Phase 1: /socialware-app-dev 阶段全部绑定 manual
  → 验证 Flow 状态机逻辑正确
  → 验证角色权限（CBAC）
  → 验证 Timeline + State 数据格式
  → 对应测试：TC-004, TC-005, TC-006

Phase 2: 替换核心操作为 bash: one ...
  → resource.create → bash: one apply
  → alloc.create    → bash: one alloc create
  → alloc.release   → bash: one alloc release
  → 验证工具输出正确映射为 Content Object

Phase 3: 完整自动化
  → status          → bash: one get "*"
  → resource.delete → bash: one delete
  → alloc.settle    → bash: one alloc settle
  → 多会话 P2P 验证（TC-008）
```

---

## 7. 产物清单

接入完成后的文件树（对应实际 SwSim 目录结构）：

```
simulation/
├── socialware/
│   └── rp-respool.socialware.md              ← /socialware-dev 产物（只读模板）
│
├── app-store/
│   ├── respool.admin.rp-respool.app.md        ← /socialware-app-dev 产物（已开发）
│   └── registry.json                          ← App 注册表
│
└── workspace/
    ├── identities/
    │   ├── admin@local.json            （人类用户）
    │   ├── user@local.json             （人类用户）
    │   （agent sessions 归属于 admin/user，无独立 identity 文件）
    │   （admin:creator@local、admin:cleaner@local → admin@local.json）
    │   （user:monitor@local → user@local.json）
    └── rooms/
        └── respool-demo/
            ├── config.json                    ← 注册 App + 角色映射
            ├── state.json                     ← 初始空状态
            ├── socialware-app/
            │   └── respool.admin.rp-respool.app.md  ← /socialware-app-install 产物（已安装）
            ├── timeline/                      ← append-only JSONL
            ├── content/                       ← Content Objects
            └── artifacts/                    ← bash 工具副产物（one 命令输出等）
```

config.json 结构：

```json
{
  "membership": {
    "policy": "invite",
    "members": {
      "admin@local": "owner",
      "user@local": "member",
      "admin:creator@local": "member",
      "user:monitor@local": "member",
      "admin:cleaner@local": "member"
    }
  },
  "socialware-app": {
    "installed": [
      {
        "app_id": "respool.admin.rp-respool",
        "namespace": "rp",
        "contract": "respool.admin.rp-respool.app.md",
        "template": "rp-respool.socialware.md"
      }
    ],
    "roles": {
      "rp:R1": "admin@local",
      "rp:R2": "user@local",
      "rp:R3": "admin:creator@local",
      "rp:R4": "user:monitor@local",
      "rp:R5": "admin:cleaner@local"
    }
  }
}
```

state.json 初始结构：

```json
{
  "last_clock": 0,
  "role_map": {
    "rp:R1": "admin@local",
    "rp:R2": "user@local",
    "rp:R3": "admin:creator@local",
    "rp:R4": "user:monitor@local",
    "rp:R5": "admin:cleaner@local"
  },
  "flow_states": {},
  "commitments": {
    "rp:C1": { "status": "inactive" },
    "rp:C2": { "status": "inactive" }
  },
  "peer_cursors": {
    "admin@local": 0,
    "user@local": 0,
    "admin:creator@local": 0,
    "user:monitor@local": 0,
    "admin:cleaner@local": 0
  }
}
```

---

## 8. 参考

| 文档 | 说明 |
|---|---|
| [swsim-v2-arch.md](swsim-v2-arch.md) | SwSim v2 架构改进（本文所依赖的改进方案） |
| [spec/001-architecture.md](spec/001-architecture.md) | SwSim 整体架构 |
| [spec/002-socialware-contract.md](spec/002-socialware-contract.md) | `.socialware.md` 格式规范 |
| [spec/003-socialware-app-contract.md](spec/003-socialware-app-contract.md) | `.app.md` 格式规范 + config.json schema |
| [spec/004-local-apps.md](spec/004-local-apps.md) | 5 种工具类型详解 |
| [spec/007-developer-integration.md](spec/007-developer-integration.md) | CLI 工具接入指南（本文核心参考） |
| [testcase/TC-013-end-to-end.md](testcase/TC-013-end-to-end.md) | 端到端验证模板（可直接复用） |
| [../.claude/skills/skills/onesystem/onesystem-cli.md](../.claude/skills/skills/onesystem/onesystem-cli.md) | OneSystem CLI 完整参考手册 |
| [../.claude/skills/skills/onesystem/SKILL.md](../.claude/skills/skills/onesystem/SKILL.md) | OneSystem 平台职能与 API 参考 |
