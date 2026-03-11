#!/usr/bin/env bash
# init-workspace.sh — 初始化 Room 工作空间
#
# 用法: ./init-workspace.sh <room_name>
# 示例: ./init-workspace.sh project-alpha
#
# 创建:
#   simulation/workspace/rooms/<name>/identities/
#   simulation/workspace/rooms/<name>/contracts/
#   simulation/workspace/rooms/<name>/config.json
#   simulation/workspace/rooms/<name>/timeline/shard-001.jsonl
#   simulation/workspace/rooms/<name>/content/
#   simulation/workspace/rooms/<name>/artifacts/
#   simulation/workspace/rooms/<name>/state.json

set -euo pipefail

SIMULATION_DIR="simulation"
ROOM_NAME="${1:?用法: $0 <room_name>}"
WORKSPACE="${SIMULATION_DIR}/workspace"
ROOM_DIR="${WORKSPACE}/rooms/${ROOM_NAME}"

# 检查是否已存在
if [ -d "${ROOM_DIR}" ]; then
    echo "Room 已存在: ${ROOM_DIR}" >&2
    exit 1
fi

# 创建目录结构
mkdir -p "${WORKSPACE}/identities"
mkdir -p "${ROOM_DIR}/identities"
mkdir -p "${ROOM_DIR}/contracts"
mkdir -p "${ROOM_DIR}/timeline"
mkdir -p "${ROOM_DIR}/content"
mkdir -p "${ROOM_DIR}/artifacts"

# 创建空 timeline shard
SHARD_FILE="${ROOM_DIR}/timeline/shard-001.jsonl"
touch "${SHARD_FILE}"
echo "创建: ${SHARD_FILE}"

# 创建初始 state.json
STATE_FILE="${ROOM_DIR}/state.json"
cat > "${STATE_FILE}" << 'EOF'
{
  "flow_states": {},
  "role_map": {},
  "commitments": {},
  "last_clock": 0,
  "peer_cursors": {}
}
EOF
echo "创建: ${STATE_FILE}"

echo ""
echo "Room 工作空间初始化完成: ${ROOM_DIR}"
echo ""
echo "下一步:"
echo "  1. 创建 config.json:  ${ROOM_DIR}/config.json"
echo "  2. 创建 identity 文件: ${WORKSPACE}/identities/<username>:<nickname>@<namespace>.json"
echo "  3. 使用 /socialware-dev 设计 Socialware 模板"
