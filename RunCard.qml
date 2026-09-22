import QtQuick
import qs.Commons
import qs.Ui
import "status.js" as Status

Column {
  id: root
  property var run: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)

  spacing: Style.space(10)

  PanelSectionHeader {
    width: parent.width
    text: root.run ? Status.stageLabel(root.run).toUpperCase() : ""
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: parent.left
      height: parent.height
      width: parent.width * Status.spendRatio(root.run ? root.run.spend : null)
      radius: height / 2
      color: root.foreground
    }
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: Status.spendText(root.run ? root.run.spend : null)
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
  }
}
