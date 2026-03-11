# 设计文档：四项变更

> 日期: 2026-03-10
> 状态: 已批准

## 变更 1: Commitment 引导更详细

socialware-dev skill §3 引导要求承诺必须具体可衡量：`{动作} + {量化指标} + {条件}`。

## 变更 2: 身份格式 `alice@local`

全局替换 `@entity:local` → `entity@local`。无 `@` 前缀，`@` 仅作 username/domain 分隔符。

## 变更 3: 强制检查 peer_cursor

- Hook: `UserPromptSubmit` → `check-inbox.sh`（扫描 `rooms/{room}/.session.{username}.json`）
- tmux watcher pane: `start-p2p.sh` 每 peer 配 watcher 小 pane
- Session 文件 per-room per-identity，多 peer 互不干扰，其他 skill 不再删除 session

## 变更 4: app-store + socialware-app-install

四阶段流转：
- socialware-dev → socialware/ (.socialware.md, §5=_待实现_)
- socialware-app-dev → app-store/ (.app.md, §5=已填工具, §1=_待绑定_)
- socialware-app-install → rooms/{room}/socialware-app/ (.app.md, §1=已填, namespace=已定)
- socialware-app → runtime (timeline+state)

新增 `simulation/app-store/` 目录和 `socialware-app-install` skill。
