var FIXED_PATH = "/usr/local/bin:/usr/bin:/bin"

function pathCandidates(program, pathValue) {
  return String(pathValue || "").split(":").filter(function(directory) {
    return directory.charAt(0) === "/"
  }).map(function(directory) {
    return directory.replace(/\/$/, "") + "/" + program
  })
}

function nodeExecutable(candidate) {
  if (typeof require === "undefined") return false
  try {
    var stat = require("node:fs").statSync(candidate)
    return stat.isFile() && (stat.mode & 0o111) !== 0
  } catch (error) {
    return false
  }
}

function resolveProgram(program, pathValue, isExecutable) {
  var check = isExecutable || nodeExecutable
  var candidates = pathCandidates(program, pathValue)
  for (var index = 0; index < candidates.length; index += 1) {
    if (check(candidates[index])) return candidates[index]
  }
  return null
}

function resolvePrograms(pathValue, isExecutable) {
  return {
    curl: resolveProgram("curl", pathValue, isExecutable),
    sh: resolveProgram("sh", pathValue, isExecutable),
    setsid: resolveProgram("setsid", pathValue, isExecutable),
    theoria: resolveProgram("theoria", pathValue, isExecutable),
    launcher: resolveProgram("omarchy-launch-webapp", pathValue, isExecutable)
  }
}

function missingProgram(programs) {
  var names = ["curl", "sh", "setsid", "theoria", "launcher"]
  for (var index = 0; index < names.length; index += 1) {
    if (!programs[names[index]]) {
      return names[index] === "launcher" ? "omarchy-launch-webapp" : names[index]
    }
  }
  return ""
}

function environment(kind, inherited) {
  var source = inherited || {}
  var result = {
    PATH: FIXED_PATH,
    HOME: String(source.HOME || ""),
    XDG_RUNTIME_DIR: String(source.XDG_RUNTIME_DIR || "")
  }
  if (kind === "launcher") {
    result.WAYLAND_DISPLAY = String(source.WAYLAND_DISPLAY || "")
    result.DISPLAY = String(source.DISPLAY || "")
  }
  if (kind === "engine") result.THEORIA_NO_BROWSER = "1"
  return result
}

/** The status call as one piece: the URL travels on stdin, so no caller can put the token in argv. */
function statusCall(curl, url) {
  return {
    command: [curl, "-sf", "--max-time", "2", "--max-filesize", "1000000", "-K", "-"],
    input: curlConfig(url)
  }
}

/** The open exchange as one piece: neither its token nor its target can leak into argv. */
function openCall(curl, serverUrl, target) {
  var value = String(serverUrl || "")
  var queryAt = value.indexOf("?")
  var origin = value.match(/^https?:\/\/[^/]+/)
  var url = queryAt >= 0 && origin ? origin[0] + "/api/open" + value.slice(queryAt) : ""
  return {
    command: [curl, "-sf", "--max-time", "2", "--max-filesize", "100000", "-K", "-"],
    input: curlConfig(url)
      + "request = \"POST\"\n"
      + "header = \"content-type: application/json\"\n"
      + "data = \"" + curlConfigValue(JSON.stringify(target || {})) + "\"\n"
  }
}

function launchCommand(launcher, url) {
  var value = String(url || "")
  return value === "" || value.indexOf("?") >= 0 || /token/i.test(value)
    ? null : [launcher, value]
}

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function engineCommand(programs) {
  return [programs.sh, "-c", "exec " + shellQuote(programs.setsid) + " -f "
    + shellQuote(programs.theoria) + " open >/dev/null 2>&1"]
}

function curlConfigValue(value) {
  return String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    .replace(/\r/g, "\\r").replace(/\n/g, "\\n").replace(/\t/g, "\\t")
}

function curlConfig(url) {
  return "url = \"" + curlConfigValue(url) + "\"\n"
}

if (typeof module !== "undefined") {
  module.exports = {
    FIXED_PATH: FIXED_PATH,
    pathCandidates: pathCandidates,
    resolveProgram: resolveProgram,
    resolvePrograms: resolvePrograms,
    missingProgram: missingProgram,
    environment: environment,
    statusCall: statusCall,
    openCall: openCall,
    launchCommand: launchCommand,
    engineCommand: engineCommand
  }
}
