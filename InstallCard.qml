import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  property var card: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.55)
  signal copyRequested()
  signal setupRequested()

  color: Style.selectedFillFor(foreground, Color.accent)
  radius: Style.cornerRadius
  implicitHeight: content.implicitHeight + Style.space(24)

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.card ? root.card.title : ""
      wrapMode: Text.WordWrap
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: root.card ? root.card.body : ""
      wrapMode: Text.WordWrap
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Rectangle {
      width: parent.width
      implicitHeight: commands.implicitHeight + Style.space(16)
      color: Qt.darker(root.color, 1.1)
      radius: Style.cornerRadius

      TextEdit {
        id: commands
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(8)
        textFormat: TextEdit.PlainText
        text: root.card ? root.card.command : ""
        wrapMode: TextEdit.WrapAnywhere
        readOnly: true
        selectByMouse: true
        color: root.foreground
        font.family: "monospace"
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      spacing: Style.space(8)

      Button {
        text: root.card ? root.card.copyLabel : ""
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.copyRequested()
      }

      Button {
        text: root.card ? root.card.setupLabel : ""
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.setupRequested()
      }
    }
  }
}
