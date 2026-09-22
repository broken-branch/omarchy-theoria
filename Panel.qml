import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "status.js" as Status

Panel {
  id: root
  moduleName: "io.github.broken-branch.theoria"
  ipcTarget: "io.github.broken-branch.theoria"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property var run: engine.status.run
  readonly property string barText: Status.barLabel(run)
  property double nowMs: Date.now()

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  onOpenedChanged: {
    if (opened) {
      nowMs = Date.now()
      engine.probe()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Engine {
    id: engine
    panelOpen: root.opened
    refreshIntervalSec: Math.max(2, Number(root.setting("refreshIntervalSec", 5)) || 5)
  }

  WidgetButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    implicitWidth: root.vertical ? barSize : barContent.implicitWidth + Style.space(17)
    tooltipText: "Theoria"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) engine.openRun("")
      else root.toggle()
    }

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(7)

      Image {
        width: Style.bar.iconCanvas
        height: width
        source: Qt.resolvedUrl("assets/theoria.svg")
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
      }

      Text {
        textFormat: Text.PlainText
        visible: root.barText !== "" && !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        text: root.barText
        color: root.barForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: engine.openRun("")
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") engine.probe() }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentY + dy * Style.space(56),
                                                     panelFlick.contentHeight - panelFlick.height))
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Theoria"
            meta: root.run ? Status.firstLine(root.run.brief) : "Idle"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Image {
                width: Style.font.display
                height: width
                source: Qt.resolvedUrl("assets/theoria.svg")
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectFit
              }
            }
          }

          Text {
            visible: !engine.live || engine.openError !== ""
            width: parent.width
            text: engine.startupError || engine.openError || "Theoria is not running"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          RunCard {
            visible: engine.live && !!root.run
            width: parent.width
            run: root.run
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: briefField
                width: parent.width - startButton.width - parent.spacing
                enabled: !root.run
                placeholderText: "What do you want to know or decide?"
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: if (engine.startBrief(text)) clear()
              }

              Button {
                id: startButton
                text: "Start"
                enabled: !root.run
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: if (engine.startBrief(briefField.text)) briefField.clear()
              }
            }

            Text {
              visible: !!root.run
              width: parent.width
              text: "One run at a time — open Theoria to see it"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }

          PanelSeparator {
            visible: engine.live
            foreground: root.foreground
          }

          Column {
            visible: engine.live
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "RECENT RUNS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: engine.status.recent.length === 0
              width: parent.width
              text: "No recent runs"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            RecentRuns {
              visible: engine.status.recent.length > 0
              width: parent.width
              runs: engine.status.recent
              nowMs: root.nowMs
              foreground: root.foreground
              fontFamily: root.fontFamily
              onOpenRun: function(runId) { engine.openRun(runId) }
            }
          }

          Button {
            width: parent.width
            text: engine.starting ? "Starting Theoria…" : "Open Theoria"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: engine.openRun("")
          }
        }
      }
    }
  }
}
