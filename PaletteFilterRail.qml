import QtQuick
import qs.Commons
import "Icons.js" as Icons

// Left rail: the library/source filters that used to be reachable only by
// typing a `plug-...:` prefix. Counts come from Fuzzy.counts(records).
Item {
  id: root

  property var counts: ({})
  property string activeFilter: "all"
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color urgent: Color.urgent
  property bool pointerInteractive: true
  property string footerText: ""
  property bool footerBusy: false

  signal filterPicked(string id)

  readonly property int rowHeight: Style.space(26)
  readonly property int labelHeight: Style.space(20)
  readonly property int ruleHeight: Style.space(13)
  readonly property var entries: [
    { kind: "label", id: "", label: "LIBRARY" },
    { kind: "row", id: "all", label: "All" },
    { kind: "row", id: "installed", label: "Installed" },
    { kind: "row", id: "available", label: "Available" },
    { kind: "row", id: "disabled", label: "Disabled" },
    { kind: "row", id: "updates", label: "Updates" },
    { kind: "rule", id: "", label: "" },
    { kind: "label", id: "", label: "SOURCE" },
    { kind: "row", id: "source-marketplace", label: "Marketplace" },
    { kind: "row", id: "source-local", label: "Local" }
  ]

  function countFor(id) {
    var value = counts ? counts[String(id)] : 0
    var numeric = Number(value)
    return isFinite(numeric) && numeric >= 0 ? numeric : 0
  }

  function countColor(id) {
    if (String(id) === "updates" && countFor(id) > 0) return root.accent
    return Util.alpha(root.foreground, 0.45)
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(root.foreground, 0.04)
  }

  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.max(1, Style.space(1))
    color: Util.alpha(root.foreground, 0.12)
  }

  Column {
    id: railColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm
    anchors.topMargin: Style.spacing.md
    spacing: Style.space(2)

    Repeater {
      model: root.entries

      delegate: Item {
        id: entry
        required property var modelData
        width: railColumn.width
        height: modelData.kind === "row"
          ? root.rowHeight
          : (modelData.kind === "label" ? root.labelHeight : root.ruleHeight)

        readonly property bool active: modelData.kind === "row"
          && root.activeFilter === String(modelData.id)

        Text {
          visible: entry.modelData.kind === "label"
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.md
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(4)
          text: entry.modelData.label
          textFormat: Text.PlainText
          color: Util.alpha(root.foreground, 0.38)
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: Style.spaceReal(1)
        }

        Rectangle {
          visible: entry.modelData.kind === "rule"
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.spacing.md
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          height: Math.max(1, Style.space(1))
          color: Util.alpha(root.foreground, 0.12)
        }

        Rectangle {
          visible: entry.modelData.kind === "row"
          anchors.fill: parent
          radius: Style.cornerRadius
          color: entry.active
            ? Util.alpha(root.accent, 0.14) : "transparent"

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.pointerInteractive
              ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.pointerInteractive)
              root.filterPicked(String(entry.modelData.id))
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.md
            anchors.right: entryCount.left
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            text: entry.modelData.label
            textFormat: Text.PlainText
            color: entry.active ? root.accent : root.foreground
            opacity: entry.active ? 1 : 0.72
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: entry.active
            elide: Text.ElideRight
          }

          Text {
            id: entryCount
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            text: root.countFor(entry.modelData.id)
            textFormat: Text.PlainText
            color: entry.active
              ? root.accent : root.countColor(entry.modelData.id)
            opacity: entry.active ? 0.72 : 1
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Style.spacing.md + Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm
    anchors.bottomMargin: Style.spacing.md
    spacing: Style.spacing.sm

    Text {
      text: Icons.glyph("refresh")
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, root.footerBusy ? 0.72 : 0.38)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width - x
      text: root.footerText
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.38)
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
