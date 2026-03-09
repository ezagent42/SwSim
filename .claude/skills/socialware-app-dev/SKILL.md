---
name: socialware-app-dev
description: "Bind a Socialware contract template — fills §5 Context Bindings with tools, installs into a Room, generates mock data for cross-references."
---

# Socialware App Dev — 契约绑定与安装

## 你在创建什么

**你在把一份 Socialware（组织蓝图）安装到一个 Room 中，使其成为可运行的 App**。

过程:
- 选择目标 Room（必须已存在，用 `/room create` 创建）
- 选择一份模板（`.socialware.md`）
- 给每个 Role 指定具体的人（必须是 Room 成员）
- 给每个动作绑定具体的工具
- 声明跨契约引用

## 制品关系

```
输入（只读）                              输出（App 制品）
─────────                               ─────────────
simulation/contracts/                    simulation/workspace/rooms/{room}/
  {name}.socialware.md                     ├── contracts/{ns}.app.md  ← 绑定副本
  状态: 模板                                ├── config.json  ← 更新 namespace
  §5 全部 _待绑定_                          ├── state.json   ← 更新 role_map
  ★ 不修改此文件                            └── ...

                                         simulation/workspace/identities/
                                           └── @{entity}.json  ← 按需创建
```

- **模板不变**: `simulation/contracts/{name}.socialware.md` 是 Socialware 产品，只读不改
- **绑定副本**: 复制模板到 `workspace/rooms/{room}/contracts/{ns}.app.md`
  - 扩展名改为 `.app.md`
  - 状态改为「已绑定」
  - §1 填入持有者
  - §5 填入工具绑定
- **命名解耦**: 模板名和 namespace 名由用户独立选择
  - 模板: `two-role-submit-approve.socialware.md`（描述性）
  - App: `ta.app.md`（namespace 简称）

## 流程

### Phase 1: 选择 Room 和模板

1. 列出可用 Room（`simulation/workspace/rooms/`），让用户选择
2. 列出可用模板（`simulation/contracts/*.socialware.md`），让用户选择
3. 让用户选择 namespace（2-4 字母简称，如 ta, ew, rp）
4. 读取模板，展示概要（Role, Flow, Commitment, Arena）

### Phase 2: 绑定角色（§1 + Identity）

5. 列出 Room 的现有成员
6. 逐个角色问持有者（必须是 Room 成员，或新加入）
7. 如需新成员，创建 identity 文件 + 加入 Room

### Phase 3: 填充 Bindings（§5）

8. 逐个动作填充，每次一个:
   - 工具: `bash:` | `mcp:` | `api:` | `manual` | `llm:`
   - 输入/输出
   - 消息模板
   - 依赖/委托/资源（从模板的 `_待绑定_` 变为具体引用，或确认 `_无_`）

### Phase 4: 跨契约 Mock

9. 对每个跨契约引用:
   - 同 Room 已安装 → 验证引用原子
   - 不存在 → 询问最小信息 → 生成 mock 数据到 state.json

### Phase 5: 写入

10. 复制模板到 `workspace/rooms/{room}/contracts/{ns}.app.md`
11. 在绑定副本上: 状态 → `已绑定`，填入 §1 持有者 + §5 Bindings + §6 模拟环境
12. 更新 config.json: 添加 namespace 到 `socialware.installed`，添加角色到 `socialware.roles`
13. 更新 state.json: 添加 role_map + commitments

## 参考

- 数据格式: @reference/data-formats.md
- 初始化脚本: @scripts/init-workspace.sh

## 关键原则

- **不改变组织图**: 只填充 binding
- **一次一个 binding**
- **Mock 按需生成**: 只在声明跨契约引用时创建
- **Room 必须先存在**: 使用 `/room create` 创建
- **模板只读**: 永远不修改 `simulation/contracts/` 中的文件
