#!/usr/bin/env bash
# start-p2p.sh — 启动多 peer P2P 模拟
#
# 用法:
#   .claude/skills/socialware-app/scripts/start-p2p.sh [--force] <room_name> <identity1> <identity2> [...]
#
# 选项:
#   --force   如果 tmux session 已存在，先 kill 再重建（默认行为是 attach 到已有 session）
#
# Identity 格式: {username}:{nickname}@{namespace}  (例: alice:Alice@local)
#
# 示例:
#   .claude/skills/socialware-app/scripts/start-p2p.sh doc-audit alice:Alice@local bob:Bob@local
#   .claude/skills/socialware-app/scripts/start-p2p.sh --force doc-audit alice:Alice@local bob:Bob@local
#
# 布局 (n identities → 2n panes):
#   ┌──────────────────────┬──────────────────────┐
#   │  Peer1 (Claude Code)  │  Peer2 (Claude Code)  │
#   │         (80%)         │         (80%)         │
#   ├───────────────────────┼───────────────────────┤
#   │  Peer1 watcher (20%) │  Peer2 watcher (20%) │
#   └───────────────────────┴───────────────────────┘
#
# 每个 identity 占 2 个 pane:
#   - 上方: Claude Code 会话（peer pane）
#   - 下方: watch-timeline.sh 实时通知（watcher pane, 20% 高度）
#
# 注意: identity ≠ role。一个 identity 可以持有多个 role，但只需要一个 peer pane。
#
# 兼容: WSL (bash) + macOS (bash/zsh), tmux 2.x+

# 解析 --force 选项
FORCE=false
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE=true
    else
        ARGS+=("$arg")
    fi
done
set -- "${ARGS[@]}"

ROOM_NAME="${1:?用法: $0 [--force] <room_name> <identity1> <identity2> [...]}"
shift
IDENTITIES=("$@")

if [ "${#IDENTITIES[@]}" -lt 2 ]; then
    echo "错误: 至少需要 2 个 identity" >&2
    exit 1
fi

ROOM_DIR="simulation/workspace/rooms/${ROOM_NAME}"
if [ ! -f "${ROOM_DIR}/config.json" ]; then
    echo "错误: Room 不存在或缺少 config.json: ${ROOM_DIR}" >&2
    exit 1
fi

SESSION_NAME="swsim-${ROOM_NAME}"

if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    if [ "$FORCE" = true ]; then
        echo "Session ${SESSION_NAME} 已存在，--force 模式: 销毁并重建..."
        tmux kill-session -t "${SESSION_NAME}"
    else
        echo "Session ${SESSION_NAME} 已存在，附着...（使用 --force 可重建）"
        exec tmux attach -t "${SESSION_NAME}"
    fi
fi

# 从 identity 中提取短名 (alice:Alice@local -> alice)
short_name() { echo "${1%%:*}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRST_WIN="$(short_name "${IDENTITIES[0]}")"
PEER_PANE_IDS=()
WATCHER_PANE_IDS=()

echo "创建 tmux session: ${SESSION_NAME}"
echo "  ${#IDENTITIES[@]} 个 identity → $((${#IDENTITIES[@]} * 2)) 个 pane (${#IDENTITIES[@]} peer + ${#IDENTITIES[@]} watcher)"

# 1. 创建 session，第一个 peer 的 Claude Code pane
tmux new-session -d -s "${SESSION_NAME}" -n "${FIRST_WIN}"
PEER_PANE_IDS+=($(tmux display-message -t "${SESSION_NAME}:${FIRST_WIN}" -p '#{pane_id}'))
echo "  peer pane ${PEER_PANE_IDS[0]}: ${IDENTITIES[0]}"

# 2. 为后续 identity 创建水平分割的 Claude Code pane
for ((i = 1; i < ${#IDENTITIES[@]}; i++)); do
    tmux split-window -t "${PEER_PANE_IDS[0]}" -h 2>/dev/null \
        || { echo "  错误: 无法创建 pane，跳过 ${IDENTITIES[$i]}" >&2; continue; }
    PEER_PANE_IDS+=($(tmux display-message -t "${SESSION_NAME}:${FIRST_WIN}" -p '#{pane_id}'))
    echo "  peer pane ${PEER_PANE_IDS[-1]}: ${IDENTITIES[$i]}"
done

# 3. 为每个 peer pane 创建下方的 watcher pane (20% 高度)
for ((i = 0; i < ${#PEER_PANE_IDS[@]}; i++)); do
    tmux split-window -t "${PEER_PANE_IDS[$i]}" -v -l 20% 2>/dev/null \
        || { echo "  警告: 无法创建 watcher pane for ${IDENTITIES[$i]}" >&2; continue; }
    WATCHER_PANE_IDS+=($(tmux display-message -t "${SESSION_NAME}:${FIRST_WIN}" -p '#{pane_id}'))
    echo "  watcher pane ${WATCHER_PANE_IDS[-1]}: ${IDENTITIES[$i]}"
done

# 4. 逐个 peer pane 发送 Claude Code 启动命令
for ((i = 0; i < ${#PEER_PANE_IDS[@]}; i++)); do
    ID="${IDENTITIES[$i]}"
    tmux send-keys -t "${PEER_PANE_IDS[$i]}" \
        "export SWSIM_ROOM='${ROOM_NAME}' SWSIM_IDENTITY='${ID}' && echo '=== Peer: ${ID} | Room: ${ROOM_NAME} ===' && claude --dangerously-skip-permissions '/socialware-app room=${ROOM_NAME} identity=${ID}'" Enter
done

# 5. 逐个 watcher pane 发送 watch-timeline.sh 命令（过滤掉自身消息）
for ((i = 0; i < ${#WATCHER_PANE_IDS[@]}; i++)); do
    ID="${IDENTITIES[$i]}"
    tmux send-keys -t "${WATCHER_PANE_IDS[$i]}" \
        "${SCRIPT_DIR}/watch-timeline.sh '${ROOM_NAME}' '${ID}'" Enter
done

echo ""
echo "P2P 模拟已启动: ${#PEER_PANE_IDS[@]} 个 peer + ${#WATCHER_PANE_IDS[@]} 个 watcher"
echo "  Peers: ${IDENTITIES[*]}"
echo "  切 pane: Ctrl-b + 方向键"
echo "  关闭:   tmux kill-session -t ${SESSION_NAME}"
echo ""

exec tmux attach -t "${SESSION_NAME}"
