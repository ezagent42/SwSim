#!/usr/bin/env bash
# start-p2p.sh — 启动多 peer P2P 模拟
#
# 用法:
#   .claude/skills/socialware-app/scripts/start-p2p.sh <room_name> <identity1> <identity2> [...]
#
# 示例:
#   .claude/skills/socialware-app/scripts/start-p2p.sh doc-audit @alice @bob
#
# 兼容: WSL (bash) + macOS (bash/zsh), tmux 2.x+

ROOM_NAME="${1:?用法: $0 <room_name> <identity1> <identity2> [...]}"
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
    echo "Session ${SESSION_NAME} 已存在，附着..."
    exec tmux attach -t "${SESSION_NAME}"
fi

strip_at() { echo "${1#@}"; }

FIRST_WIN="$(strip_at "${IDENTITIES[0]}")"
PANE_IDS=()

echo "创建 tmux session: ${SESSION_NAME}"

# 1. 创建 session，记录第一个 pane ID
tmux new-session -d -s "${SESSION_NAME}" -n "${FIRST_WIN}"
PANE_IDS+=($(tmux display-message -t "${SESSION_NAME}:${FIRST_WIN}" -p '#{pane_id}'))
echo "  pane ${PANE_IDS[0]}: ${IDENTITIES[0]}"

# 2. 为后续 identity 创建 pane，记录每个 pane ID
for ((i = 1; i < ${#IDENTITIES[@]}; i++)); do
    tmux split-window -t "${SESSION_NAME}:${FIRST_WIN}" -h 2>/dev/null \
        || tmux split-window -t "${SESSION_NAME}:${FIRST_WIN}" -v 2>/dev/null \
        || { echo "  错误: 无法创建 pane，跳过 ${IDENTITIES[$i]}" >&2; continue; }
    # split-window 后新 pane 自动获得焦点，获取它的 ID
    PANE_IDS+=($(tmux display-message -t "${SESSION_NAME}:${FIRST_WIN}" -p '#{pane_id}'))
    echo "  pane ${PANE_IDS[-1]}: ${IDENTITIES[$i]}"
done

# 3. 均匀排列
tmux select-layout -t "${SESSION_NAME}:${FIRST_WIN}" tiled

# 4. 逐个 pane 发送启动命令（用 pane ID 定位，不受 layout 影响）
for ((i = 0; i < ${#PANE_IDS[@]}; i++)); do
    ID="${IDENTITIES[$i]}"
    tmux send-keys -t "${PANE_IDS[$i]}" \
        "export SWSIM_ROOM='${ROOM_NAME}' SWSIM_IDENTITY='${ID}' && echo '=== Peer: ${ID} | Room: ${ROOM_NAME} ===' && claude --dangerously-skip-permissions '/socialware-app room=${ROOM_NAME} identity=${ID}'" Enter
done

echo ""
echo "P2P 模拟已启动: ${#PANE_IDS[@]} 个 pane"
echo "  Peers: ${IDENTITIES[*]}"
echo "  切 pane: Ctrl-b + 方向键"
echo "  关闭:   tmux kill-session -t ${SESSION_NAME}"
echo ""

exec tmux attach -t "${SESSION_NAME}"
