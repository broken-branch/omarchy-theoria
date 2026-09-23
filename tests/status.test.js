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
  const url = Status.apiUrl("http://127.0.0.1:4217/?token=secret", "/api/status")
  const call = Spawn.statusCall("/usr/bin/curl", url)
  assert.equal(call.command.some(argument => argument.includes("token=")), false)
  assert.equal(call.command.join(" ").includes("secret"), false)
  assert.equal(call.input, 'url = "http://127.0.0.1:4217/api/status?token=secret"\n')
})

test("an origin-only discovery URL yields the status API URL", () => {
  assert.equal(
    Status.apiUrl("http://127.0.0.1:4217?token=secret", "/api/status"),
    "http://127.0.0.1:4217/api/status?token=secret"
  )
})

test("the open call keeps the token out of argv and puts a run in its JSON body", () => {
  const call = Spawn.openCall(
    "/usr/bin/curl",
    Status.apiUrl("http://127.0.0.1:4217/?token=secret", "/api/open"),
    { run: "run 1" }
  )
  assert.equal(call.command.some(argument => argument.includes("token=")), false)
  assert.equal(call.command.join(" ").includes("secret"), false)
  assert.deepEqual(call.command, [
    "/usr/bin/curl", "-sf", "--max-time", "2", "--max-filesize", "100000", "-K", "-"
  ])
  assert.equal(call.input,
    'url = "http://127.0.0.1:4217/api/open?token=secret"\n'
      + 'request = "POST"\n'
      + 'header = "content-type: application/json"\n'
      + 'data = "{\\"run\\":\\"run 1\\"}"\n')
})

test("the open call puts a brief in its JSON body with curl-config escaping", () => {
  const call = Spawn.openCall(
    "/usr/bin/curl",
    Status.apiUrl("http://127.0.0.1:4217/?token=secret", "/api/open"),
    { brief: "cost & speed?\nnow" }
  )
  assert.equal(call.input.includes('data = "{\\"brief\\":\\"cost & speed?\\\\nnow\\"}"'), true)
})

test("only a query-free one-time URL on the server origin is accepted", () => {
  const server = "http://127.0.0.1:4217/?token=secret"
  const url = "http://127.0.0.1:4217/open/one-time-code"
  assert.equal(Status.openUrl(JSON.stringify({ url }), server), url)
  assert.equal(Status.openUrl(JSON.stringify({ url: "http://127.0.0.1:4218/open/code" }), server), "")
  assert.equal(Status.openUrl(JSON.stringify({ url: `${url}?token=secret` }), server), "")
  assert.equal(Status.openUrl(JSON.stringify({ url: "http://127.0.0.1:4217/runs/1" }), server), "")
  assert.equal(Status.openUrl("not json", server), "")
})

test("the launcher receives only a query-free link without a token", () => {
  const launcher = "/usr/bin/omarchy-launch-webapp"
  const url = "http://127.0.0.1:4217/open/one-time-code"
  const command = Spawn.launchCommand(launcher, url)
  assert.deepEqual(command, [launcher, url])
  assert.equal(command.join(" ").includes("token="), false)
  assert.equal(Spawn.launchCommand(launcher, "http://127.0.0.1:4217/?token=secret"), null)
  assert.equal(Spawn.launchCommand(launcher, `${url}?next=home`), null)
  assert.equal(Spawn.launchCommand(launcher, "http://127.0.0.1:4217/open/token-value"), null)
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

test("a planted executable on the user's PATH is ignored", async t => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "theoria-path-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const planted = path.join(directory, "curl")
  await writeFile(planted, "fixture")
  await chmod(planted, 0o700)
  const originalPath = process.env.PATH
  process.env.PATH = `${directory}:/usr/bin`
  t.after(() => { process.env.PATH = originalPath })
  const programs = Spawn.resolvePrograms(candidate => candidate === planted || candidate === "/usr/bin/curl")
  assert.equal(programs.curl, "/usr/bin/curl")
  assert.equal(programs.node, null)
})

test("engine command addresses the private package through node", () => {
  assert.deepEqual(Spawn.engineCommand("/usr/bin/node", "/home/test"), [
    "/usr/bin/node", "/home/test/.local/share/theoria/engine/node_modules/theoria/dist/cli/main.js", "open"
  ])
  assert.equal(Status.isPinnedEngine('{"version":"2.2.1"}'), true)
  assert.equal(Status.isPinnedEngine('{"version":"2.2.2"}'), false)
  assert.equal(Status.isPinnedEngine(""), false)
  assert.equal(Status.engineInstallMessage(), "Theoria 2.2.1 is not installed — see the plugin's README")
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
