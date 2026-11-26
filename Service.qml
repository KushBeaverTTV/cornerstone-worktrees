import QtQuick
import Quickshell
import Quickshell.Io
import "Worktrees.js" as Worktrees

// Single session-wide service for Cornerstone Worktrees: scans ~/Projects
// for git repos/worktrees and live Godot/agent processes, and owns the
// `cornerstone-worktrees` IPC target.
Item {
  id: service

  property var shell: null
  readonly property string pluginId: "cornerstone.worktrees"
  readonly property string scannerPath: Qt.resolvedUrl("bin/scan-worktrees.py").toString().replace(/^file:\/\//, "")

  property var repos: []
  property real nowSec: Date.now() / 1000
  property int watchers: 0
  property bool scanning: false

  readonly property var counts: Worktrees.summary(repos)

  function refresh() {
    if (scanProc.running) return
    scanning = true
    scanProc.running = true
  }

  function openTerminal(path) {
    if (!path) return
    Quickshell.execDetached([
      "sh", "-c",
      'cd "$1" && if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec; elif command -v omarchy-launch-terminal >/dev/null 2>&1; then exec omarchy-launch-terminal; else exec foot; fi',
      "sh", String(path)
    ])
  }

  function openLazygit(path) {
    if (!path) return
    Quickshell.execDetached(["omarchy-launch-tui", "sh", "-c", 'cd "$1" && exec lazygit', "sh", String(path)])
  }

  function copyPath(path) {
    if (!path) return
    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", String(path)])
    Quickshell.execDetached(["omarchy-shell", "dynamic-island", "toast",
      "Path copied", String(path).split("/").pop(), "󰆏", "green"])
  }

  Process {
    id: scanProc
    command: ["python3", service.scannerPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Worktrees.parseRepos(this.text)
        if (parsed) {
          service.repos = parsed
          service.nowSec = Date.now() / 1000
        }
      }
    }
    onExited: service.scanning = false
  }

  Timer {
    interval: service.watchers > 0 ? 5000 : 25000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: service.refresh()
  }

  IpcHandler {
    target: "cornerstone-worktrees"

    function toggle(): string { if (service.shell) service.shell.toggle(service.pluginId); return "ok" }
    function refresh(): string { service.refresh(); return "ok" }
  }
}
