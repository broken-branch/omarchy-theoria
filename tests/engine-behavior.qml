import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  Engine { id: engine }
  property int acceptedBriefs: 0

  Connections {
    target: engine
    function onBriefAccepted() { acceptedBriefs++ }
  }

  function fail(message) {
    console.error("engine behavior: " + message)
    Qt.exit(1)
  }

  Timer {
    interval: 500
    running: true
    onTriggered: {
      if (!engine.installCard) fail("missing engine did not show setup card")
      else install.running = true
    }
  }

  Process {
    id: install
    command: ["/usr/bin/cp", Quickshell.env("TEST_INSTALLED_PACKAGE"), engine.enginePackagePath]
    onExited: {
      // The first Open uses the package reload even though the card is still visible.
      engine.openRun("")
      verifyOpen.start()
    }
  }

  Timer {
    id: verifyOpen
    interval: 600
    onTriggered: {
      if (engine.installCard) fail("installed engine still shows setup card")
      else if (!engine.starting) fail("first Open did not start the engine")
      else {
        engine.readEnginePackage("")
        engine.probe()
        verifyProbe.start()
      }
    }
  }

  Timer {
    id: verifyProbe
    interval: 600
    onTriggered: {
      if (engine.installCard) fail("panel probe did not refresh installed package")
      else {
        engine.serverUrl = "http://127.0.0.1:4217/?token=test"
        engine.panelOpen = true
        engine.pendingOpen = false
        engine.acceptStatus("")
        if (!engine.testPollRunning) fail("failed status did not retry")
        else if (engine.testPollInterval !== 60000) fail("failed status did not use idle retry rate")
        else {
          engine.pendingBrief = "Keep this text"
          engine.pendingOpen = true
          engine.acceptOpen("invalid response", engine.serverUrl)
          if (acceptedBriefs !== 0) fail("failed open accepted the brief")
          else {
            engine.pendingBrief = "Send this text"
            engine.pendingOpen = true
            engine.acceptOpen('{"url":"http://127.0.0.1:4217/open/test-code"}', engine.serverUrl)
            if (acceptedBriefs !== 1) fail("successful open did not accept the brief")
            else {
              console.log("engine behavior: ok")
              Qt.quit()
            }
          }
        }
      }
    }
  }
}
