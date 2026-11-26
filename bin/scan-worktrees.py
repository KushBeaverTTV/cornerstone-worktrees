#!/usr/bin/env python3
"""Parallel git worktree & active-process scanner across discovered project roots.

Auto-discovers ~/Projects, ~/Work, ~/Code, ~/dev, and ~/src (or uses paths from
CORNERSTONE_WORKTREES_ROOTS / ~/.config/cornerstone-worktrees/roots).
"""
from concurrent.futures import ThreadPoolExecutor
import glob
import json
import os
import subprocess

HOME = os.path.expanduser("~")
DEFAULT_ROOTS = ("Projects", "Work", "Code", "dev", "src")
CONFIG_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"),
    "cornerstone-worktrees",
    "roots",
)
INTERESTING_PROCS = {
    "godot": "Godot",
    "claude": "Claude",
    "codex": "Codex",
    "devin": "Devin",
    "agy": "AGY",
    "muse": "Muse",
}


def discover_roots():
    candidates = []
    env_roots = os.environ.get("CORNERSTONE_WORKTREES_ROOTS", "").strip()
    if env_roots:
        candidates = [os.path.expanduser(p.strip()) for p in env_roots.split(":") if p.strip()]
    elif os.path.isfile(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                for line in f:
                    line = line.split("#", 1)[0].strip()
                    if line:
                        candidates.append(os.path.expanduser(line))
        except Exception:
            pass
    if not candidates:
        candidates = [os.path.join(HOME, d) for d in DEFAULT_ROOTS]

    roots = []
    seen = set()
    for p in candidates:
        if os.path.isdir(p):
            rp = os.path.realpath(p)
            if rp not in seen:
                seen.add(rp)
                roots.append(rp)
    return roots


def scan_active_cwds(roots):
    """Map repo realpath -> set of interesting active tool tags."""
    by_dir = {}
    if not roots:
        return by_dir
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
            for root in roots:
                if cwd.startswith(root + "/") or cwd == root:
                    rel = cwd[len(root) + 1:].split("/", 1)[0]
                    if rel:
                        top = os.path.join(root, rel)
                        by_dir.setdefault(top, set()).add(tag)
                    break
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
    roots = discover_roots()
    if not roots:
        print(json.dumps({"repos": []}))
        return
    active_map = scan_active_cwds(roots)
    dirs = []
    seen_dirs = set()
    for root in roots:
        try:
            for entry in os.scandir(root):
                if entry.name.startswith(".") or not entry.is_dir():
                    continue
                if os.path.exists(os.path.join(entry.path, ".git")):
                    rp = os.path.realpath(entry.path)
                    if rp not in seen_dirs:
                        seen_dirs.add(rp)
                        dirs.append(rp)
        except Exception:
            pass
    repos = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        for res in pool.map(lambda p: probe_repo(p, active_map), dirs):
            if res:
                repos.append(res)
    print(json.dumps({"repos": repos}))


if __name__ == "__main__":
    main()
