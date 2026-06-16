#!/usr/bin/env python3
"""Validate data/games.json: unique ids and required, well-typed fields.

Used by CI and `make check`.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "..", "data", "games.json")

REQUIRED = ("id", "name", "year", "kind", "dir", "disks", "state")
SLOTS = {"hda", "hdb", "cdrom"}


def main():
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f)

    errors = []
    ids = set()
    for g in data.get("games", []):
        gid = g.get("id", "?")
        for key in REQUIRED:
            if key not in g:
                errors.append(f"{gid}: missing field '{key}'")
        if gid in ids:
            errors.append(f"duplicate id '{gid}'")
        ids.add(gid)
        if g.get("kind") not in ("dos", "win98"):
            errors.append(f"{gid}: kind must be 'dos' or 'win98'")
        for disk in g.get("disks", []):
            if "file" not in disk:
                errors.append(f"{gid}: a disk entry is missing 'file'")
            if not isinstance(disk.get("size"), int) or disk.get("size", 0) <= 0:
                errors.append(f"{gid}: bad size for {disk.get('file')}")
            if disk.get("slot") not in SLOTS:
                errors.append(f"{gid}: slot must be one of {sorted(SLOTS)}")

    if errors:
        print("games.json INVALID:")
        print("\n".join("  - " + e for e in errors))
        sys.exit(1)
    print(f"games.json OK ({len(data['games'])} games, {len(ids)} unique ids)")


if __name__ == "__main__":
    main()
