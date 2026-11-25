# Cornerstone Worktrees

Parallel agent and Godot git branch / worktree dashboard for the Omarchy status bar.

- **Bar pill**: `󰘬 N` showing active/dirty repo count across `~/Projects` (collapses to a single icon when everything is clean). Left-click opens the drawer; right-click forces a rescan.
- **Panel**: parallel git status scan across `~/Projects` with branch name, dirty count, ahead/behind indicators, Active/All filter, and one-click open in terminal or editor.

## Tests

```bash
node tests/run.js
```
