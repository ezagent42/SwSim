#!/usr/bin/env python3
"""Register a developed Socialware App in the app-store registry.

Usage:
    python3 .claude/skills/socialware-app-dev/scripts/register-app.py \
        --app-name "doc-review" \
        --developer "alice:Alice@local" \
        --socialware "two-role-submit-approve" \
        --description "文档审批工作流"

App-ID format: {AppName}.{DeveloperName}.{SocialwareName}
    - DeveloperName is extracted from developer identity (part before ':')
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REGISTRY_PATH = Path("simulation/app-store/registry.json")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Register a Socialware App in the registry"
    )
    parser.add_argument(
        "--app-name",
        required=True,
        help="Short name for the app implementation (e.g., doc-review)",
    )
    parser.add_argument(
        "--developer",
        required=True,
        help="Developer identity in {username}:{nickname}@{namespace} format",
    )
    parser.add_argument(
        "--socialware",
        required=True,
        help="Template name without .socialware.md extension",
    )
    parser.add_argument(
        "--description",
        default="",
        help="Brief description of the app",
    )
    args = parser.parse_args()

    # Extract developer username (part before ':')
    if ":" not in args.developer:
        print(
            f"Error: developer identity must be in {{username}}:{{nickname}}@{{namespace}} format, got: {args.developer}",
            file=sys.stderr,
        )
        return 1

    developer_username = args.developer.split(":")[0]

    # Compute app-id
    app_id = f"{args.app_name}.{developer_username}.{args.socialware}"

    # Read registry
    if not REGISTRY_PATH.exists():
        print(f"Error: registry file not found: {REGISTRY_PATH}", file=sys.stderr)
        return 1

    with open(REGISTRY_PATH, "r", encoding="utf-8") as f:
        registry = json.load(f)

    # Check for duplicate
    if app_id in registry["apps"]:
        print(f"Error: app-id already exists: {app_id}", file=sys.stderr)
        return 1

    # Add entry
    registry["apps"][app_id] = {
        "app_id": app_id,
        "socialware": args.socialware,
        "developer": args.developer,
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "app_file": f"{app_id}.app.md",
        "description": args.description,
    }

    # Write back (sorted keys, indent=2)
    with open(REGISTRY_PATH, "w", encoding="utf-8") as f:
        json.dump(registry, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

    # Print app-id to stdout
    print(app_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
