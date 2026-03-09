---
name: socialware-dev
description: "Design a new Socialware organization — generates contract template files (.socialware.md) through guided Q&A defining Role, Flow, Commitment, Arena."
---

# Socialware Dev — 契约模板生成

## 你在创建什么

**你在设计一个 Socialware——一份定义组织结构的契约文件**。

Socialware 是一份 `.socialware.md` 文件，用四个原语描述组织图：
- **Role**: 组织中的位置（不是人）和能力
- **Flow**: 状态机，定义动作如何推进状态
- **Commitment**: 角色间可追踪的承诺
- **Arena**: 谁可以参与

产出的契约是**可分享、可组合的产品**。它可以被不同的 App Dev 各自绑定成不同的 App，也可以被其他 Socialware 通过引用组合。

## 制品

- **产出**: `simulation/contracts/{name}.socialware.md`（状态: 模板）
- 文件扩展名: `.socialware.md`
- 命名: 用户自选描述性名称（如 `two-role-submit-approve.socialware.md`）
- 这份文件是 **Socialware 产品**——可分发给不同的 App Dev 各自绑定
- App Dev 阶段会 **复制** 此模板到 workspace 中再绑定，模板本身保持不变
- 契约格式: 见 @reference/contract-spec.md

## 流程

每次只问一个问题，按序收集:

1. **场景**: 这个组织做什么？有哪些角色（位置，不是人）？
2. **§1 Roles**: 整理角色表（ID, 名称, 能力），持有者全部 `_待绑定_`
3. **§2 Flows**: 每个流程的状态机（subject, 状态, 转换, 角色, 能力约束[any/author/author | role:R]）
4. **§3 Commitments**: 角色间的承诺（双方, 触发条件, 时限）
5. **§4 Arena**: 进入策略
6. **§5 Bindings**: 自动生成骨架（从 Flow 提取动作），工具全部 `_待绑定_`
   - 依赖/委托/资源: 如果设计层有需求用 `_待绑定_`，确实没有用 `_无_`
7. **命名**: 让用户为模板文件命名（描述性名称，如 `two-role-submit-approve`）
8. **确认**: 展示预览，写入文件

## 关键原则

- **只定义图，不填 context**: §5 工具全部 `_待绑定_`
- **角色 = 位置**: 同一人可持有多个角色
- **Flow = 状态机**: 必须有明确状态和转换
- **Commitment = 可追踪的义务**
- **依赖/委托/资源**: 在模板中声明抽象需求（`_待绑定_`），不是 `_无_`
- **文件扩展名**: `.socialware.md`，不是 `.contract.md`
