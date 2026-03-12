# 03 — EventWeaver 提供的工具

> 日期: 2026-03-12
> 状态: 概念设计

---

## 1. 工具来源：从 elfiee 拆解

elfiee 原有 18 个 MCP 工具 + 14 个 CLI 命令。拆解后归属：

| 归属 | elfiee 原工具 | 去向 |
|---|---|---|
| **EventWeaver 保留** | block CRUD, document read/write, session append/read, link/unlink, grant/revoke, history, state_at_event | 核心工具 |
| **EventWeaver 新增** | — | fork 管理、diff、trace、query |
| AgentForge | editor_create, editor_delete, auth | Agent 生命周期 |
| TaskArena | task_write, task_read, task_commit | 任务状态机 |
| RePool | file_list, open/close (项目管理) | 资源管理 |

## 2. EventWeaver 工具清单

### 2.1 核心工具（§5 Context Bindings 中定义）

这些工具实现 peer-stewardship 模板中的 capabilities。

#### 产出物管理

| 工具 | 对应 Capability | 说明 | 来源 |
|---|---|---|---|
| `ew:create` | create | 创建 block，开始追踪。调用者成为管家。可指定 block_type 选择 plugin。 | elfiee: block_create |
| `ew:contribute` | contribute | 向 block 写入内容。plugin 决定事件 mode（delta/full/append/ref）。有 grant→主线，无 grant→分叉。 | elfiee: document_write, session_append |
| `ew:view` | view | 读取 block 当前状态（从事件重建）。 | elfiee: block_get |
| `ew:archive` | archive | 软删除 block。管家-only（工具内部验证）。 | elfiee: block_delete |

#### 关系管理

| 工具 | 对应 Capability | 说明 | 来源 |
|---|---|---|---|
| `ew:relate` | relate | 添加 block 间的因果关系（implement）。有 grant→主线，无 grant→分叉。 | elfiee: block_link |
| `ew:unrelate` | unrelate | 移除因果关系。同样遵循 grant/分叉 逻辑。 | elfiee: block_unlink |

#### 信任管理

| 工具 | 对应 Capability | 说明 | 来源 |
|---|---|---|---|
| `ew:grant` | grant | 授予某参与者对特定 block 的合并权限。管家-only。创建 trust_change Flow instance。 | elfiee: grant |
| `ew:revoke` | revoke | 撤销已授予的合并权限。管家-only。 | elfiee: revoke |

#### 分叉管理

| 工具 | 对应 Capability | 说明 | 来源 |
|---|---|---|---|
| `ew:accept` | accept | 管家接受分叉，合入主线。触发 CRDT merge。 | **新增** |
| `ew:reject` | reject | 管家拒绝分叉，标记为 discarded。 | **新增** |
| `ew:force_resolve` | force_resolve | R1 管理员强制处理滞留分叉。 | **新增** |
| `ew:list_forks` | list_forks | 查看 block 的所有分叉及其状态。 | **新增** |

#### 事件消费

| 工具 | 对应 Capability | 说明 | 来源 |
|---|---|---|---|
| `ew:audit` | audit | 查看 block 的完整事件历史，按时间顺序。 | elfiee: block_history |
| `ew:query` | query | 结构化查询事件（按作者、时间、block_type、关系等）。 | **新增** |

### 2.2 扩展工具（EventWeaver 特有，不在通用模板中）

这些是 EventWeaver 作为"文件事件溯源"实现的额外能力。

| 工具 | 说明 | 来源 |
|---|---|---|
| `ew:state_at` | 时光回溯——重建 block 在指定事件点的状态 | elfiee: state_at_event |
| `ew:diff` | 差异比较——对比任意两个事件点之间的变化 | **新增** |
| `ew:trace` | 因果链追溯——从某事件沿 DAG 追溯上下游关联事件 | **新增** |
| `ew:rebuild` | 从事件日志完整重建所有 block 的当前状态 | elfiee: StateProjector replay |

## 3. Capability Plugin 机制

EventWeaver 核心只管"事件进来 → 存储 → 权限检查 → 主线或分叉"。具体怎么记录、diff、merge、渲染由 plugin 决定。

### 3.1 Plugin 接口

```
Capability Plugin:
  block_type     → 处理哪种 block（document / session / ref / ...）
  event_mode     → 用什么 mode 记录（full / delta / append / ref）
  diff(old, new) → 怎么计算差异
  merge(a, b)    → CRDT 合并逻辑
  render(state)  → 怎么展示给人看
```

### 3.2 内置 Plugin

| Plugin | block_type | event_mode | diff 方式 | merge 方式 | 渲染 |
|---|---|---|---|---|---|
| document | document | delta | 文本 diff | yrs (CRDT text) | Markdown |
| session | session | append | N/A（只追加） | 追加合并 | 对话日志 |
| ref | ref | ref | hash 比较 | 按 hash 取最新 | 外部链接 |

### 3.3 未来可扩展 Plugin

| Plugin | block_type | 用途 |
|---|---|---|
| schema | schema | JSON Schema / 配置文件，mode=full |
| notebook | notebook | Jupyter notebook，mode=delta |
| binary | binary | 二进制文件，mode=ref，关联 RePool |

## 4. 工具输入/输出规范

### 4.1 ew:create

```
输入:
  name: string          — block 显示名
  block_type: string    — 选择 plugin（document / session / ref）
  content?: any         — 初始内容（可选，由 plugin 定义格式）
  description?: string  — 可选描述

输出:
  block_id: string      — 新创建的 block UUID
  owner: string         — 管家（= 调用者）
  event_id: string      — 创建事件的 ID
```

### 4.2 ew:contribute

```
输入:
  block_id: string      — 目标 block
  content: any          — 贡献内容（格式由 plugin 定义）

输出:
  event_id: string      — 贡献事件的 ID
  mode: string          — 事件 mode（delta / full / append / ref）
  branch?: string       — 如果产生分叉，返回分叉 ID；否则 null
```

### 4.3 ew:grant / ew:revoke

```
输入:
  block_id: string      — 目标 block
  target: string        — 被授权/撤权的参与者 identity
  capability?: string   — 可选，指定具体能力（默认全部写入能力）

输出:
  event_id: string      — 权限变更事件的 ID
  flow_id: string       — trust_change Flow instance ID
```

### 4.4 ew:accept / ew:reject

```
输入:
  fork_id: string       — 分叉的 block ID
  comment?: string      — 可选审查意见

输出:
  event_id: string      — 审查事件的 ID
  result: string        — "merged" 或 "discarded"
  conflict?: boolean    — 合并时是否遇到 CRDT 冲突（仅 accept）
```

### 4.5 ew:audit

```
输入:
  block_id: string      — 目标 block
  from?: string         — 起始事件 ID（可选）
  to?: string           — 结束事件 ID（可选）
  limit?: number        — 返回条数限制

输出:
  events: Event[]       — 事件列表
  total: number         — 事件总数
```

### 4.6 ew:state_at

```
输入:
  block_id: string      — 目标 block
  event_id: string      — 回溯到的事件点

输出:
  state: Block          — 该事件点的 block 完整状态
  event_count: number   — 重放的事件数
```

### 4.7 ew:query

```
输入:
  filter:
    author?: string     — 按作者过滤
    block_type?: string — 按 block 类型过滤
    time_range?:        — 按时间范围
      from: ISO8601
      to: ISO8601
    related_to?: string — 按 DAG 关系过滤
    has_forks?: boolean — 只返回有分叉的 block
  limit?: number
  offset?: number

输出:
  results: Event[] | Block[]
  total: number
```

### 4.8 ew:diff

```
输入:
  block_id: string      — 目标 block
  from: string          — 起始事件 ID
  to: string            — 结束事件 ID

输出:
  diff: any             — 差异内容（格式由 plugin 定义）
  additions: number     — 新增行/条目数
  deletions: number     — 删除行/条目数
```

## 5. 与其他 App 工具的交互

### 5.1 被引用（其他 App 调用 EventWeaver）

```
TaskArena:
  ta:submit 时 → 调用 ew:create 开始追踪相关文件
  ta:approve 时 → 调用 ew:audit 获取审计证据

AgentForge:
  af:create_agent 时 → Agent 获得 ew:contribute 等能力
```

### 5.2 引用（EventWeaver 调用其他 App）

```
EventWeaver → RePool:
  ew:create (block_type=ref) → 引用 rp:allocate 中的文件
  ew:contribute (mode=ref) → 更新 RePool 文件引用

EventWeaver → TaskArena:
  ew:accept/reject → 可触发 ta:notify（如果配置了委托）
```
