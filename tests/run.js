const assert = require("node:assert/strict")
const W = require("../Worktrees.js")

const repos = W.parseRepos(JSON.stringify({
  repos: [
    { name: "clean-old", path: "/p/clean-old", branch: "main", dirty: 0, ahead: 0, behind: 0, active: [], lastCommit: 100 },
    { name: "classified-anim", path: "/p/classified-anim", branch: "feat/anim", dirty: 3, ahead: 1, behind: 0, worktree: true, active: [], lastCommit: 200 },
    { name: "classified", path: "/p/classified", branch: "main", dirty: 0, ahead: 0, behind: 0, active: ["Godot"], lastCommit: 150 }
  ]
}))
assert.equal(repos[0].name, "classified")         // active process first
assert.equal(repos[1].name, "classified-anim")    // dirty second
assert.equal(W.filterRepos(repos, "active").length, 2)
assert.equal(W.filterRepos(repos, "all").length, 3)
assert.deepEqual(W.summary(repos), { total: 3, dirty: 1, active: 1 })
assert.equal(W.parseRepos("{"), null)

console.log("PASS cornerstone.worktrees unit tests")
