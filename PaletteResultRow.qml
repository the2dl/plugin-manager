import QtQuick
import qs.Commons
import "Icons.js" as Icons

// One table row. Columns are fixed-width and anchored from the right so the
// name column absorbs whatever is left over.
Rectangle {
  id: root

  required property int index
  required property string pluginName
  required property string pluginId
  required property string description
  required property string author
  required property string kind
  required property string stateLabel
  required property string sourceLabel
  required property string warning
  required property string version
  required property string releaseTag
  required property string repository
  required property bool separatorBefore
  required property bool dangerous

  property bool selected: false
  property bool settingsMenuOpen: false
  property bool pointerInteractive: true
  property int rowHeight: Style.space(28)
  property color foreground: Color.menu.text
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color accent: Color.accent
  property color successColor: Color.accent
  property color urgent: Color.urgent

  readonly property int authorWidth: Style.space(118)
  readonly property int versionWidth: Style.space(54)
  readonly property int stateWidth: Style.space(78)
  readonly property int dotColumn: Style.space(16)
  readonly property bool disabledRow: stateLabel === "Disabled"
  readonly property bool updateRow: stateLabel.indexOf("Update") === 0
  readonly property color dotColor: {
    if (updateRow) return accent
    if (disabledRow) return Util.alpha(foreground, 0.34)
    if (stateLabel === "Available" || stateLabel === "Browse only")
      return Util.alpha(foreground, 0.22)
    return successColor
  }
  readonly property color bodyColor: selected ? selectedText : foreground

  signal hovered()
  signal activated()
  signal repositoryRequested(string url)

  height: rowHeight
  radius: Style.cornerRadius
  color: selected ? selectedBackground : "transparent"

  Rectangle {
    visible: root.separatorBefore
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Math.max(1, Style.space(1))
    color: Util.alpha(root.foreground, 0.18)
  }

  Rectangle {
    visible: root.selected
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.max(1, Style.space(2))
    radius: width
    color: root.accent
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.pointerInteractive
      ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: if (root.pointerInteractive) root.hovered()
    onClicked: if (root.pointerInteractive) root.activated()
  }

  // ---- settings menu reuses the row as a plain two-line entry
  Column {
    visible: root.settingsMenuOpen
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Style.spacing.md
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.pluginName
      textFormat: Text.PlainText
      color: root.dangerous && !root.selected ? root.urgent : root.bodyColor
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.description
      textFormat: Text.PlainText
      color: root.bodyColor
      opacity: 0.62
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // ---- table columns
  Rectangle {
    id: stateDot
    visible: !root.settingsMenuOpen
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(7)
    height: width
    radius: width
    color: root.dotColor
  }

  // Most catalog records carry some validation warning, so it rides as a
  // marker beside the state rather than recolouring the whole column.
  Item {
    id: stateCell
    visible: !root.settingsMenuOpen
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    width: root.stateWidth
    height: root.rowHeight

    Text {
      id: warningGlyph
      visible: root.warning.length > 0
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      // "Upstream changed" means an update is available, not a problem, so it
      // takes the accent colour and an update glyph rather than a red warning.
      text: root.warning === "Upstream changed"
        ? Icons.glyph("update") : Icons.glyph("warning")
      textFormat: Text.PlainText
      color: root.warning === "Upstream changed" ? root.accent : root.urgent
      opacity: root.selected ? 1 : 0.80
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      id: stateText
      anchors.left: warningGlyph.visible ? warningGlyph.right : parent.left
      anchors.leftMargin: warningGlyph.visible ? Style.spacing.xs : 0
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.stateLabel
      textFormat: Text.PlainText
      color: root.updateRow && !root.selected ? root.accent : root.bodyColor
      opacity: root.disabledRow && !root.selected ? 0.55 : 1
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Text {
    id: versionText
    visible: !root.settingsMenuOpen
    anchors.right: stateCell.left
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    width: root.versionWidth
    text: root.version
    textFormat: Text.PlainText
    color: root.bodyColor
    opacity: 0.58
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Text {
    id: authorText
    visible: !root.settingsMenuOpen
    anchors.right: versionText.left
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    width: root.authorWidth
    text: root.author
    textFormat: Text.PlainText
    color: root.bodyColor
    opacity: 0.58
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Row {
    visible: !root.settingsMenuOpen
    anchors.left: parent.left
    anchors.leftMargin: root.dotColumn + Style.spacing.md
    anchors.right: authorText.left
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.sm

    Text {
      id: nameText
      width: Math.min(implicitWidth, parent.width)
      text: root.pluginName
      textFormat: Text.PlainText
      color: root.dangerous && !root.selected ? root.urgent : root.bodyColor
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: root.selected
      elide: Text.ElideRight
    }

    Text {
      width: Math.max(0, parent.width - nameText.width - parent.spacing)
      text: root.pluginId
      textFormat: Text.PlainText
      color: root.bodyColor
      opacity: 0.48
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
