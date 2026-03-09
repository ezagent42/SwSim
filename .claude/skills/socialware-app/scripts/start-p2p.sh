#!/usr/bin/env bash
# start-p2p.sh — 启动多 peer P2P 模拟
#
# 用法:
#   ./start-p2p.sh <room_name> <identity1> <identity2> [identity3 ...]
#
# 示例:
#   ./start-p2p.sh project-alpha @alice @bob
#   ./start-p2p.sh project-alpha @alice @bob @charlie
#
# 效果:
#   创建 tmux session "swsim-{room}"，每个 pane 对应一个 peer identity。
#   每个 pane 自动启动 claude code 并执行 /socialware-app。
#
# 前置条件:
#   - tmux 已安装
#   - claude (Claude Code CLI) 在 PATH 中
#   - Room 已创建且包含 config.json

set -euo pipefail

ROOM_NAME="${1:?用法: $0 <room_name> <identity1> <identity2> [...]}"
shift
IDENTITIES=("$@")

if [ ${#IDENTITIES[@]} -lt 2 ]; then
    echo "错误: 至少需要 2 个 identity" >&2
    echo "用法: $0 <room_name> <identity1> <identity2> [...]" >&2
    exit 1
fi

ROOM_DIR="simulation/workspace/rooms/${ROOM_NAME}"
if [ ! -f "${ROOM_DIR}/config.json" ]; then
    echo "错误: Room 不存在或缺少 config.json: ${ROOM_DIR}" >&2
    exit 1
fi

SESSION_NAME="swsim-${ROOM_NAME}"

# 如果 session 已存在则附着
if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    echo "Session ${SESSION_NAME} 已存在，附着..."
    tmux attach -t "${SESSION_NAME}"
    exit 0
fi

# 创建 tmux session，第一个 pane 给第一个 identity
FIRST_ID="${IDENTITIES[0]}"
tmux new-session -d -s "${SESSION_NAME}" -n "${FIRST_ID}" \
    -e "SWSIM_ROOM=${ROOM_NAME}" \
    -e "SWSIM_IDENTITY=${FIRST_ID}"

# 在第一个 pane 中启动 claude
tmux send-keys -t "${SESSION_NAME}:${FIRST_ID}" \
    "echo '=== Peer: ${FIRST_ID} | Room: ${ROOM_NAME} ===' && claude --prompt '/socialware-app room=${ROOM_NAME} identity=${FIRST_ID}'" Enter

# 为后续每个 identity 创建新 pane
for ((i = 1; i < ${#IDENTITIES[@]}; i++)); do
    ID="${IDENTITIES[$i]}"
    tmux split-window -t "${SESSION_NAME}" -h \
        -e "SWSIM_ROOM=${ROOM_NAME}" \
        -e "SWSIM_IDENTITY=${ID}"
    tmux send-keys -t "${SESSION_NAME}" \
        "echo '=== Peer: ${ID} | Room: ${ROOM_NAME} ===' && claude --prompt '/socialware-app room=${ROOM_NAME} identity=${ID}'" Enter
done

# 均匀排列 panes
tmux select-layout -t "${SESSION_NAME}" tiled

echo "P2P 模拟已启动: tmux session '${SESSION_NAME}'"
echo "  Room: ${ROOM_NAME}"
echo "  Peers: ${IDENTITIES[*]}"
echo ""
echo "操作:"
echo "  附着:  tmux attach -t ${SESSION_NAME}"
echo "  切 pane: Ctrl-b + 方向键"
echo "  关闭:  tmux kill-session -t ${SESSION_NAME}"

# 附着到 session
tmux attach -t "${SESSION_NAME}"
