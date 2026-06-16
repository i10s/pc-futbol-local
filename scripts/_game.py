#!/usr/bin/env python3
"""Read data/games.json and emit info for the shell launcher.

Modes:
    _game.py --list            -> "id<TAB>year<TAB>name" per line
    _game.py --ids             -> space separated ids
    _game.py --total <id>      -> total download bytes for a game
    _game.py --human <bytes>   -> human readable size
    _game.py <id>              -> shell-evalable variables for one game
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data", "games.json")


def load():
    with open(DATA, encoding="utf-8") as f:
        return json.load(f)


def human(n):
    n = float(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024


def find(data, gid):
    for g in data["games"]:
        if g["id"] == gid:
            return g
    return None


def sh_quote(s):
    return "'" + str(s).replace("'", "'\\''") + "'"


def main():
    args = sys.argv[1:]
    data = load()

    if not args:
        sys.exit("usage: _game.py [--list|--ids|--total ID|--human N|ID]")

    if args[0] == "--list":
        for g in data["games"]:
            print(f"{g['id']}\t{g['year']}\t{g['name']}")
        return
    if args[0] == "--ids":
        print(" ".join(g["id"] for g in data["games"]))
        return
    if args[0] == "--human":
        print(human(int(args[1])))
        return
    if args[0] == "--total":
        g = find(data, args[1])
        if not g:
            sys.exit(3)
        print(sum(d["size"] for d in g["disks"]))
        return

    gid = args[0]
    g = find(data, gid)
    if not g:
        sys.exit(3)
    files = " ".join(d["file"] for d in g["disks"])
    total = sum(d["size"] for d in g["disks"])
    print(f"GID={sh_quote(g['id'])}")
    print(f"GNAME={sh_quote(g['name'])}")
    print(f"GYEAR={sh_quote(g['year'])}")
    print(f"GKIND={sh_quote(g['kind'])}")
    print(f"GDIR={sh_quote(g['dir'])}")
    print(f"GDISKS={sh_quote(files)}")
    print(f"GSTATE={sh_quote(g['state'])}")
    print(f"GTOTAL={sh_quote(total)}")
    print(f"GTOTAL_H={sh_quote(human(total))}")


if __name__ == "__main__":
    main()
