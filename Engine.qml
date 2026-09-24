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
  property var installCard: null
  property string openError: ""
  property string pendingRunId: ""
  property string pendingBrief: ""
  property bool pendingOpen: false
  property bool pinnedEngineInstalled: false
  property string pinnedEnginePackage: ""
  signal briefAccepted()

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string discoveryPath: home + "/.local/share/theoria/server.json"
  readonly property string enginePackagePath: home + "/.local/share/theoria/engine/node_modules/theoria/package.json"
  readonly property var inheritedEnvironment: ({
    HOME: home,
    XDG_RUNTIME_DIR: Quickshell.env("XDG_RUNTIME_DIR") || "",
    WAYLAND_DISPLAY: Quickshell.env("WAYLAND_DISPLAY") || "",
    DISPLAY: Quickshell.env("DISPLAY") || ""
  })
  readonly property var programs: Spawn.resolvePrograms(function(candidate) {
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

  function readEnginePackage(content) {
    pinnedEngineInstalled = Status.isPinnedEngine(content, pinnedEnginePackage)
    installCard = Status.installCard(content, pinnedEnginePackage, Qt.resolvedUrl("engine/package.json"))
    if (!pinnedEngineInstalled) unavailable()
    else if (pendingOpen && !live) launchEngine()
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
    if (installCard) enginePackage.reload()
    var url = Status.apiUrl(serverUrl, "/api/status")
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
      else if (serverUrl !== "") pollTimer.restart()
      return
    }
    status = parsed
    live = true
    startupError = ""
    starting = false
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
    pinnedPackage.reload()
    enginePackage.reload()
    if (!pinnedEngineInstalled) {
      unavailable()
      return
    }
    launchEngine()
  }

  function launchEngine() {
    if (missingProgram !== "") {
      startupError = "Missing program: " + missingProgram
      unavailable()
      return
    }
    if (starting) return
    starting = true
    startupError = ""
    startProcess.command = Spawn.engineCommand(programs.node, home)
    startProcess.startDetached()
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
    var url = Status.apiUrl(serverUrl, "/api/open")
    var call = Spawn.openCall(programs.curl, url, target)
    openProcess.serverUrl = serverUrl
    openProcess.input = call.input
    openProcess.stdinEnabled = true
    openProcess.command = call.command
    openProcess.running = true
  }

  function acceptOpen(output, requestedServerUrl) {
    var url = Status.openUrl(String(output || ""), requestedServerUrl)
    var command = Spawn.launchCommand(programs.launcher, url)
    var acceptedBrief = pendingBrief !== ""
    pendingOpen = false
    pendingRunId = ""
    pendingBrief = ""
    if (!command) {
      openError = Status.unexpectedOpenLinkMessage()
      return
    }
    openError = ""
    if (acceptedBrief) briefAccepted()
    launchProcess.command = command
    launchProcess.running = true
  }

  function openSetupSteps() {
    if (!programs.launcher || !installCard) return
    launchProcess.command = [programs.launcher, installCard.setupUrl]
    launchProcess.running = true
  }

  FileView {
    id: pinnedPackage
    path: Qt.resolvedUrl("engine/package.json")
    blockLoading: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.pinnedEnginePackage = text()
      enginePackage.reload()
    }
    onLoadFailed: {
      root.pinnedEnginePackage = ""
      enginePackage.reload()
    }
  }

  FileView {
    id: enginePackage
    path: root.enginePackagePath
    blockLoading: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readEnginePackage(text())
    onLoadFailed: root.readEnginePackage("")
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
    interval: (root.live && (root.panelOpen || root.status.run) ? root.refreshIntervalSec : 60) * 1000
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
