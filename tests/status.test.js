const assert = require("node:assert/strict")
const { execFile, spawn, spawnSync } = require("node:child_process")
const { mkdtemp, readFile, rm } = require("node:fs/promises")
const os = require("node:os")
const path = require("node:path")
const test = require("node:test")
const { promisify } = require("node:util")

const Status = require("../status.js")
const execFileAsync = promisify(execFile)

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

async function waitForDiscovery(file, child) {
  const deadline = Date.now() + 10000
  while (Date.now() < deadline) {
    if (child.exitCode !== null) throw new Error("theoria open exited before writing server.json")
    try {
      return JSON.parse(await readFile(file, "utf8"))
    } catch (error) {
      if (error.code !== "ENOENT" && !(error instanceof SyntaxError)) throw error
    }
    await new Promise(resolve => setTimeout(resolve, 50))
  }
  throw new Error("timed out waiting for server.json")
}

test("a fresh real engine reports idle with no recent runs", async t => {
  if (spawnSync("theoria", ["--help"], { stdio: "ignore" }).error) {
    t.skip("theoria is not on PATH")
    return
  }

  const home = await mkdtemp(path.join(os.tmpdir(), "theoria-bar-"))
  const child = spawn("theoria", ["open", "--port", "0"], {
    env: { ...process.env, THEORIA_NO_BROWSER: "1", THEORIA_HOME: home },
    stdio: "ignore"
  })
  const exited = new Promise(resolve => child.once("exit", resolve))
  t.after(async () => {
    if (child.exitCode === null) child.kill("SIGTERM")
    let timeout
    await Promise.race([
      exited,
      new Promise(resolve => {
        timeout = setTimeout(resolve, 2000)
        timeout.unref()
      })
    ])
    clearTimeout(timeout)
    await rm(home, { recursive: true, force: true })
  })

  const discovery = await waitForDiscovery(path.join(home, "server.json"), child)
  const { stdout } = await execFileAsync("curl", ["-sf", "--max-time", "2", Status.statusUrl(discovery.url)])
  const status = Status.parseStatus(stdout)
  assert.equal(status.run, null)
  assert.deepEqual(status.recent, [])
})
