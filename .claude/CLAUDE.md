# CLAUDE.md — SwSim

## Project Overview

SwSim is a Socialware contract-file model simulation. It simulates the full lifecycle of Socialware — from designing organizations (contract templates) to developing, installing, and running them as Apps in Rooms.

## Key Concepts

- **Socialware** = contract file (`.socialware.md`) defining organization with 4 primitives (Role, Flow, Commitment, Arena)
- **Socialware App** = developed contract (`.app.md`) with tool bindings filled
- **App Store** = `simulation/app-store/` — developed Apps awaiting installation
- **Room** = collaboration space, can host multiple Socialware (Room ≠ App)
- **Timeline** = append-only JSONL, single source of truth
- **State** = pure-derived from Timeline, can be rebuilt anytime
- **Identity** = `{username}@{namespace}` (human) or `{username}:{session-name}@{namespace}` (agent session), no `@` prefix
  - Human user: `alice@local` — 无 session name
  - Agent session: `alice:ppt-maker@local` — `session-name` 是 Claude Code（或其它 Agent）的 session 名称，由创建者指定
  - 文件名始终为 `{username}@{namespace}.json`（省略 session-name）
- **Identity 前置条件** = 所有 Skill 启动时必须确认身份（`workspace/identities/` 中存在），`/room` 是身份的创建入口

## Directory Structure

- `docs/` — Specs and plans
- `docs/spec/` — Seven spec documents
- `docs/testcase/` — Thirteen test cases
- `simulation/socialware/` — Socialware templates (`.socialware.md`, read-only)
- `simulation/app-store/` — Developed Apps (`.app.md`, tools bound, users unbound) + `registry.json`
- `simulation/workspace/identities/` — Global identity files
- `simulation/workspace/rooms/` — Rooms with installed Apps
- `.claude/skills/` — Five Skills (socialware-dev, socialware-app-dev, socialware-app-install, socialware-app, room)
- `.claude/scripts/` — Hook scripts (check-inbox.sh)

## Five-Stage Lifecycle

```
room  →  socialware-dev  →  socialware-app-dev  →  socialware-app-install  →  socialware-app
创建空间    模板设计            App 开发                App 安装到 Room            运行时
创建身份    需要身份(开发者)     需要身份(开发者)         需要身份(安装者)+Room成员   需要身份+Room成员

socialware/           app-store/                rooms/{room}/socialware-app/ runtime
{name}.socialware.md  {app-id}.app.md           {app-id}.app.md            timeline+state
                      + registry.json

开发者: {identity}    开发者: {identity}         安装者: {identity}
§1 = _待绑定_          §1 = _待绑定_              §1 = 已填持有者
§5 = _待实现_          §5 = 已填工具              §5 = 同 app-store
状态: 模板             状态: 已开发               状态: 已安装
```

## Naming Convention

- Templates: `{descriptive-name}.socialware.md` (e.g., `two-role-submit-approve.socialware.md`)
- App-ID: `{AppName}.{DeveloperName}.{SocialwareName}` format (e.g., `doc-review.alice.two-role-submit-approve`)
  - AppName: developer-chosen descriptive name
  - DeveloperName: identity username of the developer
  - SocialwareName: name of the source template (without `.socialware.md`)
- Namespace: 2-4 letter abbreviation, chosen at install time (e.g., `dc`, `ta`)
- Names are decoupled — template name ≠ app-id ≠ namespace

## Placeholder Convention

- `_待实现_`: §5 tool bindings, awaiting App Dev to fill in tool implementations
- `_待绑定_`: §1 role holders, awaiting App Install to assign specific users
- `_无_`: explicitly no dependency (design decision)

## Development Rules

1. Template files in `simulation/socialware/` are **READ-ONLY** after creation
2. App Dev copies template to `simulation/app-store/{app-id}.app.md`, fills §5 tools, and registers in `simulation/app-store/registry.json`
3. App Install copies from app-store to `workspace/rooms/{room}/socialware-app/` and fills §1 holders
4. Timeline is **append-only** — never edit or delete entries
5. State is always rebuildable from Timeline (`/rebuild`)
6. Use Chinese for documentation, English for variable names and code

## Skills

| Skill | 用途 | 产出 |
|-------|------|------|
| `/socialware-dev` | 设计组织 → 模板 | `.socialware.md` |
| `/room` | 创建/列表/管理 Room + 清理 session | Room 目录 + config.json |
| `/socialware-app-dev` | 开发 App（填工具） | `app-store/{app-id}.app.md` |
| `/socialware-app-install` | 安装 App 到 Room（绑用户） | `rooms/{room}/socialware-app/` |
| `/socialware-app` | 运行 App（文字游戏运行时） | Timeline entries |

## P2P Simulation

- **Multi-session mode**: Each Claude Code session = one peer identity, sharing workspace files
- **Single-session mode**: Use `/switch {username}@local` or `/switch {username}:{session-name}@local` for identity switching (fallback)
- **Inbox hook**: `UserPromptSubmit` hook scans `rooms/{room}/.session.{username}.json`（per-room per-identity，支持多 peer 同时运行）
- **Session 生命周期**: `/socialware-app` 启动创建，`/quit` 退出删除，`/room clean-sessions` 清理残留
- **tmux watcher**: Each peer gets a watcher pane for passive notification
- Shared filesystem = P2P network (Zenoh simulation)

## Room Model

Room 可以承载多个 Socialware App，每个 App 提供一个 namespace：

```
Room "alpha"/
├── socialware-app/
│   ├── task-assignment.app.md  (namespace: ta)
│   └── standup.app.md          (namespace: su)
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
