import QtQuick
import qs.Commons
import qs.Ui
import "Icons.js" as Icons

// Action strip for the selected row. Replaces the six keyboard-shortcut
// chips: every action here is an icon button, and the status line the
// palette used to carry on its own row now rides along on the right.
Item {
  id: root

  property var record: null
  property var actions: []
  property string statusText: ""
  property color statusColor: Color.menu.text
  property real statusOpacity: 0.70
  property color foreground: Color.menu.text
  property color shortcutColor: Color.accent
  property color urgent: Color.urgent
  property bool pointerInteractive: true
  property bool busy: false
  property bool statusAcknowledgeable: false
  property string hintText: ""

  signal operationRequested(string operation)
  signal infoRequested()
  signal websiteRequested()
  signal sourceRequested()
  signal statusDismissed()

  readonly property int buttonSize: Style.space(26)
  readonly property bool hasRecord: record !== null && record !== undefined
    && String(record.id || "").length > 0
  readonly property string recordName: hasRecord
    ? String(record.name || record.id || "") : ""
  readonly property var buttons: {
    var out = []
    if (!hasRecord) return out
    var values = Array.isArray(actions) ? actions : []
    for (var i = 0; i < values.length; i++) {
      var action = values[i]
      var operation = String(action.operation || "")
      if (["cancel", "close"].indexOf(operation) >= 0) continue
      out.push({
        kind: "operation",
        operation: operation,
        label: String(action.label || operation),
        available: action.available !== false,
        dangerous: action.dangerous === true,
        reason: String(action.reason || "")
      })
    }
    if (out.length > 0)
      out.push({ kind: "separator", operation: "", label: "",
        available: true, dangerous: false, reason: "" })
    out.push({ kind: "info", operation: "info", label: "Plugin info",
      available: true, dangerous: false, reason: "" })
    out.push({ kind: "website", operation: "website",
      label: "Plugin website", available: true, dangerous: false,
      reason: "" })
    out.push({ kind: "source", operation: "source",
      label: "Source repository", available: true, dangerous: false,
      reason: "" })
    return out
  }

  function iconFor(entry) {
    if (entry.kind === "operation") return Icons.glyph(entry.operation)
    return Icons.glyph(entry.kind)
  }

  function activate(entry) {
    if (!root.pointerInteractive || entry.available === false) return
    if (entry.kind === "info") root.infoRequested()
    else if (entry.kind === "website") root.websiteRequested()
    else if (entry.kind === "source") root.sourceRequested()
    else if (entry.kind === "operation")
      root.operationRequested(String(entry.operation))
  }

  Rectangle {
    anchors.top: parent.top
    width: parent.width
    height: 1
    color: Util.alpha(root.foreground, 0.16)
  }

  Text {
    id: emptyHint
    visible: !root.hasRecord
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    text: root.hintText
    textFormat: Text.PlainText
    color: root.foreground
    opacity: 0.45
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
  }

  Row {
    id: actionRow
    visible: root.hasRecord
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.sm

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, Style.space(120))
      text: root.recordName
      textFormat: Text.PlainText
      color: root.foreground
      opacity: 0.50
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Repeater {
      model: root.buttons

      delegate: Item {
        id: actionSlot
        required property var modelData
        anchors.verticalCenter: parent.verticalCenter
        width: modelData.kind === "separator"
          ? Style.spacing.sm : root.buttonSize
        height: root.buttonSize

        readonly property bool danger: modelData.dangerous === true
        readonly property bool unavailable: modelData.available === false

        Rectangle {
          visible: actionSlot.modelData.kind === "separator"
          anchors.centerIn: parent
          width: Math.max(1, Style.space(1))
          height: Style.space(16)
          color: Util.alpha(root.foreground, 0.16)
        }

        Rectangle {
          id: actionButton
          visible: actionSlot.modelData.kind !== "separator"
          anchors.fill: parent
          radius: Style.cornerRadius
          opacity: actionSlot.unavailable ? 0.38 : 1
          color: actionSlot.danger
            ? Util.alpha(root.urgent, actionHover.containsMouse ? 0.20 : 0.10)
            : Util.alpha(root.foreground,
                actionHover.containsMouse ? 0.14 : 0.06)
          border.width: Math.max(1, Style.space(1))
          border.color: actionSlot.danger
            ? Util.alpha(root.urgent, 0.42)
            : Util.alpha(root.foreground, 0.12)

          MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.pointerInteractive
              && !actionSlot.unavailable
              ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.activate(actionSlot.modelData)
          }

          Text {
            anchors.centerIn: parent
            text: root.iconFor(actionSlot.modelData)
            textFormat: Text.PlainText
            color: actionSlot.danger
              ? root.urgent
              : (actionSlot.modelData.kind === "info"
                ? root.shortcutColor : root.foreground)
            font.family: Style.font.family
            font.pixelSize: Style.font.iconSmall
          }

          PanelToolTip {
            visible: actionHover.containsMouse
            text: actionSlot.unavailable && actionSlot.modelData.reason
              ? actionSlot.modelData.label + "  -  "
                + actionSlot.modelData.reason
              : actionSlot.modelData.label
            panelBorder: actionSlot.danger
              ? root.urgent : root.shortcutColor
            fontFamily: Style.font.menuFamily
          }
        }
      }
    }
  }

  Text {
    id: statusLabel
    anchors.left: root.hasRecord ? actionRow.right : emptyHint.right
    anchors.leftMargin: Style.spacing.lg
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: parent.verticalCenter
    text: root.statusText
    textFormat: Text.PlainText
    color: root.statusColor
    opacity: root.statusOpacity
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideLeft

    MouseArea {
      anchors.fill: parent
      enabled: root.statusAcknowledgeable
      cursorShape: root.statusAcknowledgeable
        ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.statusDismissed()
    }
  }
}
