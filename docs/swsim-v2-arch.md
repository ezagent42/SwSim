# SwSim v2 架构改进实施方案

> **状态**：Draft v2（已对照实际更新结果修订）
> **日期**：2026-03-10
> **作者**：Allen & Claude collaborative design
> **背景**：基于 ResPool 接入分析过程中识别出的架构问题，整合采纳的改进方案
> **修订说明**：v1 为规划版本，v2 对照用户实际更新的 spec/testcase 文件修正了各项细节

---

## 概览

本文档定义六项架构改进，整体围绕一个核心目标：

**将"定义组织"、"实现能力"、"部署使用"三件事明确分离。**

```
现状（两阶段）                    目标（三阶段，已实施）
──────────────                   ──────────────
/socialware-dev                  /socialware-dev    → simulation/socialware/
  └── .socialware.md (模板)

/socialware-app-dev              /socialware-app-dev    → simulation/app-store/
  └── .app.md (绑角色+绑工具)
                                 /socialware-app-install → workspace/rooms/{room}/socialware-app/
```

> **注意**：v1 规划中使用 `/define`/`/dev`/`/install`/`/run` 等简短命令名，
> 实际实施保留了原有命令名，并新增 `/socialware-app-install` 分离安装阶段。

---

## 改进一：三阶段拆分（核心）

### 当前问题

`/socialware-app-dev` 同时做了两件性质不同的事：
1. 为每个 Action 绑定工具（能力实现，属于"产品"层）
2. 为每个 Role 绑定具体用户、指定 Room（部署配置，属于"实例"层）

这导致同一份 App 无法在不同 Room/不同用户组合下复用。

### 目标：三个独立阶段（已实施）

| 阶段 | 命令 | 产物 | 产物位置 | 内容 |
|---|---|---|---|---|
| 定义 | `/socialware-dev` | `.socialware.md` | `simulation/socialware/` | 纯组织图，工具全 `_待实现_` |
| 开发 | `/socialware-app-dev` | `.app.md`（已开发） | `simulation/app-store/` | 工具绑定 + 注册到 registry.json，用户仍 `_待绑定_` |
| 安装 | `/socialware-app-install` | `.app.md`（已安装） | `workspace/rooms/{room}/socialware-app/` | 用户绑定 + Room 绑定 |

### 三个阶段的产物关系

```
simulation/socialware/
  rp-respool.socialware.md      ← /socialware-dev 产物，只读模板

simulation/app-store/
  respool.alice.rp-respool.app.md    ← /socialware-app-dev 产物，工具已绑定，用户 _待绑定_
  registry.json                       ← App 注册表

simulation/workspace/rooms/respool-demo/
  socialware-app/
    respool.alice.rp-respool.app.md  ← /socialware-app-install 产物，已安装副本（含用户绑定）
  state.json
  config.json
  timeline/
```

### `_待实现_` 替代 `_待绑定_`（已实施）

模板 `.socialware.md` 中所有工具字段改用 `_待实现_`（而非 `_待绑定_`）：

```markdown
- 工具: _待实现_
```

语义区分：
- `_待实现_`：该能力的具体实现方式尚未决定（/socialware-app-dev 阶段填入）
- `_待绑定_`：保留用于"用户/角色持有者"字段（/socialware-app-install 阶段填入）

---

## 改进二：App ID 体系

### 当前问题

App 用 namespace 缩写标识（如 `rp`、`ta`），缺乏溯源信息，无法追溯来自哪个模板、由谁开发。

### 目标：结构化 ID（已实施）

| 层级 | ID / 文件名格式 | 示例 |
|---|---|---|
| 模板 | `{descriptive-name}.socialware.md` | `rp-respool.socialware.md` |
| App 定义（已开发） | `{AppName}.{DeveloperName}.{SocialwareName}.app.md` | `respool.alice.rp-respool.app.md` |
| App 实例（已安装） | 同上，放入 `socialware-app/` 目录 | `socialware-app/respool.alice.rp-respool.app.md` |

App ID 格式：`{AppName}.{DeveloperName}.{SocialwareName}`（不含 `.app.md` 扩展名）

### config.json 更新（已实施）

`socialware-app.installed` 为对象数组，包含完整元数据：

```json
{
  "socialware-app": {
    "installed": [
      {
        "app_id": "respool.alice.rp-respool",
        "namespace": "rp",
        "contract": "respool.alice.rp-respool.app.md",
        "template": "rp-respool.socialware.md"
      }
    ]
  }
}
```

state.json 中角色映射：

```json
{
  "role_map": {
    "rp:R1": "admin:Admin@local",
    "rp:R2": "user:User@local",
    "rp:R3": "creator:Creator@local"
  }
}
```

> **注意**：v1 规划中 config.json key 为 `socialware`，实际实施改为 `socialware-app`。
> v1 规划 installed 为字符串数组，实际为对象数组。

---

## 改进三：用户名格式（已实施，与规划有差异）

### v1 规划格式

```
alice@local
bob@org.h2os.cloud
```

### 实际实施格式

```
alice:Alice@local
bob:Bob@local
```

格式：`{username}:{nickname}@{domain}`

- `username`：机器标识（小写，用于文件路径、config.json key）
- `nickname`：显示名称（首字母大写，用于界面展示）
- `domain`：节点域（本地用 `local`）

> **与 v1 差异**：实际格式增加了 `:{nickname}` 部分，与 email 格式有所不同。
> 与 Socialware namespace 的 `:` 分隔符共用，但语境不同：
> - `rp:R1` = namespace:RoleID
> - `alice:Alice@local` = username:nickname@domain

### 影响范围

| 文件/字段 | 格式 |
|---|---|
| Identity 文件名 | `alice:Alice@local.json` |
| config.json `members` key | `"alice:Alice@local": "member"` |
| state.json `role_map` value | `"alice:Alice@local"` |
| state.json `peer_cursors` key | `"alice:Alice@local"` |
| Timeline Ref `author` 字段 | `"alice:Alice@local"` |
| `.app.md` §1 Holder | `"alice:Alice@local"` |

---

## 改进四：Commitment 具体化要求

### 当前问题

`/socialware-dev` 引导时，截止时间字段允许模糊描述（如"及时"、"尽快"），导致 Commitment 无法被运行时追踪。

### 目标：强制具体时限

§3 Commitments 的截止时间字段**必须**是以下格式之一：

| 格式 | 示例 | 含义 |
|---|---|---|
| 相对时长 | `触发后 24h` | 触发后 N 小时/分钟 |
| 相对天数 | `触发后 3d` | 触发后 N 天 |
| ongoing | `ongoing` | 持续性义务，无截止 |
| 操作前 | `操作前` | 执行某动作之前必须满足 |

**不接受**：`及时`、`尽快`、`适时`等模糊描述。

### `/socialware-dev` Skill 引导改动

§3 引导问题：

> 截止时间（必须具体）：请用「触发后 Nh/Nd」、「ongoing」或「操作前」描述。例如：「触发后 48h」表示提交后 48 小时内必须审批。不接受「及时」等模糊描述。

---

## 改进五：PrePrompt Hook（替代 watch.sh）

### 当前问题

新消息通知依赖外部 `watch-timeline.sh` 脚本，需要单独终端窗口，体验割裂。

### 目标：运行时内置 peer_cursor 检查

在 `/socialware-app` 运行时中，每次用户输入前自动检查新消息。

### Hook Pipeline 扩展

在现有三阶段前增加 `pre_prompt` 阶段：

```
用户输入
  │
  ▼
┌─────────────────────────────────────┐
│  Phase 0: pre_prompt（新增）         │
│                                     │
│  读取 state.json → peer_cursors[me] │
│  扫描 timeline：clock > cursor       │
│  若有新消息 → 展示收件箱摘要          │
│  更新 peer_cursors[me] = last_clock │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Phase 1: pre_send（原有）           │
│  ...                                │
```

完整 Pipeline：`pre_prompt → pre_send → execute → after_write`

### 收件箱摘要格式

```
📬 2 条新消息（自 clock=3 以来）:
  [clock:4] alice:Alice@local → rp:resource.create  ✅ 已创建资源: gpu-01
  [clock:5] bob:Bob@local     → rp:alloc.create     📌 创建分配: alloc-001
────────────────────────────────────────
```

`watch-timeline.sh` 降级为可选工具（用于无交互的后台监控场景），不再是主要通知机制。

---

## 改进六：目录结构调整（已实施，与规划有差异）

### 新目录结构（实际）

```
simulation/
├── socialware/         ← /socialware-dev 产物：.socialware.md 模板库（只读）
│   └── rp-respool.socialware.md
│
├── app-store/          ← /socialware-app-dev 产物：.app.md App 定义库
│   ├── respool.alice.rp-respool.app.md
│   └── registry.json   ← App 注册表
│
└── workspace/          ← 运行时数据
    ├── identities/     ← Identity 文件
    │   ├── admin:Admin@local.json
    │   └── user:User@local.json
    └── rooms/
        └── respool-demo/
            ├── config.json
            ├── state.json
            ├── socialware-app/       ← App 已安装副本（/socialware-app-install）
            │   └── respool.alice.rp-respool.app.md
            ├── timeline/
            ├── content/
            └── artifacts/
```

> **与 v1 差异**：
> - `contracts/` → `socialware/`（更语义化）
> - `apps/` → `socialware-app/`（与 Skill 名称一致）
> - 不使用 `@room` 后缀区分实例，而是用目录位置区分（app-store vs socialware-app/）

### CLAUDE.md 对应更新

```markdown
## Directory Structure

- `simulation/socialware/`   — Socialware 模板（`.socialware.md`，只读）
- `simulation/app-store/`   — App 定义（`.app.md`，工具已绑，用户待绑）+ registry.json
- `simulation/workspace/`   — 运行时数据（identities, rooms）
- `docs/`                   — 规范文档
- `.claude/skills/`         — 四个 Skills（socialware-dev, socialware-app-dev, socialware-app-install, socialware-app）
```

---

## 计划 vs 实际 对照表

| 方面 | v1 规划 | 实际实施 |
|---|---|---|
| 身份格式 | `alice@local` | `alice:Alice@local`（增加 nickname） |
| 模板目录 | `simulation/contracts/` | `simulation/socialware/` |
| Room App 目录 | `rooms/{room}/apps/` | `rooms/{room}/socialware-app/` |
| 定义命令 | `/define` | `/socialware-dev`（保持原名） |
| 开发命令 | `/dev` | `/socialware-app-dev`（保持原名） |
| 安装命令 | `/install` | `/socialware-app-install`（新增） |
| 运行命令 | `/run` | `/socialware-app`（保持原名） |
| config.json key | `socialware.installed` | `socialware-app.installed` |
| installed 值类型 | 字符串数组 | 对象数组 `{app_id, namespace, contract, template}` |
| App 实例标识 | `app-id@room`（文件名后缀） | 目录位置（`socialware-app/`）区分 |
| §5 格式 | 6 列表格 | 子标题 + 项目列表（`### on: {action}` + `- 工具:` 等） |

---

## 实施状态

| 改进 | 状态 | 说明 |
|---|---|---|
| 改进一：三阶段拆分 | ✅ 已实施 | spec/testcase 已更新 |
| 改进二：App ID 体系 | ✅ 已实施 | 格式已定，见 TC-013 |
| 改进三：用户名格式 | ✅ 已实施（有偏差） | 实际为 `username:nickname@domain` |
| 改进四：Commitment 具体化 | 📋 待实施 | /socialware-dev Skill 引导需更新 |
| 改进五：PrePrompt Hook | 📋 待实施 | /socialware-app Skill 需增加 pre_prompt |
| 改进六：目录结构 | ✅ 已实施（有偏差） | 目录名与规划不同，见上表 |

---

## 受影响的文档（已更新状态）

| 文档 | 状态 |
|---|---|
| `docs/spec/001-architecture.md` | ⬜ 需更新 Hook Pipeline（增加 pre_prompt） |
| `docs/spec/002-socialware-contract.md` | ✅ 已更新（模板路径、`_待实现_`、身份格式） |
| `docs/spec/003-socialware-app-contract.md` | ✅ 已更新（App ID、目录路径、config.json schema、§5 格式） |
| `docs/spec/004-local-apps.md` | ✅ 已更新（身份格式示例） |
| `docs/spec/005-user-journey.md` | ✅ 已更新（三阶段流程、目录路径） |
| `docs/spec/006-p2p-simulation.md` | ✅ 已更新（身份格式、start-p2p.sh） |
| `docs/spec/007-developer-integration.md` | ✅ 已更新（三阶段接入流程） |
| `docs/testcase/TC-001~TC-013` | ✅ 已更新（路径、身份格式、阶段名） |
| `docs/respool-integration.md` | ⬜ 需同步本文档实际值 |
