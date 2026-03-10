# SwSim 测试用例索引

## 测试策略

### 分层测试

```
Layer 1: 基础功能          — 每个 Skill 独立验证
Layer 2: 集成链路          — Skill 间数据流转正确
Layer 3: 协作场景          — 多用户/多 namespace 交互
Layer 4: 数据完整性        — CRDT 保证、State 重建、热重启
Layer 5: 端到端            — 从零到完整协作的全链路
```

### 执行顺序

测试用例按依赖关系排序。TC-001 → TC-002 → TC-003 是基础链路，后续用例依赖前三个的产物。

### 测试用例格式

每个测试步骤包含四个字段：

| 字段 | 含义 |
|------|------|
| **操作** | 用户执行的具体动作 |
| **前置依赖** | 该步骤需要什么条件已满足 |
| **验证** | 执行后检查什么 |
| **验收标准** | 通过/失败的判定条件 |

---

## 测试用例清单

### Layer 1: 基础功能

| ID | 名称 | 测试目标 | 依赖 |
|----|------|---------|------|
| [TC-001](TC-001-socialware-dev.md) | Socialware 模板设计 | `/socialware-dev` 生成有效的 `.socialware.md` | 无 |
| [TC-002](TC-002-room-management.md) | Room 管理 | `/room` 的 create/list/show/join 全流程 | 无 |
| [TC-003](TC-003-app-binding.md) | App 绑定安装 | `/socialware-app-dev` 完整绑定流程 | TC-001, TC-002 |

### Layer 2: 集成链路

| ID | 名称 | 测试目标 | 依赖 |
|----|------|---------|------|
| [TC-004](TC-004-basic-runtime.md) | 基础运行时 | 单 namespace 完整 Flow 执行 | TC-003 |
| [TC-005](TC-005-hook-pipeline.md) | Hook Pipeline 验证 | pre_send 三项检查 + execute + after_write | TC-004 |
| [TC-006](TC-006-cbac-verification.md) | CBAC 权限控制 | any / author / author\|role 三种类型验证 | TC-004 |

### Layer 3: 协作场景

| ID | 名称 | 测试目标 | 依赖 |
|----|------|---------|------|
| [TC-007](TC-007-single-session-p2p.md) | 单会话 P2P | `/switch` 身份切换 + inbox 机制 | TC-004 |
| [TC-008](TC-008-multi-session-p2p.md) | 多会话 P2P | tmux 多 pane + watch-timeline + 并发写入 | TC-004 |
| [TC-009](TC-009-multi-namespace.md) | 多 Namespace 共存 | 3 个 App 同 Room + 跨 namespace 引用 | TC-003 |

### Layer 4: 数据完整性

| ID | 名称 | 测试目标 | 依赖 |
|----|------|---------|------|
| [TC-010](TC-010-state-rebuild.md) | State 重建 | `/rebuild` + CRDT 一致性验证 | TC-004 |
| [TC-011](TC-011-commitment-lifecycle.md) | Commitment 生命周期 | inactive → active → fulfilled/violated | TC-004 |
| [TC-012](TC-012-hot-restart.md) | 热重启 | 关闭→重启→状态恢复 | TC-004 |

### Layer 5: 端到端

| ID | 名称 | 测试目标 | 依赖 |
|----|------|---------|------|
| [TC-013](TC-013-end-to-end.md) | 完整端到端 | 从设计模板到多人协作的全链路 | 无（自包含） |

---

## 覆盖矩阵

### Skill 覆盖

| Skill | 主测试 | 辅助测试 |
|-------|--------|---------|
| `/socialware-dev` | TC-001 | TC-013 |
| `/room` | TC-002 | TC-009, TC-013 |
| `/socialware-app-dev` | TC-003 | TC-009, TC-013 |
| `/socialware-app` | TC-004~TC-012 | TC-013 |

### Spec 覆盖

| Spec | 覆盖测试 |
|------|---------|
| 001 Architecture | TC-005, TC-009, TC-010 |
| 002 Contract | TC-001 |
| 003 App Contract | TC-003, TC-004 |
| 004 Local Apps | TC-005 |
| 005 User Journey | TC-013 |
| 006 P2P Simulation | TC-007, TC-008 |
| 007 Developer Integration | TC-003 (manual 绑定验证) |

### 数据格式覆盖

| 数据格式 | 覆盖测试 |
|---------|---------|
| config.json | TC-002, TC-003, TC-009 |
| state.json | TC-004, TC-010, TC-011 |
| Ref (Timeline) | TC-004, TC-005, TC-010 |
| Content Object | TC-004, TC-005 |
| Identity | TC-002, TC-003 |
| .socialware.md | TC-001 |
| .app.md | TC-003 |
