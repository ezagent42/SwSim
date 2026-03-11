#!/bin/bash
# check-inbox.sh — UserPromptSubmit hook for socialware-app runtime
# Checks for new timeline messages since last peer_cursor
# Scans rooms/{room}/.session.{username}.json (per-room per-identity)

WORKSPACE="simulation/workspace"

# Guard: find any active session files
SESSION_FILES=$(find "$WORKSPACE/rooms" -name '.session.*.json' 2>/dev/null)
[ -z "$SESSION_FILES" ] && exit 0

# Process each active session
for SESSION_FILE in $SESSION_FILES; do
    ROOM=$(python3 -c "import json; print(json.load(open('$SESSION_FILE'))['room'])" 2>/dev/null)
    IDENTITY=$(python3 -c "import json; print(json.load(open('$SESSION_FILE'))['identity'])" 2>/dev/null)

    [ -z "$ROOM" ] || [ -z "$IDENTITY" ] && continue

    STATE_FILE="$WORKSPACE/rooms/$ROOM/state.json"
    [ ! -f "$STATE_FILE" ] && continue

    # Get peer cursor
    CURSOR=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
print(state.get('peer_cursors', {}).get('$IDENTITY', 0))
" 2>/dev/null)
    [ -z "$CURSOR" ] && CURSOR=0

    # Find timeline shards
    TIMELINE_DIR="$WORKSPACE/rooms/$ROOM/timeline"
    [ ! -d "$TIMELINE_DIR" ] && continue

    # Count new messages (clock > cursor, exclude self)
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
    print(f'📬 Room {\"$ROOM\"}: {len(new_messages)} 条新消息（自 clock={cursor} 以来）:')
    for m in new_messages:
        print(m)
" 2>/dev/null)

    [ -n "$NEW_MSGS" ] && echo "$NEW_MSGS"
done

exit 0
