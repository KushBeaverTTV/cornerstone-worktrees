// Pure parsing, filtering & formatting helpers for Cornerstone Worktrees.

function ago(sec, nowSec) {
  var t = Number(sec) || 0
  if (t <= 0) return ""
  var d = Math.max(0, Math.round((Number(nowSec) || Date.now() / 1000) - t))
  if (d < 60) return "now"
  if (d < 3600) return Math.round(d / 60) + "m"
  if (d < 86400) return Math.round(d / 3600) + "h"
  return Math.round(d / 86400) + "d"
}

function parseRepos(text) {
  var d
  try { d = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!d || !Array.isArray(d.repos)) return null
  var list = d.repos.slice(0, 60).map(function(r) {
    return {
      name: String(r.name || "").slice(0, 64),
      path: String(r.path || ""),
      branch: String(r.branch || "HEAD").slice(0, 64),
      dirty: Math.max(0, parseInt(r.dirty, 10) || 0),
      ahead: Math.max(0, parseInt(r.ahead, 10) || 0),
      behind: Math.max(0, parseInt(r.behind, 10) || 0),
      worktree: r.worktree === true,
      active: Array.isArray(r.active) ? r.active.map(String).slice(0, 4) : [],
      lastCommit: parseInt(r.lastCommit, 10) || 0
    }
  })
  list.sort(function(a, b) {
    if ((b.active.length > 0) !== (a.active.length > 0)) return b.active.length > 0 ? 1 : -1
    if ((b.dirty > 0) !== (a.dirty > 0)) return b.dirty > 0 ? 1 : -1
    if (b.ahead !== a.ahead) return b.ahead - a.ahead
    return b.lastCommit - a.lastCommit
  })
  return list
}

function filterRepos(repos, mode) {
  var list = Array.isArray(repos) ? repos : []
  if (mode === "all") return list
  return list.filter(function(r) { return r.active.length > 0 || r.dirty > 0 || r.ahead > 0 })
}

function summary(repos) {
  var list = Array.isArray(repos) ? repos : []
  var dirty = 0, active = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i].dirty > 0) dirty++
    if (list[i].active.length > 0) active++
  }
  return { total: list.length, dirty: dirty, active: active }
}

if (typeof module !== "undefined") {
  module.exports = {
    ago: ago,
    parseRepos: parseRepos,
    filterRepos: filterRepos,
    summary: summary
  }
}
