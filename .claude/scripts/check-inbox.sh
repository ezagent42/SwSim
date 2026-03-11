#!/bin/bash
# check-inbox.sh — UserPromptSubmit hook for socialware-app runtime
# Checks for new timeline messages since last peer_cursor
# Only active when .active-session.json exists

SESSION_FILE="simulation/workspace/.active-session.json"

# Guard: only run during active socialware-app session
[ ! -f "$SESSION_FILE" ] && exit 0

# Read session info
ROOM=$(python3 -c "import json; print(json.load(open('$SESSION_FILE'))['room'])" 2>/dev/null)
IDENTITY=$(python3 -c "import json; print(json.load(open('$SESSION_FILE'))['identity'])" 2>/dev/null)

[ -z "$ROOM" ] || [ -z "$IDENTITY" ] && exit 0

STATE_FILE="simulation/workspace/rooms/$ROOM/state.json"
[ ! -f "$STATE_FILE" ] && exit 0

# Get peer cursor
CURSOR=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
print(state.get('peer_cursors', {}).get('$IDENTITY', 0))
" 2>/dev/null)
[ -z "$CURSOR" ] && CURSOR=0

# Find timeline shards
TIMELINE_DIR="simulation/workspace/rooms/$ROOM/timeline"
[ ! -d "$TIMELINE_DIR" ] && exit 0

# Count new messages (clock > cursor)
NEW_MSGS=$(python3 -c "
import json, glob, os
cursor = $CURSOR
timeline_dir = '$TIMELINE_DIR'
new_messages = []
for shard in sorted(glob.glob(os.path.join(timeline_dir, '*.jsonl'))):
    with open(shard) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
                clock = msg.get('clock', 0)
                if clock > cursor and msg.get('author') != '$IDENTITY':
                    cmd = msg.get('ext', {}).get('command', {})
                    action = cmd.get('action', '?')
                    ns = cmd.get('namespace', '?')
                    author = msg.get('author', '?')
                    new_messages.append(f'  [clock:{clock}] {author} → {ns}:{action}')
            except json.JSONDecodeError:
                continue
if new_messages:
    print(f'📬 {len(new_messages)} 条新消息（自 clock={cursor} 以来）:')
    for m in new_messages:
        print(m)
" 2>/dev/null)

# Output new messages (visible to Claude Code as hook output)
[ -n "$NEW_MSGS" ] && echo "$NEW_MSGS"
exit 0
