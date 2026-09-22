import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "spawn.js" as Spawn
import "status.js" as Status

Item {
  id: root
  visible: false

  property int refreshIntervalSec: 5
  property bool panelOpen: false
  property var status: Status.emptyStatus()
  property string serverUrl: ""
  property bool live: false
  property bool starting: false
  property string startupError: ""
  property string pendingRunId: ""
  property string pendingBrief: ""
  property bool pendingOpen: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string discoveryPath: home + "/.local/share/theoria/server.json"
  readonly property var inheritedEnvironment: ({
    HOME: home,
    XDG_RUNTIME_DIR: Quickshell.env("XDG_RUNTIME_DIR") || "",
    WAYLAND_DISPLAY: Quickshell.env("WAYLAND_DISPLAY") || "",
    DISPLAY: Quickshell.env("DISPLAY") || ""
  })
  readonly property var programs: Spawn.resolvePrograms(Quickshell.env("PATH") || "", function(candidate) {
    return String(StandardPaths.findExecutable(candidate, [])) !== ""
  })
  readonly property string missingProgram: Spawn.missingProgram(programs)

  Component.onCompleted: {
    if (missingProgram !== "") {
      startupError = "Missing program: " + missingProgram
      unavailable()
    }
  }

  function unavailable() {
    live = false
    status = Status.emptyStatus()
    pollTimer.stop()
  }

  function readDiscovery(content) {
    var url = Status.parseDiscovery(content)
    if (url === "") {
      serverUrl = ""
      unavailable()
      return
    }
    serverUrl = url
    probe()
  }

  function probe() {
    var url = Status.statusUrl(serverUrl)
    if (url === "" || statusProcess.running || missingProgram !== "") return
    var call = Spawn.statusCall(programs.curl, url)
    statusProcess.input = call.input
    statusProcess.stdinEnabled = true
    statusProcess.command = call.command
    statusProcess.running = true
  }

  function acceptStatus(output) {
    var parsed = Status.parseStatus(String(output || ""))
    if (!parsed) {
      unavailable()
      if (pendingOpen) startEngine()
      return
    }
    status = parsed
    live = true
    starting = false
    startupError = ""
    pollTimer.restart()
    discoveryRetry.stop()
    startupTimeout.stop()
    if (pendingOpen) launchPending()
  }

  function requestOpen() {
    pendingOpen = true
    if (live) launchPending()
    else if (serverUrl !== "") probe()
    else startEngine()
  }

  function openRun(runId) {
    pendingRunId = String(runId || "")
    pendingBrief = ""
    requestOpen()
  }

  function startBrief(text) {
    if (String(text).trim() === "") return false
    pendingRunId = ""
    pendingBrief = String(text).trim()
    requestOpen()
    return true
  }

  function startEngine() {
    if (missingProgram !== "") {
      startupError = "Missing program: " + missingProgram
      unavailable()
      return
    }
    if (starting || startProcess.running) return
    starting = true
    startupError = ""
    // The redirect keeps the detached engine independent of this Process's pipes.
    startProcess.command = Spawn.engineCommand(programs)
    startProcess.running = true
    discoveryRetry.start()
    startupTimeout.restart()
  }

  function launchPending() {
    if (!live || !pendingOpen || openProcess.running || launchProcess.running) return
    if (missingProgram !== "") {
      startupError = "Missing program: " + missingProgram
      unavailable()
      return
    }
    var target = pendingBrief !== "" ? { brief: pendingBrief }
      : pendingRunId === "" ? {} : { run: pendingRunId }
    var call = Spawn.openCall(programs.curl, serverUrl, target)
    openProcess.serverUrl = serverUrl
    openProcess.input = call.input
    openProcess.stdinEnabled = true
    openProcess.command = call.command
    openProcess.running = true
  }

  function acceptOpen(output, requestedServerUrl) {
    var url = Status.openUrl(String(output || ""), requestedServerUrl)
    var command = Spawn.launchCommand(programs.launcher, url)
    pendingOpen = false
    pendingRunId = ""
    pendingBrief = ""
    if (!command) {
      startupError = "Open needs Theoria 2.2 or newer — npm install -g theoria"
      return
    }
    startupError = ""
    launchProcess.command = command
    launchProcess.running = true
  }

  FileView {
    id: discovery
    path: root.discoveryPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readDiscovery(text())
    onLoadFailed: {
      root.serverUrl = ""
      root.unavailable()
    }
  }

  Process {
    id: statusProcess
    property string input: ""
    running: false
    clearEnvironment: true
    environment: Spawn.environment("status", root.inheritedEnvironment)
    stdinEnabled: true
    onStarted: {
      write(input)
      input = ""
      stdinEnabled = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.acceptStatus(text)
    }
  }

  Process {
    id: startProcess
    running: false
    clearEnvironment: true
    environment: Spawn.environment("engine", root.inheritedEnvironment)
  }
  Process {
    id: openProcess
    property string input: ""
    property string serverUrl: ""
    running: false
    clearEnvironment: true
    environment: Spawn.environment("status", root.inheritedEnvironment)
    stdinEnabled: true
    onStarted: {
      write(input)
      input = ""
      stdinEnabled = false
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.acceptOpen(text, openProcess.serverUrl)
    }
  }
  Process {
    id: launchProcess
    running: false
    clearEnvironment: true
    environment: Spawn.environment("launcher", root.inheritedEnvironment)
  }

  Timer {
    id: pollTimer
    interval: (root.panelOpen || root.status.run ? root.refreshIntervalSec : 60) * 1000
    repeat: false
    onTriggered: root.probe()
  }

  // The engine writes the discovery file only once it listens, and a watch cannot follow a file that does not
  // exist yet, so a start polls for it.
  Timer {
    id: discoveryRetry
    interval: 250
    repeat: true
    onTriggered: discovery.reload()
  }

  Timer {
    id: startupTimeout
    interval: 15000
    repeat: false
    onTriggered: {
      discoveryRetry.stop()
      root.starting = false
      root.pendingOpen = false
      root.startupError = "Theoria did not start"
    }
  }
}
