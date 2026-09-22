import QtQuick
import Quickshell
import Quickshell.Io
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
    if (url === "" || statusProcess.running) return
    statusProcess.command = ["curl", "-sf", "--max-time", "2", url]
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
    if (starting || startProcess.running) return
    starting = true
    startupError = ""
    // Redirect before detaching: the engine must not inherit Process's pipes,
    // which disappear when this QML object or the shell is reloaded.
    startProcess.command = ["sh", "-c", "exec setsid -f env THEORIA_NO_BROWSER=1 theoria open >/dev/null 2>&1"]
    startProcess.running = true
    discoveryRetry.start()
    startupTimeout.restart()
  }

  function launchPending() {
    if (!live || !pendingOpen || launchProcess.running) return
    var url = pendingBrief !== "" ? Status.withBrief(serverUrl, pendingBrief)
      : pendingRunId === "" ? serverUrl : Status.runUrl(serverUrl, pendingRunId)
    pendingOpen = false
    pendingRunId = ""
    pendingBrief = ""
    launchProcess.command = ["omarchy-launch-webapp", url]
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
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.acceptStatus(text)
    }
  }

  Process { id: startProcess; running: false }
  Process { id: launchProcess; running: false }

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
