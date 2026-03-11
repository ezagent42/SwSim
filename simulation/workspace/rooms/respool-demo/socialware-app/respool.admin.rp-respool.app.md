# respool.admin.rp-respool.app.md

> 状态: 已安装
> App-ID: respool.admin.rp-respool
> 基于模板: rp-respool.socialware.md
> 开发者: admin@local
> 安装者: admin@local
> Namespace: rp
> Room: respool-demo

资源池管理 App：绑定 OneSystem CLI (`one`) 为核心工具，以 `bash: one ...` 执行资源和分配操作，人工角色 (admin/user) 使用 manual。

---

## §1 Roles

| R-ID | 名称 | 能力 | 持有者 |
|------|------|------|--------|
| R1 | admin | cleanup, role_grant, role_revoke, alloc.settle, reject | admin@local |
| R2 | user | request, alloc.dispute | user@local |
| R3 | creator | resource.create, alloc.create | admin:creator@local |
| R4 | monitor | status.report | user:monitor@local |
| R5 | cleaner | resource.delete, alloc.release | admin:cleaner@local |

---

## §2 Flows

### Flow: resource_lifecycle

资源从申请到删除的生命周期。

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|---------|------|---------|---------|---------|
| _none_ | request | requested | R2 | any |
| requested | resource.create | created | R3 | any |
| requested | reject | rejected | R1 | any |
| created | resource.delete | deleted | R5 | author \| role:R1 |

### Flow: allocation_lifecycle

资源分配从创建到结算的生命周期。

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|---------|------|---------|---------|---------|
| _none_ | alloc.create | active | R3 | any |
| active | alloc.release | released | R5 | author \| role:R1 |
| released | alloc.settle | settled | R1 | any |
| released | alloc.dispute | disputed | R2 | author |

### Flow: monitoring_lifecycle

资源状态持续监控。

| 当前状态 | 动作 | 下一状态 | 要求角色 | 能力约束 |
|---------|------|---------|---------|---------|
| _none_ | status.init | monitoring | R4 | any |
| monitoring | status.report | monitoring | R4 | any |

---

## §3 Commitments

| C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限 |
|------|------|--------|--------|---------|------|
| C1 | creator 在资源创建后 10 分钟内，monitor 更新一次状态报告（执行 status.report） | R4 | R3 | resource_lifecycle.resource.create → created | 触发后 10min |
| C2 | cleaner 在删除资源前，必须通过 user 确认（user 需知晓删除将发生） | R5 | R2 | resource_lifecycle.resource.delete 操作前 | 操作前 |

---

## §4 Arena

- 进入策略: 持有 R1/R2/R3/R4/R5 任一角色
- 最小参与者: 2

---

## §5 Context Bindings

### on: request
- 前置: R2 + 状态=_none_（resource_lifecycle）
- 工具: manual
- 输入: 资源类型（如 GPU/CPU/Storage）+ 规格描述（自然语言）
- 输出: 申请描述文本
- 消息模板: "📥 @{author} 申请资源: {description}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: resource.create
- 前置: R3 + 状态=requested（resource_lifecycle）
- 工具: bash: one apply -f {yaml_file} -n {namespace}
- 输入: yaml_file: 资源 YAML 文件路径, namespace: 目标命名空间
- 输出: JSON: { name, kind, hostname, status }
- 消息模板: "✅ @{author} 已创建资源: {name}（{kind}）"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: reject
- 前置: R1 + 状态=requested（resource_lifecycle）
- 工具: manual
- 输入: 驳回原因
- 输出: 驳回通知文本
- 消息模板: "❌ @{author} 驳回申请: {reason}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: resource.delete
- 前置: R5 + 状态=created（resource_lifecycle）
- 工具: bash: one delete {kind} {name}
- 输入: kind: 资源类型, name: 资源名
- 输出: 删除确认文本
- 消息模板: "🗑️ @{author} 已删除资源: {name}（{kind}）"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.create
- 前置: R3 + 状态=_none_（allocation_lifecycle）
- 工具: bash: one alloc create --resource {kind}/{name} --amount {amount} --unit {unit} --consumer {consumer} --duration {duration}
- 输入: kind: 资源类型, name: 资源名, amount: 数量, unit: 单位, consumer: 消费者标识, duration: 租期（如 2h/1d）
- 输出: JSON: { alloc_id, phase, amount, unit, lease_until }
- 消息模板: "📌 @{author} 创建分配: {alloc_id}（{amount} {unit}，消费者: {consumer}，租期: {duration}）"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.release
- 前置: R5 + 状态=active（allocation_lifecycle）
- 工具: bash: one alloc release {alloc_id} --reason {reason}
- 输入: alloc_id: 分配 ID, reason: 释放原因（completed | cancelled | timeout | exhausted）
- 输出: JSON: { alloc_id, status, invoice_amount }
- 消息模板: "🔓 @{author} 释放分配: {alloc_id}，原因: {reason}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.settle
- 前置: R1 + 状态=released（allocation_lifecycle）
- 工具: bash: one alloc settle {alloc_id}
- 输入: alloc_id: 分配 ID
- 输出: 结算确认文本
- 消息模板: "💰 @{author} 完成结算: {alloc_id}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.dispute
- 前置: R2 + 状态=released（allocation_lifecycle）
- 工具: bash: one alloc dispute {alloc_id} --reason {reason}
- 输入: alloc_id: 分配 ID, reason: 争议原因
- 输出: 争议申请确认
- 消息模板: "⚠️ @{author} 对 {alloc_id} 提出争议: {reason}"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: status.init
- 前置: R4 + 状态=_none_（monitoring_lifecycle）
- 工具: bash: one get "*" -o json
- 输入: _无_
- 输出: JSON: 所有资源列表
- 消息模板: "🔭 @{author} 初始化监控，当前资源 {total} 个"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: status.report
- 前置: R4 + 状态=monitoring（monitoring_lifecycle）
- 工具: bash: one get "*" -o json
- 输入: _无_
- 输出: JSON: 所有资源列表（含状态、分配情况）
- 消息模板: "📊 @{author} 状态报告: 共 {total} 个资源，{active_allocs} 个活跃分配"
- 依赖: _无_
- 委托: _无_
- 资源: _无_

---

## §6 模拟环境

| 项 | 值 |
|----|-----|
| workspace | simulation/workspace/rooms/respool-demo/ |
| 身份模拟 | 人类用户: admin@local / user@local（用户名取 admin/user 仅为演示角色权限）；Agent session: admin:creator@local / user:monitor@local / admin:cleaner@local（agent 必须归属明确的 user） |
| P2P 模拟 | 多会话（每 session 一个 peer）或单节点（/switch） |
| 消息持久化 | timeline/shard-001.jsonl（append-only） |
| 状态派生 | state.json（可从 timeline 重建） |
| 消息输出 | 终端打印 |
