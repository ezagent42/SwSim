#!/usr/bin/env bash
# watch-timeline.sh — 监听 Timeline 变化，打印新消息通知
#
# 用法:
#   ./watch-timeline.sh <room_name> [@identity]
#
# 示例:
#   ./watch-timeline.sh project-alpha           # 显示所有消息
#   ./watch-timeline.sh project-alpha @bob      # 过滤掉 @bob 自己的消息
#
# 效果:
#   持续监听 timeline 目录，打印新消息通知。
#   如果指定 identity，则跳过该身份发出的消息。
#   可在 tmux 的独立 pane 中运行，作为"通知中心"。
#
# 前置条件:
#   - inotifywait (inotify-tools) 已安装
#   - jq 已安装

set -euo pipefail

ROOM_NAME="${1:?用法: $0 <room_name> [@identity]}"
IDENTITY="${2:-}"

TIMELINE_DIR="simulation/workspace/rooms/${ROOM_NAME}/timeline"

if [ ! -d "${TIMELINE_DIR}" ]; then
    echo "错误: Timeline 目录不存在: ${TIMELINE_DIR}" >&2
    exit 1
fi

echo "══════════════════════════════════════"
echo "  Timeline Watcher"
echo "  Room: ${ROOM_NAME}"
if [ -n "${IDENTITY}" ]; then
    echo "  过滤身份: ${IDENTITY}（跳过自己的消息）"
else
    echo "  显示所有消息"
fi
echo "══════════════════════════════════════"
echo ""

# 记录当前行数作为基线
BASELINE=$(cat "${TIMELINE_DIR}"/*.jsonl 2>/dev/null | wc -l)

# 检查 inotifywait 是否可用
if command -v inotifywait &>/dev/null; then
    # 使用 inotifywait 实时监听
    inotifywait -m -e modify "${TIMELINE_DIR}" --format '%f' 2>/dev/null | while read -r FILE; do
        # 读取最后一行
        LAST_LINE=$(tail -1 "${TIMELINE_DIR}/${FILE}" 2>/dev/null)
        if [ -z "${LAST_LINE}" ]; then
            continue
        fi

        # 解析 author
        AUTHOR=$(echo "${LAST_LINE}" | jq -r '.author // empty' 2>/dev/null)
        if [ -z "${AUTHOR}" ]; then
            continue
        fi
        if [ -n "${IDENTITY}" ] && [ "${AUTHOR}" = "${IDENTITY}" ]; then
            continue  # 跳过自己的消息
        fi

        # 解析消息信息
        CLOCK=$(echo "${LAST_LINE}" | jq -r '.clock // "?"' 2>/dev/null)
        NS=$(echo "${LAST_LINE}" | jq -r '.ext.command.namespace // "?"' 2>/dev/null)
        ACTION=$(echo "${LAST_LINE}" | jq -r '.ext.command.action // "?"' 2>/dev/null)

        echo "$(date '+%H:%M:%S') [clock:${CLOCK}] ${AUTHOR} → ${NS}:${ACTION}"
    done
else
    # Fallback: 轮询模式（每 2 秒检查一次）
    echo "(inotifywait 不可用，使用轮询模式，每 2 秒检查)"
    echo ""

    LAST_COUNT="${BASELINE}"
    while true; do
        CURRENT_COUNT=$(cat "${TIMELINE_DIR}"/*.jsonl 2>/dev/null | wc -l)
        if [ "${CURRENT_COUNT}" -gt "${LAST_COUNT}" ]; then
            # 有新消息
            NEW_LINES=$((CURRENT_COUNT - LAST_COUNT))
            tail -"${NEW_LINES}" "${TIMELINE_DIR}"/*.jsonl 2>/dev/null | while IFS= read -r LINE; do
                AUTHOR=$(echo "${LINE}" | jq -r '.author // empty' 2>/dev/null)
                if [ -z "${AUTHOR}" ] || [ "${AUTHOR}" = "${IDENTITY}" ]; then
                    continue
                fi
                CLOCK=$(echo "${LINE}" | jq -r '.clock // "?"' 2>/dev/null)
                NS=$(echo "${LINE}" | jq -r '.ext.command.namespace // "?"' 2>/dev/null)
                ACTION=$(echo "${LINE}" | jq -r '.ext.command.action // "?"' 2>/dev/null)
                echo "$(date '+%H:%M:%S') [clock:${CLOCK}] ${AUTHOR} → ${NS}:${ACTION}"
            done
            LAST_COUNT="${CURRENT_COUNT}"
        fi
        sleep 2
    done
fi
