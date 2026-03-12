# 01 — EventWeaver 的定位和主要功能

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 一句话定位

**EventWeaver 是基于 peer-stewardship 组织模式的文件级事件溯源 Socialware App。**

它将 elfiee（被动事件编织器）的核心功能拆解重构，以 Socialware 合约的形式运行在 Room 中。

## 2. 是什么

EventWeaver 聚焦于三件事：

### 2.1 记录

对产出物（文件、文档、配置等）的一切变更，记录为不可变事件。

- **EAVT 模型**：Entity（什么被改了）、Attribute（谁用什么能力改的）、Value（改了什么）、Timestamp（向量时钟）
- **四种记录模式**：full（完整快照）、delta（增量差异）、ref（外部引用）、append（追加条目）
- **不可变**：事件一旦写入，永不修改

### 2.2 关联

将事件组织成有意义的逻辑链条。

- **DAG 关系**（relate/unrelate）：产出物之间的因果关系（A 决定了 B 的存在）
- **事件序列**：同一产出物的事件按时间形成线性链
- **tool_usage 推导**：从 Socialware 消息事件中推导与文件事件的关联（"alice 在 da:submit 时引用了 rp:file-001"）

### 2.3 消费

提供多种方式消费事件链条。

- **线性消费**：按时间顺序回放事件（audit），重建当前状态（state rebuild）
- **非线性消费**：时光回溯到任意历史点（state_at），比较任意两点差异（diff）
- **分叉消费**：查看并行世界线的状态（list_forks），为审查提供证据

## 3. 不是什么

| EventWeaver 不是 | 理由 |
|---|---|
| P2P 基础设施 | DAG/CRDT/Zenoh 是 ezagent 底层（elf + yrs）的职责 |
| 文件存储系统 | 文件的实际 bytes 由 RePool 管理 |
| Git 替代品 | 没有手动分支/合并操作，分叉和合并都是自动的 |
| 任务管理系统 | 任务状态机由 TaskArena 管理 |
| 身份管理系统 | Agent/Editor 生命周期由 AgentForge 管理 |
| 通用内容管理 | Socialware Timeline 管消息级的 Content，EventWeaver 管文件级的 Artifact |

## 4. 核心功能清单

```
记录 (Record)
├── 创建产出物并开始追踪 (create)
├── 向产出物贡献内容 (contribute)
├── 管理产出物间的因果关系 (relate / unrelate)
└── 归档产出物 (archive)

信任 (Trust)
├── 授予合并权限 (grant)
├── 撤销合并权限 (revoke)
└── 权限驱动的自动分叉 (diverge — 系统自动)

审查 (Review)
├── 查看分叉列表 (list_forks)
├── 接受分叉合入主线 (accept)
├── 拒绝分叉 (reject)
└── 管理员强制处理 (force_resolve)

消费 (Consume)
├── 事件历史回放 (audit)
├── 时光回溯 (state_at)
├── 差异比较 (diff)
├── 结构化查询 (query)
└── 查看当前状态 (view)
```

## 5. 在四 App 体系中的位置

```
┌─────────────────────────────────────────────────┐
│  应用层                                          │
│  ta: TaskArena    — 谁该做什么（工作流状态机）    │
│  af: AgentForge   — 谁来做（Agent 构造/管理）    │
├─────────────────────────────────────────────────┤
│  基础设施层                                       │
│  ew: EventWeaver  — 东西发生了什么（事件/分叉/审计）│
│  rp: RePool       — 东西存在哪（资源分配/存储）    │
├─────────────────────────────────────────────────┤
│  Socialware Runtime + ezagent 底层               │
└─────────────────────────────────────────────────┘
```

EventWeaver 和 RePool 是**基础设施层**——被上层的 TaskArena 和 AgentForge 依赖。

### 与其他 App 的关系

| 关系 | 说明 |
|---|---|
| TaskArena → EventWeaver | ta:submit 时，EventWeaver 开始追踪相关文件的变更 |
| EventWeaver → RePool | 文件实际存储在 RePool 中，EventWeaver 通过 ref 模式引用 |
| AgentForge → EventWeaver | Agent 的操作（contribute, grant 等）产生 EventWeaver 事件 |
| EventWeaver → TaskArena | 审计证据（audit/diff）为 ta:approve/reject 提供决策依据 |

## 6. 来源：从 elfiee 继承的核心

EventWeaver 继承了 elfiee 的以下核心：

| elfiee 组件 | EventWeaver 继承方式 |
|---|---|
| EAVT 事件模型 | 直接保留 |
| Capability 系统 | 保留为 plugin 机制 |
| CBAC 权限检查 | 语义从"拒绝"改为"分叉" |
| Block DAG | 保留为 relate/unrelate |
| StateProjector | 保留为 state rebuild |
| 时间旅行 (state_at_event) | 直接保留 |
| Actor 模型引擎 | 保留架构，适配 Socialware Runtime |

**不继承的部分**：Editor 管理（→ AgentForge）、Task blocks（→ TaskArena）、ref 存储（→ RePool）。
