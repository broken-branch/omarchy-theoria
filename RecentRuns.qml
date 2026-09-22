import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "status.js" as Status

Column {
  id: root
  property var runs: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property double nowMs: Date.now()
  readonly property color dim: Qt.darker(foreground, 1.55)
  signal openRun(string runId)

  spacing: Style.space(6)

  Repeater {
    model: Status.recentRows(root.runs)

    CursorSurface {
      id: row
      required property var modelData
      width: root.width
      foreground: root.foreground
      implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: row.hasCursor = containsMouse
        onClicked: root.openRun(String(row.modelData.id || ""))
      }

      RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(10)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: Status.firstLine(row.modelData.brief) || "Untitled run"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: Status.formatWhen(row.modelData.startedAt, root.nowMs)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          textFormat: Text.PlainText
          text: Status.statusLabel(row.modelData.status)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }
      }
    }
  }
}
