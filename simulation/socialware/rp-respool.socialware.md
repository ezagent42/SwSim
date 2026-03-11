# rp-respool.socialware.md

> 状态: 模板
> 开发者: admin@local

资源池管理 Socialware：定义资源申请、创建、分配、释放、结算的完整生命周期，支持 5 种角色协作。

---

## §1 Roles

| R-ID | 名称 | 能力 | 持有者 |
|------|------|------|--------|
| R1 | admin | cleanup, role_grant, role_revoke, alloc.settle, reject | _待绑定_ |
| R2 | user | request, alloc.dispute | _待绑定_ |
| R3 | creator | resource.create, alloc.create | _待绑定_ |
| R4 | monitor | status.report | _待绑定_ |
| R5 | cleaner | resource.delete, alloc.release | _待绑定_ |

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
| C1 | creator 在资源创建后 10 分钟内，monitor 更新一次状态报告（执行 status.report） | R4 | R3 | resource_lifecycle.resource.create → created | _待绑定_ |
| C2 | cleaner 在删除资源前，必须通过 user 确认（user 需知晓删除将发生） | R5 | R2 | resource_lifecycle.resource.delete 操作前 | 操作前 |

---

## §4 Arena

- 进入策略: 持有 R1/R2/R3/R4/R5 任一角色
- 最小参与者: 2

---

## §5 Context Bindings

### on: request
- 前置: R2 + 状态=_none_（resource_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: resource.create
- 前置: R3 + 状态=requested（resource_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: reject
- 前置: R1 + 状态=requested（resource_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: resource.delete
- 前置: R5 + 状态=created（resource_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.create
- 前置: R3 + 状态=_none_（allocation_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.release
- 前置: R5 + 状态=active（allocation_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.settle
- 前置: R1 + 状态=released（allocation_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: alloc.dispute
- 前置: R2 + 状态=released（allocation_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: status.init
- 前置: R4 + 状态=_none_（monitoring_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_

### on: status.report
- 前置: R4 + 状态=monitoring（monitoring_lifecycle）
- 工具: _待实现_
- 输入: _待实现_
- 输出: _待实现_
- 消息模板: _待实现_
- 依赖: _无_
- 委托: _无_
- 资源: _无_
