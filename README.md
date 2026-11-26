# Cornerstone Worktrees

Parallel agent and Godot git branch / worktree dashboard for the Omarchy status bar.

- **Multi-root auto-discovery**: automatically scans existing directories across `~/Projects`, `~/Work`, `~/Code`, `~/dev`, and `~/src` (override with `CORNERSTONE_WORKTREES_ROOTS` or `~/.config/cornerstone-worktrees/roots`).
- **Bar pill**: `󰘬 N` showing active/dirty repo count (collapses to a single icon when everything is clean). Left-click opens the drawer; right-click forces a rescan.
- **Panel**: parallel git status scan with branch name, dirty count, ahead/behind indicators, live agent/Godot process badges, Active/All filter, and one-click open in your default Omarchy terminal (`xdg-terminal-exec`) or `lazygit`.

## Tests

```bash
node tests/run.js
```
