#!/usr/bin/env python3
"""rebuild-state.py — 从 Timeline 重建 State Cache

模拟 CRDT 的"状态从消息纯派生"：删除 state.json，从 timeline/*.jsonl 重放。

用法:
    python rebuild-state.py <room_dir> [<contract_dir>]

示例:
    python rebuild-state.py simulation/workspace/rooms/project-alpha

    # 指定契约目录（默认读取 room_dir/contracts/）
    python rebuild-state.py simulation/workspace/rooms/project-alpha \
        simulation/workspace/rooms/project-alpha/contracts

输入:
    - room_dir/timeline/*.jsonl   — Ref 序列
    - room_dir/config.json        — Room Config（读取 role_map + installed namespaces）
    - room_dir/contracts/*.app.md — 已安装的契约文件（读取 Flow 转换表和 Commitment）

输出:
    - room_dir/state.json         — 重建的 State Cache
"""

import json
import sys
import re
from pathlib import Path
from typing import Any


def parse_contract_flows(
    contract_path: Path,
    namespace: str,
) -> dict[str, dict[tuple[str, str], tuple[str, str]]]:
    """从契约文件解析 §2 Flow 转换表（5 列：当前状态, 动作, 下一状态, 要求角色, 能力约束）。

    返回: { "ns:flow_name": { (current_state, action): (next_state, capability_constraint) } }
    """
    text = contract_path.read_text(encoding="utf-8")
    flows: dict[str, dict[tuple[str, str], tuple[str, str]]] = {}

    # 匹配 ## §2 Flow: {name}
    flow_pattern = re.compile(r"## §2 Flow:\s*(\S+)")
    # 匹配 5 列表格行: | state | action | next_state | role | capability |
    row_pattern = re.compile(
        r"\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
    )
    # 兼容 4 列（无能力约束列的旧格式）
    row_pattern_4col = re.compile(
        r"\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$"
    )

    current_flow: str | None = None
    in_table = False

    for line in text.splitlines():
        flow_match = flow_pattern.match(line)
        if flow_match:
            raw_name = flow_match.group(1)
            current_flow = f"{namespace}:{raw_name}"
            flows[current_flow] = {}
            in_table = False
            continue

        if current_flow and line.strip().startswith("|"):
            stripped = line.strip()
            row_match = row_pattern.match(stripped)
            if row_match:
                state, action, next_state, _role, constraint = (
                    g.strip() for g in row_match.groups()
                )
                # 跳过表头和分隔行
                if state in ("当前状态", "---", "----") or "-" * 3 in state:
                    in_table = True
                    continue
                if in_table:
                    flows[current_flow][(state, action)] = (next_state, constraint)
            else:
                # 尝试 4 列兼容
                row_match_4 = row_pattern_4col.match(stripped)
                if row_match_4:
                    state, action, next_state, _role = (
                        g.strip() for g in row_match_4.groups()
                    )
                    if state in ("当前状态", "---", "----") or "-" * 3 in state:
                        in_table = True
                        continue
                    if in_table:
                        flows[current_flow][(state, action)] = (next_state, "any")
        elif current_flow and not line.strip().startswith("|") and line.strip():
            # 非表格行，Flow 段落结束
            if in_table:
                current_flow = None
                in_table = False

    return flows


def parse_contract_commitments(
    contract_path: Path,
    namespace: str,
) -> dict[str, dict[str, Any]]:
    """从契约文件解析 §3 Commitments。

    表格格式（6 列）: | C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限 |

    返回: { "ns:commitment_id": { obligation, debtor, creditor, trigger, deadline } }
    """
    text = contract_path.read_text(encoding="utf-8")
    commitments: dict[str, dict[str, Any]] = {}

    in_commitments = False
    in_table = False
    # 6 列: C-ID | 承诺 | 债务人 | 债权人 | 触发条件 | 时限
    row_pattern = re.compile(
        r"\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
    )
    # 兼容 5 列（无时限列的旧格式）
    row_pattern_5col = re.compile(
        r"\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$"
    )

    for line in text.splitlines():
        if "## §3 Commitments" in line:
            in_commitments = True
            continue
        if in_commitments and line.startswith("## "):
            break
        if in_commitments and line.strip().startswith("|"):
            stripped = line.strip()
            row_match = row_pattern.match(stripped)
            if row_match:
                cid, obligation, debtor, creditor, trigger, deadline = (
                    g.strip() for g in row_match.groups()
                )
                if cid in ("ID", "C-ID", "---", "----") or "-" * 3 in cid:
                    in_table = True
                    continue
                if in_table:
                    commitments[f"{namespace}:{cid}"] = {
                        "obligation": obligation,
                        "debtor": debtor,
                        "creditor": creditor,
                        "trigger": trigger,
                        "deadline": deadline,
                        "status": "inactive",
                        "triggered_by": None,
                        "triggered_at": None,
                    }
            else:
                # 兼容 5 列（无时限）
                row_match_5 = row_pattern_5col.match(stripped)
                if row_match_5:
                    cid, obligation, debtor, creditor, trigger = (
                        g.strip() for g in row_match_5.groups()
                    )
                    if cid in ("ID", "C-ID", "---", "----") or "-" * 3 in cid:
                        in_table = True
                        continue
                    if in_table:
                        commitments[f"{namespace}:{cid}"] = {
                            "obligation": obligation,
                            "debtor": debtor,
                            "creditor": creditor,
                            "trigger": trigger,
                            "deadline": "_待绑定_",
                            "status": "inactive",
                            "triggered_by": None,
                            "triggered_at": None,
                        }

    return commitments


def resolve_flow_instance(
    ref_id: str,
    refs_by_id: dict[str, dict[str, Any]],
    flow_states: dict[str, dict[str, Any]],
) -> str | None:
    """沿 reply_to 链回溯，找到关联的 flow instance ID。

    从当前 ref 的 reply_to 开始，逐级回溯直到找到一个已注册的 flow instance。
    """
    current = ref_id
    visited: set[str] = set()
    while current and current not in visited:
        if current in flow_states:
            return current
        visited.add(current)
        parent_ref = refs_by_id.get(current)
        if not parent_ref:
            break
        current = (parent_ref.get("ext", {}).get("reply_to") or {}).get("ref_id")
    return None


def rebuild_state(room_dir: Path, contract_dir: Path | None = None) -> dict[str, Any]:
    """从 timeline 重建 state.json。

    支持多 namespace：读取 Room 中所有已安装的 .app.md 契约文件。
    """
    if contract_dir is None:
        contract_dir = room_dir / "contracts"

    # 读取 config.json
    config_path = room_dir / "config.json"
    role_map: dict[str, str] = {}
    installed_items: list[dict[str, str]] = []
    ns_for_contract: dict[str, str] = {}  # contract filename → namespace
    if config_path.exists():
        config = json.loads(config_path.read_text(encoding="utf-8"))
        role_map = config.get("socialware", {}).get("roles", {})
        installed_items = config.get("socialware", {}).get("installed", [])
        for item in installed_items:
            if isinstance(item, dict) and "contract" in item and "namespace" in item:
                ns_for_contract[item["contract"]] = item["namespace"]

    # 解析所有已安装契约的 Flow 和 Commitment
    all_flows: dict[str, dict[tuple[str, str], tuple[str, str]]] = {}
    all_commitments: dict[str, dict[str, Any]] = {}

    if contract_dir.exists():
        for contract_file in contract_dir.glob("*.app.md"):
            # 从 config.json 的 installed 映射中查找 namespace
            filename = contract_file.name
            if filename in ns_for_contract:
                ns = ns_for_contract[filename]
            else:
                # 宽容模式：如果 config 中没有映射，从文件名推断
                ns = contract_file.stem.replace(".app", "")
            flows = parse_contract_flows(contract_file, ns)
            all_flows.update(flows)
            commitments = parse_contract_commitments(contract_file, ns)
            all_commitments.update(commitments)

    # 读取所有 timeline shards
    timeline_dir = room_dir / "timeline"
    refs: list[dict[str, Any]] = []
    if timeline_dir.exists():
        for shard_file in sorted(timeline_dir.glob("*.jsonl")):
            for line_text in shard_file.read_text(encoding="utf-8").splitlines():
                line_text = line_text.strip()
                if line_text:
                    refs.append(json.loads(line_text))

    # 按 clock 排序
    refs.sort(key=lambda r: r.get("clock", 0))

    # 建立 ref_id → ref 索引（用于 reply_to 链回溯）
    refs_by_id: dict[str, dict[str, Any]] = {}
    for ref in refs:
        refs_by_id[ref.get("ref_id", "")] = ref

    # 重放
    flow_states: dict[str, dict[str, Any]] = {}
    last_clock = 0
    peer_cursors: dict[str, int] = {}

    for ref in refs:
        clock = ref.get("clock", 0)
        author = ref.get("author", "")
        last_clock = max(last_clock, clock)
        peer_cursors[author] = max(peer_cursors.get(author, 0), clock)

        # 解析 command
        command = ref.get("ext", {}).get("command")
        if not command:
            continue

        ns = command.get("namespace", "")
        action = command.get("action", "")
        ref_id = ref.get("ref_id", "")
        reply_to = (ref.get("ext", {}).get("reply_to") or {}).get("ref_id")

        # 查找该 action 属于哪个 Flow
        for flow_name, transitions in all_flows.items():
            # 检查 namespace 匹配
            flow_ns = flow_name.split(":")[0] if ":" in flow_name else ""
            if flow_ns != ns:
                continue

            # 检查是否是 subject 动作（第一个转换）
            first_key = next(iter(transitions), None)
            if first_key and first_key[1] == action and reply_to is None:
                # subject 动作: 创建新 flow instance
                next_state, _constraint = transitions[first_key]
                flow_states[ref_id] = {
                    "flow": flow_name,
                    "state": next_state,
                    "subject_action": action,
                    "subject_author": author,
                    "last_action": action,
                    "last_ref": ref_id,
                }
                break

            # 后续动作: 沿 reply_to 链回溯找到 flow instance
            if reply_to:
                instance_id = resolve_flow_instance(
                    reply_to, refs_by_id, flow_states
                )
                if instance_id:
                    instance = flow_states[instance_id]
                    if instance["flow"] == flow_name:
                        current_state = instance["state"]
                        key = (current_state, action)
                        if key in transitions:
                            next_state, _constraint = transitions[key]
                            instance["state"] = next_state
                            instance["last_action"] = action
                            instance["last_ref"] = ref_id
                            break

        # 检查 Commitment 触发
        for cid, commitment in all_commitments.items():
            if commitment["status"] == "inactive" and commitment["trigger"] == action:
                commitment["status"] = "active"
                commitment["triggered_by"] = ref_id
                commitment["triggered_at"] = ref.get("created_at")

    state = {
        "flow_states": flow_states,
        "role_map": role_map,
        "commitments": all_commitments,
        "last_clock": last_clock,
        "peer_cursors": peer_cursors,
    }

    return state


def main() -> None:
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <room_dir> [<contract_dir>]", file=sys.stderr)
        sys.exit(1)

    room_dir = Path(sys.argv[1])
    contract_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else None

    if not room_dir.exists():
        print(f"错误: room 目录不存在: {room_dir}", file=sys.stderr)
        sys.exit(1)

    state = rebuild_state(room_dir, contract_dir)

    state_path = room_dir / "state.json"
    state_path.write_text(
        json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    ref_count = (
        sum(
            1
            for f in (room_dir / "timeline").glob("*.jsonl")
            for line in f.read_text(encoding="utf-8").splitlines()
            if line.strip()
        )
        if (room_dir / "timeline").exists()
        else 0
    )

    print(f"[rebuild] State 从 {ref_count} 条消息重建完成")
    print(f"  namespaces: {list({fs['flow'].split(':')[0] for fs in state['flow_states'].values() if ':' in fs.get('flow', '')})}")
    print(f"  flow_states: {len(state['flow_states'])} 个实例")
    print(f"  commitments: {len(state['commitments'])} 个")
    print(f"  last_clock: {state['last_clock']}")
    print(f"  写入: {state_path}")


if __name__ == "__main__":
    main()
