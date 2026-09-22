const assert = require("node:assert/strict")
const { chmod, mkdtemp, rm, writeFile } = require("node:fs/promises")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")

const Spawn = require("../spawn.js")
const Status = require("../status.js")

const running = {
  id: "run-1",
  brief: "Choose a database",
  stage: "research",
  round: 2,
  waiting: null,
  spend: { tokens: 118432, tokenCeiling: 200000, costUsdEstimate: 0.4167, elapsedMs: 754000 }
}

test("bar label describes the running stage and tokens", () => {
  const status = Status.parseStatus(JSON.stringify({ run: running, recent: [] }))
  assert.equal(Status.barLabel(status.run), "Researching · 118k")
})

test("bar label says Needs you instead of the stage while waiting", () => {
  assert.equal(Status.barLabel({ ...running, waiting: "plan" }), "Needs you")
})

test("spend values use compact, user-facing units", () => {
  assert.equal(Status.formatTokens(118432), "118k")
  assert.equal(Status.formatTokens(1234567), "1.2M")
  assert.equal(Status.formatCost(0.4167), "$0.42 est")
  assert.equal(Status.formatElapsed(754000), "13 min")
})

test("recent rows are newest first and limited to five", () => {
  const rows = [1, 6, 3, 2, 7, 4, 5].map(startedAt => ({ id: String(startedAt), startedAt }))
  assert.deepEqual(Status.recentRows(rows).map(row => row.id), ["7", "6", "5", "4", "3"])
})

test("a brief URL keeps the token and carries the trimmed, encoded brief", () => {
  assert.equal(
    Status.withBrief("http://127.0.0.1:4217/?token=secret", "  cost & speed?  "),
    "http://127.0.0.1:4217/?token=secret&brief=cost%20%26%20speed%3F"
  )
})

test("a run URL keeps the token and carries the run id", () => {
  assert.equal(
    Status.runUrl("http://127.0.0.1:4217/?token=secret", "run 1"),
    "http://127.0.0.1:4217/?token=secret&run=run%201"
  )
})

test("only a loopback discovery URL with a token is accepted", () => {
  assert.equal(Status.parseDiscovery('{"url":"http://127.0.0.1:4217/?token=secret"}'), "http://127.0.0.1:4217/?token=secret")
  assert.equal(Status.parseDiscovery('{"url":"http://example.com/?token=secret"}'), "")
  assert.equal(Status.parseDiscovery("not json"), "")
})

test("the stage reads as the round while researching, and as the wait when one is needed", () => {
  assert.equal(Status.stageLabel(running), "Researching round 2")
  assert.equal(Status.stageLabel({ ...running, waiting: "card" }), "Needs you: a budget card")
  assert.equal(Status.stageLabel({ ...running, stage: "write", round: 0 }), "Writing")
})

test("the status command keeps the control token out of argv", () => {
  const url = Status.statusUrl("http://127.0.0.1:4217/?token=secret")
  const command = Spawn.statusCommand("/usr/bin/curl")
  assert.equal(command.some(argument => argument.includes("token=")), false)
  assert.equal(Spawn.curlConfig(url), 'url = "http://127.0.0.1:4217/api/status?token=secret"\n')
})

test("the resolver returns the first absolute executable and null when absent", async t => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "theoria-path-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const executable = path.join(directory, "planted")
  await writeFile(executable, "fixture")
  await chmod(executable, 0o700)

  assert.equal(Spawn.resolveProgram("planted", `${directory}:/usr/bin`), executable)
  assert.equal(Spawn.resolveProgram("missing", directory), null)
})

test("process environments contain only the allowed keys", () => {
  const inherited = {
    HOME: "/home/test",
    XDG_RUNTIME_DIR: "/run/user/1000",
    WAYLAND_DISPLAY: "wayland-1",
    DISPLAY: ":0",
    LD_PRELOAD: "/tmp/attack.so"
  }

  assert.deepEqual(Spawn.environment("status", inherited), {
    PATH: "/usr/local/bin:/usr/bin:/bin",
    HOME: "/home/test",
    XDG_RUNTIME_DIR: "/run/user/1000"
  })
  assert.deepEqual(Spawn.environment("engine", inherited), {
    PATH: "/usr/local/bin:/usr/bin:/bin",
    HOME: "/home/test",
    XDG_RUNTIME_DIR: "/run/user/1000",
    THEORIA_NO_BROWSER: "1"
  })
  assert.deepEqual(Spawn.environment("launcher", inherited), {
    PATH: "/usr/local/bin:/usr/bin:/bin",
    HOME: "/home/test",
    XDG_RUNTIME_DIR: "/run/user/1000",
    WAYLAND_DISPLAY: "wayland-1",
    DISPLAY: ":0"
  })
})
