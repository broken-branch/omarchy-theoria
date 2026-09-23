function emptyStatus() {
  return { run: null, recent: [] }
}

function pinnedEngineVersion(raw) {
  try {
    return JSON.parse(String(raw || "")).dependencies.theoria || ""
  } catch (error) {
    return ""
  }
}

function isPinnedEngine(raw, pinnedPackage) {
  try {
    var version = pinnedEngineVersion(pinnedPackage)
    return version !== "" && JSON.parse(String(raw || "")).version === version
  } catch (error) {
    return false
  }
}

function engineInstallMessage(pinnedPackage) {
  var version = pinnedEngineVersion(pinnedPackage)
  return "Theoria" + (version ? " " + version : "") + " is not installed — see the plugin's README"
}

function unexpectedOpenLinkMessage() {
  return "Theoria returned an unexpected link"
}

/** The status body, or null when it is not one: the caller treats null as "no engine". */
function parseStatus(raw) {
  var parsed
  try {
    parsed = typeof raw === "string" ? JSON.parse(raw) : raw
  } catch (e) {
    return null
  }
  if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.recent)) return null
  return {
    run: parsed.run && typeof parsed.run === "object" ? parsed.run : null,
    recent: parsed.recent
  }
}

function firstLine(value) {
  return String(value || "").split(/\r?\n/, 1)[0]
}

var STAGE_WORDS = {
  intake: "Clarifying",
  scope: "Planning",
  research: "Researching",
  verify: "Verifying",
  critic: "Verifying",
  decision: "Writing",
  write: "Writing"
}

var WAITING_WORDS = {
  clarify: "Needs you: a question",
  plan: "Needs you: the plan",
  card: "Needs you: a budget card"
}

function stageWord(stage) {
  return STAGE_WORDS[stage] || "Working"
}

function stageLabel(run) {
  if (!run) return ""
  if (WAITING_WORDS[run.waiting]) return WAITING_WORDS[run.waiting]
  var round = Number(run.round)
  if (run.stage === "research" && round > 0) return "Researching round " + round
  return stageWord(run.stage)
}

function barLabel(run) {
  if (!run) return ""
  if (run.waiting) return "Needs you"
  return stageWord(run.stage) + " · " + formatTokens(run.spend ? run.spend.tokens : 0)
}

function formatTokens(value) {
  var tokens = Math.max(0, Number(value) || 0)
  if (tokens >= 1000000) return (tokens / 1000000).toFixed(1).replace(/\.0$/, "") + "M"
  if (tokens >= 1000) return Math.round(tokens / 1000) + "k"
  return String(Math.round(tokens))
}

function formatCost(value) {
  var amount = Number(value)
  return "$" + (isFinite(amount) ? Math.max(0, amount) : 0).toFixed(2) + " est"
}

function formatElapsed(value) {
  return Math.round(Math.max(0, Number(value) || 0) / 60000) + " min"
}

function spendText(spend) {
  var value = spend || {}
  return formatTokens(value.tokens) + " tokens · "
    + formatCost(value.costUsdEstimate) + " · " + formatElapsed(value.elapsedMs)
}

function spendRatio(spend) {
  var value = spend || {}
  var ceiling = Number(value.tokenCeiling)
  if (!(ceiling > 0)) return 0
  return Math.max(0, Math.min(1, Number(value.tokens || 0) / ceiling))
}

function recentRows(recent) {
  return recent.slice().sort(function(a, b) {
    return Number(b.startedAt || 0) - Number(a.startedAt || 0)
  }).slice(0, 5)
}

function statusLabel(value) {
  var text = String(value || "")
  return text === "" ? "Unknown" : text.charAt(0).toUpperCase() + text.slice(1)
}

function sameLocalDay(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate()
}

function formatWhen(timestamp, nowMs) {
  var date = new Date(Number(timestamp))
  if (isNaN(date.getTime())) return ""
  var now = new Date(Number(nowMs))
  if (sameLocalDay(date, now)) {
    var hour = date.getHours()
    var suffix = hour >= 12 ? "PM" : "AM"
    var displayHour = hour % 12 || 12
    return displayHour + ":" + String(date.getMinutes()).padStart(2, "0") + " " + suffix
  }
  return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.getMonth()]
    + " " + date.getDate()
}

function parseDiscovery(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    return parsed && typeof parsed.url === "string" && /^http:\/\/127\.0\.0\.1:\d+\/?\?token=/.test(parsed.url)
      ? parsed.url : ""
  } catch (e) {
    return ""
  }
}

function apiUrl(serverUrl, path) {
  var value = String(serverUrl || "")
  var queryAt = value.indexOf("?")
  if (queryAt < 0) return ""
  var origin = value.match(/^https?:\/\/[^/?#]+/)
  return origin ? origin[0] + String(path || "") + value.slice(queryAt) : ""
}

function openUrl(body, serverUrl) {
  var parsed
  try {
    parsed = JSON.parse(String(body || ""))
  } catch (e) {
    return ""
  }
  if (!parsed || typeof parsed.url !== "string") return ""
  var origin = String(serverUrl || "").match(/^https?:\/\/[^/?#]+/)
  if (!origin || parsed.url.indexOf(origin[0]) !== 0) return ""
  var path = parsed.url.slice(origin[0].length)
  return /^\/open\/[^/?#]+$/.test(path) ? parsed.url : ""
}

if (typeof module !== "undefined") {
  module.exports = {
    isPinnedEngine: isPinnedEngine,
    engineInstallMessage: engineInstallMessage,
    unexpectedOpenLinkMessage: unexpectedOpenLinkMessage,
    emptyStatus: emptyStatus,
    parseStatus: parseStatus,
    firstLine: firstLine,
    stageLabel: stageLabel,
    barLabel: barLabel,
    formatTokens: formatTokens,
    formatCost: formatCost,
    formatElapsed: formatElapsed,
    spendText: spendText,
    spendRatio: spendRatio,
    recentRows: recentRows,
    statusLabel: statusLabel,
    formatWhen: formatWhen,
    parseDiscovery: parseDiscovery,
    apiUrl: apiUrl,
    openUrl: openUrl
  }
}
