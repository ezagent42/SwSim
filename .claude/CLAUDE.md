# CLAUDE.md — SwSim

## Project Overview

SwSim is a Socialware contract-file model simulation. It simulates the full lifecycle of Socialware — from designing organizations (contract templates) to binding and running them as Apps in Rooms.

## Key Concepts

- **Socialware** = contract file (`.socialware.md`) defining organization with 4 primitives (Role, Flow, Commitment, Arena)
- **Socialware App** = bound contract (`.app.md`) + workspace
- **Room** = collaboration space, can host multiple Socialware (Room ≠ App)
- **Timeline** = append-only JSONL, single source of truth
- **State** = pure-derived from Timeline, can be rebuilt anytime

## Directory Structure

- `docs/` — Specs and plans
- `docs/spec/` — Seven spec documents (architecture, contract, app-contract, local-apps, user-journey, p2p-simulation, developer-integration)
- `simulation/contracts/` — Socialware templates (`.socialware.md`, read-only)
- `simulation/workspace/` — Runtime data (identities, rooms)
- `.claude/skills/` — Four Skills (socialware-dev, socialware-app-dev, socialware-app, room)

## Naming Convention

- Templates: `{descriptive-name}.socialware.md` (e.g., `two-role-submit-approve.socialware.md`)
- Bound apps: `{namespace}.app.md` (e.g., `ta.app.md`)
- Names are decoupled — template name ≠ app name

## Development Rules

1. Template files in `simulation/contracts/` are **READ-ONLY** after creation
2. App Dev copies template to `workspace/rooms/{room}/contracts/{ns}.app.md` and binds there
3. Timeline is **append-only** — never edit or delete entries
4. State is always rebuildable from Timeline (`/rebuild`)
5. Use Chinese for documentation, English for variable names and code

## Skills

| Skill | 用途 | 产出 |
|-------|------|------|
| `/socialware-dev` | 设计组织 → 模板 | `.socialware.md` |
| `/room` | 创建/列表/管理 Room | Room 目录 + config.json |
| `/socialware-app-dev` | 绑定模板 + 安装到 Room | `.app.md` |
| `/socialware-app` | 运行 App（文字游戏运行时） | Timeline entries |

## P2P Simulation

- **Multi-session mode**: Each Claude Code session = one peer identity, sharing workspace files
- **Single-session mode**: Use `/switch @entity` for identity switching (fallback)
- Shared filesystem = P2P network (Zenoh simulation)

## Room Model

Room 可以承载多个 Socialware App，每个 App 提供一个 namespace：

```
Room "alpha"/
├── contracts/
│   ├── ta.app.md       (namespace: ta)
│   └── standup.app.md  (namespace: su)
├── state.json          (合并所有 namespace 的状态)
└── timeline/           (所有 App 共享的 append-only 时间线)
```

## State Management

```
Timeline (JSONL, append-only)
    ↓ reduce
State (JSON, derived)
    ↓ rebuild
可随时从 Timeline 重建 State
```

- 写操作：追加 Timeline entry
- 读操作：查询 State
- 恢复：从 Timeline 重放，重建 State
