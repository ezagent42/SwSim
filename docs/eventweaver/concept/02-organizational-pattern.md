# 02 — EventWeaver 是 peer-stewardship 的特殊实现

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 通用模式与特定实现的关系

```
peer-stewardship.socialware.md          ← 通用组织模式（模板）
    │
    ├── EventWeaver App                 ← 文件事件溯源实现
    ├── Wiki Collaboration App          ← 知识协作实现
    ├── Design Review App               ← 设计评审实现
    └── Config Manager App              ← 配置管理实现
```

peer-stewardship（对等管家制）定义了**组织的形状**：
- 扁平对等、创建即拥有、贡献自由但合并受控

EventWeaver 是这个形状在**文件事件溯源**领域的**具体实例**：
- "产出物" = 文件/文档（block）
- "贡献" = 文件内容编辑（写入事件）
- "管家" = 文件创建者/所有者
- "分叉" = 无权限写入在 P2P 同步时自动产生的事件分支

## 2. Role 映射

### 通用模式 → EventWeaver 具体化

| 通用 Role | EventWeaver 中的含义 |
|---|---|
| R1 管理员 | EventWeaver 实例的管理者，可 force_resolve 滞留分叉，管理 plugin 配置 |
| R2 参与者 | 文件的创建者/编辑者/审查者——同一人可能同时是某些文件的管家和另一些文件的贡献者 |
| R3 审计者 | 合规/审查角色，只读访问所有事件历史和分叉状态 |

### 关键区分：Socialware Role vs EventWeaver 内部角色

```
Socialware Role（组织资格）          EventWeaver 内部（运行时状态）
┌──────────────────────┐            ┌──────────────────────────┐
│ R2 = 参与者           │            │ 对于 block-A:             │
│ "你有资格使用         │            │   alice = owner (管家)    │
│  EventWeaver 的动作"  │            │   bob = granted (受信者)  │
│                      │            │   carol = no grant (贡献者)│
│ 与具体文件无关        │            │                          │
│ 安装时绑定            │            │ 对于 block-B:             │
│                      │            │   bob = owner             │
│                      │            │   alice = no grant        │
└──────────────────────┘            └──────────────────────────┘

R2 是进门的资格证                    内部角色是动态的信任关系
```

- Socialware Role 回答："你能不能参与这个组织？"
- EventWeaver CBAC 回答："你对这个具体文件能不能合入主线？"
- 两层独立，互不干涉

## 3. Flow 映射

### 通用模式 → EventWeaver 具体化

| 通用 Flow | EventWeaver 中的含义 |
|---|---|
| fork_review | **文件分叉审查**：P2P 同步时，某人对某文件的编辑因无 grant 自动分叉 → 文件管家审查 → accept 合入 / reject 丢弃 |
| trust_change | **文件权限变更**：文件管家授予某人对该文件的合并权限（grant），或撤销已有权限（revoke） |

### fork_review 在 EventWeaver 中的具体流转

```
Carol 在本地编辑了 Alice 的文件 (block-A)
    │
    ▼ P2P 同步触发
EventWeaver 检测: Carol 无 block-A 的 grant
    │
    ▼ 自动 diverge
创建分叉 fork-carol-block-a（Carol 是此分叉的管家）
    │
    ▼ fork_review Flow instance 创建
状态: pending
    │
    ├──▶ Alice (block-A 管家) → accept → 状态: merged
    │     Carol 的修改合入 Alice 的主线
    │
    ├──▶ Alice → reject → 状态: discarded
    │     Carol 的分叉被丢弃
    │
    └──▶ 超时 72h → C1 violated → R1 管理员 force_resolve
          管理员强制处理
```

### trust_change 在 EventWeaver 中的具体流转

```
Alice (block-A 管家) 决定信任 Bob
    │
    ▼ grant
trust_change Flow instance 创建，状态: trusted
Bob 未来对 block-A 的编辑将 auto-merge
    │
    ▼ 某天 Alice 撤销信任
Alice → revoke → 状态: revoked
Bob 未来的编辑将重新自动分叉
```

## 4. Capability 映射

### 通用 → EventWeaver 具体化

| 通用 Capability | EventWeaver 工具 | 具体含义 |
|---|---|---|
| create | `ew:create` | 创建 block，开始追踪文件（调用者成为管家） |
| contribute | `ew:contribute` | 写入文件内容（有 grant→主线，无 grant→分叉） |
| view | `ew:view` | 读取文件当前状态 |
| relate | `ew:relate` | 添加 block 间的因果关系（implement） |
| unrelate | `ew:unrelate` | 移除因果关系 |
| grant | `ew:grant` | 授予对特定 block 的合并权限 |
| revoke | `ew:revoke` | 撤销合并权限 |
| diverge | （系统自动） | P2P 同步时检测到无 grant 写入，自动分叉 |
| accept | `ew:accept` | 管家接受分叉合入主线 |
| reject | `ew:reject` | 管家拒绝分叉 |
| force_resolve | `ew:force_resolve` | 管理员强制处理滞留分叉 |
| audit | `ew:audit` | 查看 block 的完整事件历史 |
| list_forks | `ew:list_forks` | 查看 block 的所有分叉 |
| query | `ew:query` | 结构化查询事件 |
| archive | `ew:archive` | 归档 block（管家-only） |

### EventWeaver 特有的非通用功能

以下是 EventWeaver 作为"文件事件溯源"实现带来的额外能力，不在通用模式中：

| 功能 | 说明 |
|---|---|
| state_at | 时光回溯——重建任意历史点的文件状态 |
| diff | 差异比较——对比任意两个事件点之间的变化 |
| trace | 因果链追溯——从某事件沿 DAG 追溯关联事件 |
| Capability Plugin | 按 block_type 注册不同的记录/差异/合并/渲染逻辑 |

这些作为 EventWeaver App 的扩展能力，在 §5 Context Bindings 中定义。

## 5. Commitment 映射

| 通用 Commitment | EventWeaver 具体化 |
|---|---|
| C1: 管家必须审查 pending 分叉 | 文件管家必须在 72h 内 accept 或 reject 对其文件的分叉 |
| C2: 管理员兜底处理 | C1 超时后，R1 管理员在 24h 内 force_resolve |
| C3: 事件对审计者可查 | 所有文件事件对 R3 审计者可通过 audit/query 查询 |

## 6. 图结构的具体化

### 通用图

```
● 参与者 ──owns──→ ■ 产出物
● 参与者 ──granted──→ ■ 产出物
◆ 分叉 ──forks_from──→ ■ 产出物
■ 产出物 ──relates──→ ■ 产出物
```

### EventWeaver 图

```
● alice ──owns──→ ■ auth-module.rs (block)
● bob ──granted──→ ■ auth-module.rs
● carol ──(no grant)──→ ◆ carol/auth-module (fork, carol owns this)
◆ carol/auth-module ──forks_from──→ ■ auth-module.rs
■ auth-module.rs ──implements──→ ■ auth-spec.md
■ auth-spec.md ──implements──→ ■ project-prd.md
```

子图视角：
- **以 block 为中心**：auth-module.rs 的管家是 alice，bob 有 grant，carol 有一个待审查的分叉
- **以参与者为中心**：alice 管理 3 个 block，对 bob 的 2 个 block 有 grant，创建了 1 个分叉
- **以因果链为中心**：project-prd → auth-spec → auth-module 的实现链

全图视角：
- 所有参与者和所有 block 的信任关系网络
- 动态拓扑：grant/revoke 改变边
- 分叉密度反映协作冲突程度
