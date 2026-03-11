# ResPool 实施记录

> **日期**：2026-03-11
> **操作者**：admin@local
> **状态**：已完成（完整三阶段 + 安装）

---

## 概述

本文档记录 ResPool Socialware 从模板设计到安装就绪的完整实施过程，覆盖五个 Skill 阶段的所有操作步骤和产出文件。

ResPool 是一个**资源池管理 Socialware**，定义了 5 个角色和 3 条工作流：
- 资源生命周期（申请→创建→删除）
- 分配生命周期（分配→释放→结算/争议）
- 监控生命周期（初始化→持续报告）

核心工具绑定：人工角色（admin/user）使用 `manual`，自动化角色（creator/monitor/cleaner）使用 `bash: one ...` 调用 OneSystem CLI。

---

## Stage 0：Identity 创建

**操作**：为 5 个参与者创建全局 Identity 文件。

**产出**：

```
simulation/workspace/identities/
├── admin@local.json       { entity_id: "admin@local" }   ← 人类用户（用户名 admin，仅演示用）
└── user@local.json        { entity_id: "user@local" }    ← 人类用户（用户名 user，仅演示用）
```

**说明**：Agent session（R3/R4/R5）归属于真实用户，无独立 identity 文件：
- `admin:creator@local` → admin 的 agent session，identity 文件为 `admin@local.json`
- `user:monitor@local` → user 的 agent session，identity 文件为 `user@local.json`
- `admin:cleaner@local` → admin 的 agent session，identity 文件为 `admin@local.json`

**设计原则**：agent 必须依托明确的 user，不能独立存在。`username:session-name@namespace` 中 username 是归属用户，session-name 是 Claude Code session 名称。

---

## Stage 1：/room create respool-demo

**操作**：以 `admin@local` 为 owner 创建 Room。

**产出**：

```
simulation/workspace/rooms/respool-demo/
├── identities/admin@local.json
├── socialware-app/          （空，待安装）
├── timeline/shard-001.jsonl （空，待写入）
├── content/
├── artifacts/
├── config.json
└── state.json
```

**config.json 初始状态**：

```json
{
  "room_id": "room-respool-demo-001",
  "name": "Respool Demo",
  "created_by": "admin@local",
  "membership": {
    "policy": "invite",
    "members": { "admin@local": "owner" }
  },
  "socialware-app": { "installed": [], "roles": {} }
}
```

---

## Stage 2：/room join — 加入 4 个成员

**操作**：依次加入 user、creator、monitor、cleaner 四个成员。

```
/room join respool-demo user@local
/room join respool-demo admin:creator@local
/room join respool-demo user:monitor@local
/room join respool-demo admin:cleaner@local
```

**产出变更**：

- Room `identities/` 新增 4 个成员引用文件
- `config.json` membership.members 扩展为 5 人
- `state.json` peer_cursors 扩展为 5 人（均初始化为 0）

**最终成员列表**：

| Identity | 角色 |
|---|---|
| admin@local | owner（人类用户，用户名 admin 仅演示用） |
| user@local | member（人类用户，用户名 user 仅演示用） |
| admin:creator@local | member（admin 的 agent session，admin 负责） |
| user:monitor@local | member（user 的 agent session，user 负责） |
| admin:cleaner@local | member（admin 的 agent session，admin 负责） |

---

## Stage 3：/socialware-dev — 设计模板

**操作**：以 `admin@local` 为开发者，执行 `/socialware-dev` 设计 ResPool 组织图。

**设计决策**：

| 原语 | 决策 |
|---|---|
| §1 Roles | 5 个角色，职责分离：admin 管控，user 使用，creator/cleaner 操作资源，monitor 观察 |
| §2 Flows | 3 条流：resource_lifecycle（资源）、allocation_lifecycle（分配）、monitoring_lifecycle（监控） |
| §3 Commitments | C1：资源创建后 10min 内 monitor 需更新报告；C2：删除前需 user 确认 |
| §4 Arena | role_based，最小 2 人参与 |
| §5 | 全部 `_待实现_`（模板阶段） |

**Flow 详情**：

```
resource_lifecycle:
  _none_ → request(R2,any) → requested
  requested → resource.create(R3,any) → created
  requested → reject(R1,any) → rejected
  created → resource.delete(R5,author|role:R1) → deleted

allocation_lifecycle:
  _none_ → alloc.create(R3,any) → active
  active → alloc.release(R5,author|role:R1) → released
  released → alloc.settle(R1,any) → settled
  released → alloc.dispute(R2,author) → disputed

monitoring_lifecycle:
  _none_ → status.init(R4,any) → monitoring
  monitoring → status.report(R4,any) → monitoring（循环）
```

**产出**：`simulation/socialware/rp-respool.socialware.md`（只读，后续不再修改）

---

## Stage 4：/socialware-app-dev — 开发 App

**操作**：以 `admin@local` 为开发者，执行 `/socialware-app-dev`，基于 `rp-respool.socialware.md` 开发 App。

**App 命名**：
- AppName：`respool`
- DeveloperName：`admin`（identity username 部分）
- SocialwareName：`rp-respool`
- **App-ID**：`respool.admin.rp-respool`

**工具绑定决策**：

| 动作 | 角色 | 工具 | 说明 |
|---|---|---|---|
| request | R2 user | `manual` | 用户描述申请需求 |
| resource.create | R3 creator | `bash: one apply -f {yaml_file} -n {namespace}` | OneSystem CLI 创建资源 |
| reject | R1 admin | `manual` | 管理员手动填写驳回原因 |
| resource.delete | R5 cleaner | `bash: one delete {kind} {name}` | OneSystem CLI 删除资源 |
| alloc.create | R3 creator | `bash: one alloc create --resource {kind}/{name} ...` | OneSystem CLI 创建分配 |
| alloc.release | R5 cleaner | `bash: one alloc release {alloc_id} --reason {reason}` | OneSystem CLI 释放分配 |
| alloc.settle | R1 admin | `bash: one alloc settle {alloc_id}` | OneSystem CLI 结算 |
| alloc.dispute | R2 user | `bash: one alloc dispute {alloc_id} --reason {reason}` | OneSystem CLI 争议申请 |
| status.init | R4 monitor | `bash: one get "*" -o json` | OneSystem CLI 初始状态扫描 |
| status.report | R4 monitor | `bash: one get "*" -o json` | OneSystem CLI 周期性状态报告 |

**产出**：`simulation/app-store/respool.admin.rp-respool.app.md`（状态：已开发，§5 已填，§1 仍 `_待绑定_`）

---

## Stage 5：注册 App 到 registry.json

**操作**：

```bash
python .claude/skills/socialware-app-dev/scripts/register-app.py \
  --app-name "respool" \
  --developer "admin@local" \
  --socialware "rp-respool" \
  --description "资源池管理 App：资源申请/创建/分配/释放/结算全生命周期，绑定 OneSystem CLI"
```

**输出**：`respool.admin.rp-respool`

**registry.json 新增条目**：

```json
"respool.admin.rp-respool": {
  "app_id": "respool.admin.rp-respool",
  "socialware": "rp-respool",
  "developer": "admin@local",
  "created_at": "2026-03-11T07:41:00Z",
  "app_file": "respool.admin.rp-respool.app.md",
  "description": "资源池管理 App：资源申请/创建/分配/释放/结算全生命周期，绑定 OneSystem CLI"
}
```

**注意**：`python3` 在本环境中不可用，使用 `python` 命令。

---

## Stage 6：/socialware-app-install — 安装到 respool-demo

**操作**：以 `admin@local` 为安装者，执行 `/socialware-app-install`。

**安装参数**：
- App：`respool.admin.rp-respool`（来源：app-store/registry.json）
- Room：`respool-demo`
- Namespace：`rp`
- 角色绑定：

| R-ID | 角色名 | 绑定 Identity |
|---|---|---|
| R1 | admin | admin@local（人类用户） |
| R2 | user | user@local（人类用户） |
| R3 | creator | admin:creator@local（admin 的 agent session） |
| R4 | monitor | user:monitor@local（user 的 agent session） |
| R5 | cleaner | admin:cleaner@local（admin 的 agent session） |

**产出**：

```
simulation/workspace/rooms/respool-demo/
└── socialware-app/
    └── respool.admin.rp-respool.app.md   ← 已安装副本
        状态: 已安装
        Namespace: rp
        §1 Holder 已填入具体 Identity
        §6 模拟环境已添加
```

**config.json 更新**：

```json
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
```

**state.json 更新**：

```json
{
  "role_map": {
    "rp:R1": "admin@local",
    "rp:R2": "user@local",
    "rp:R3": "admin:creator@local",
    "rp:R4": "user:monitor@local",
    "rp:R5": "admin:cleaner@local"
  },
  "commitments": {
    "rp:C1": { "status": "inactive" },
    "rp:C2": { "status": "inactive" }
  },
  "last_clock": 0,
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

## 产物清单

实施完成后的完整文件树：

```
simulation/
├── socialware/
│   └── rp-respool.socialware.md              ✅ 模板（只读）
│
├── app-store/
│   ├── registry.json                          ✅ 已注册
│   └── respool.admin.rp-respool.app.md        ✅ 已开发（§5 已填）
│
└── workspace/
    ├── identities/
    │   ├── admin@local.json                   ✅  （含 admin:creator、admin:cleaner 两个 agent session）
    │   └── user@local.json                    ✅  （含 user:monitor agent session）
    └── rooms/
        └── respool-demo/
            ├── config.json                    ✅ App 已注册，角色已映射
            ├── state.json                     ✅ role_map + commitments 初始化
            ├── identities/（5 个成员引用）    ✅
            ├── socialware-app/
            │   └── respool.admin.rp-respool.app.md  ✅ 已安装（§1 已绑定）
            ├── timeline/shard-001.jsonl       ✅ 空，待写入
            ├── content/                       ✅ 空，待写入
            └── artifacts/                    ✅ 空，待写入
```

---

## 验收检查

| 检查项 | 状态 | 说明 |
|---|---|---|
| `rp-respool.socialware.md` 存在 | ✅ | §5 全部 `_待实现_`，§1 全部 `_待绑定_` |
| `respool.admin.rp-respool.app.md` 存在于 app-store | ✅ | §5 已填工具，§1 仍 `_待绑定_` |
| registry.json 有注册条目 | ✅ | app_id = `respool.admin.rp-respool` |
| 已安装副本存在于 Room | ✅ | §1 Holder 已填入具体 Identity |
| §6 模拟环境已添加 | ✅ | workspace 路径正确 |
| config.json `socialware-app.installed` 正确 | ✅ | 对象数组，含 app_id/namespace/contract/template |
| state.json `role_map` 正确 | ✅ | 5 条 `rp:Rx` → identity 映射 |
| state.json `commitments` 初始化 | ✅ | rp:C1 和 rp:C2 均为 inactive |
| 模板文件未被修改 | ✅ | socialware/ 下的模板保持只读状态 |

---

## 下一步：运行验证

App 已就绪，执行以下步骤验证运行时：

```
/socialware-app
Room: respool-demo
Identity: user@local
```

**建议验证路径（Phase 1 — 全 manual 模式）**：

```
1. user@local                  → rp:request（申请一个 GPU 资源）
   预期：pre_send 通过（R2✓，any✓，_none_→request✓）
         after_write：Timeline 追加 msg-001(clock:1)，flow_states 更新为 requested

2. admin:creator@local  → rp:resource.create（bash: one apply 创建资源）
   预期：pre_send 通过（R3✓，any✓，requested→resource.create✓）
         execute：调用 one apply 命令
         after_write：Timeline 追加 msg-002(clock:2)，flow_states 更新为 created
         Commitment C1 激活（10min 内 monitor 需报告）

3. user:monitor@local       → rp:status.init（bash: one get "*"）
   预期：C1 fulfilled（在时限内执行了 status.report）

4. admin:creator@local  → rp:alloc.create（bash: one alloc create）
   预期：分配创建成功，allocation_lifecycle 进入 active

5. admin:cleaner@local      → rp:alloc.release（bash: one alloc release）
   预期：C2 触发（操作前验证 user 已知晓）

6. admin@local                 → rp:alloc.settle
   预期：allocation_lifecycle 进入 settled，结算完成
```

**注意**：Phase 1 建议先将所有 §5 工具替换为 `manual` 验证 Flow 逻辑，确认后再替换为 `bash: one ...` 进行 Phase 2 真实工具集成。

---

## 参考文档

| 文档 | 说明 |
|---|---|
| [respool-integration.md](respool-integration.md) | ResPool 接入设计（四原语 + §5 工具绑定详情） |
| [swsim-v2-arch.md](swsim-v2-arch.md) | SwSim v2 架构（目录结构、命名规范） |
| [spec/007-developer-integration.md](spec/007-developer-integration.md) | CLI 工具接入指南 |
| [testcase/TC-013-end-to-end.md](testcase/TC-013-end-to-end.md) | 端到端验证参考 |
