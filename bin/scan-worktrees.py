#!/usr/bin/env python3
"""Parallel git worktree & active-process scanner for ~/Projects."""
from concurrent.futures import ThreadPoolExecutor
import glob
import json
import os
import subprocess

ROOT = os.path.expanduser("~/Projects")
INTERESTING_PROCS = {
    "godot": "Godot",
    "claude": "Claude",
    "codex": "Codex",
    "devin": "Devin",
    "agy": "AGY",
    "muse": "Muse",
}


def scan_active_cwds():
    """Map repo realpath -> set of interesting active tool tags."""
    by_dir = {}
    for pid_dir in glob.glob("/proc/[0-9]*"):
        try:
            with open(os.path.join(pid_dir, "comm")) as f:
                comm = f.read().strip().lower()
            tag = None
            for needle, label in INTERESTING_PROCS.items():
                if needle in comm:
                    tag = label
                    break
            if not tag:
                continue
            cwd = os.path.realpath(os.path.join(pid_dir, "cwd"))
            if cwd.startswith(ROOT + "/") or cwd == ROOT:
                rel = cwd[len(ROOT) + 1:].split("/", 1)[0]
                top = os.path.join(ROOT, rel)
                by_dir.setdefault(top, set()).add(tag)
        except Exception:
            pass
    return by_dir


def probe_repo(entry_path, active_map):
    git_marker = os.path.join(entry_path, ".git")
    if not os.path.exists(git_marker):
        return None
    is_worktree = os.path.isfile(git_marker)
    try:
        r = subprocess.run(
            ["git", "-C", entry_path, "status", "--porcelain=v2", "--branch"],
            capture_output=True, text=True, timeout=2.0
        )
        if r.returncode != 0:
            return None
    except Exception:
        return None

    branch = "HEAD"
    ahead = 0
    behind = 0
    dirty = 0
    for line in r.stdout.splitlines():
        if line.startswith("# branch.head "):
            branch = line.split(" ", 2)[2].strip()
        elif line.startswith("# branch.ab "):
            parts = line.split()
            for p in parts[2:]:
                if p.startswith("+"):
                    ahead = int(p[1:])
                elif p.startswith("-"):
                    behind = int(p[1:])
        elif line and not line.startswith("#"):
            dirty += 1

    last_commit = 0
    try:
        t = subprocess.run(
            ["git", "-C", entry_path, "log", "-1", "--format=%ct"],
            capture_output=True, text=True, timeout=1.5
        )
        if t.returncode == 0 and t.stdout.strip().isdigit():
            last_commit = int(t.stdout.strip())
    except Exception:
        pass

    return {
        "name": os.path.basename(entry_path),
        "path": entry_path,
        "branch": branch,
        "dirty": dirty,
        "ahead": ahead,
        "behind": behind,
        "worktree": is_worktree,
        "active": sorted(active_map.get(entry_path, ())),
        "lastCommit": last_commit,
    }


def main():
    if not os.path.isdir(ROOT):
        print(json.dumps({"repos": []}))
        return
    active_map = scan_active_cwds()
    dirs = []
    for entry in os.scandir(ROOT):
        if entry.name.startswith(".") or not entry.is_dir():
            continue
        if os.path.exists(os.path.join(entry.path, ".git")):
            dirs.append(entry.path)
    repos = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        for res in pool.map(lambda p: probe_repo(p, active_map), dirs):
            if res:
                repos.append(res)
    print(json.dumps({"repos": repos}))


if __name__ == "__main__":
    main()
