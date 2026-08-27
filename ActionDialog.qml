import QtQuick
import qs.Commons
import qs.Ui
import "CatalogModel.js" as CatalogModel
import "Icons.js" as Icons
import "PaletteViewModel.js" as PaletteViewModel

FocusScope {
  id: root

  property bool opened: false
  property var plugin: null
  property string selfId: ""
  property bool readOnly: false
  property bool busy: false
  property bool installInTerminal: false
  property bool previewLoading: false
  property bool previewFailed: false
  property string previewCardSource: ""
  property string previewDetailSource: ""
  property int selectedChoice: 0
  property string helpText: ""
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property color warningColor: Color.urgent
  property string fontFamily: Style.font.menuFamily
  property color marketplaceOrange: Color.accent
  property color marketplaceGreen: Color.accent
  property color marketplaceYellow: Color.accent
  property color marketplaceRed: Color.urgent

  readonly property var actions: PaletteViewModel.actionOptions(plugin, readOnly)
  readonly property var selectedAction: selectedChoice >= 0
    && selectedChoice < actions.length ? actions[selectedChoice] : null
  readonly property bool helpDelayRunning: helpDelay.running
  readonly property string selectedOperation: String(
    selectedAction && selectedAction.operation || "cancel")
  readonly property bool terminalAllowed: !readOnly && plugin
    && plugin.installable === true
    && String(plugin.repository || "").length > 0
    && String(plugin.source || "") !== "submission"
  readonly property bool terminalInstall: terminalAllowed && installInTerminal
  readonly property string reviewedCommit: String(plugin
    && (plugin.commit || plugin.listingValidatedCommit) || "")
  readonly property bool marketplaceListed: plugin
    && plugin.marketplaceListed === true
  readonly property bool listedUserPlugin: marketplaceListed
    && plugin.builtIn !== true
  readonly property bool metricsAvailable: marketplaceListed
    && plugin.metricsAvailable === true
  readonly property string verificationStatus: String(plugin
    && plugin.verificationStatus || "")
  readonly property string activityState: CatalogModel.activityState(
    plugin, Date.now())
  readonly property bool starsAvailable: root.listedUserPlugin && plugin
    && plugin.stars !== null && plugin.stars !== undefined
  readonly property string previewImageUrl: String(plugin
    && plugin.previewImageUrl || "")
  readonly property string previewThumbnailUrl: String(plugin
    && plugin.previewThumbnailUrl || previewImageUrl)
  readonly property int previewWidth: Number(plugin
    && plugin.previewWidth || 0)
  readonly property int previewHeight: Number(plugin
    && plugin.previewHeight || 0)
  readonly property bool hasPreview: readOnly
    && previewImageUrl.length > 0 && previewThumbnailUrl.length > 0
  readonly property bool previewReady: hasPreview
    && previewCardSource.length > 0 && previewDetailSource.length > 0
  readonly property int preferredReadOnlyHeight:
    Style.spacing.panelPadding * 2 + contentColumn.implicitHeight
      + Style.space(7) + Style.space(56)
  readonly property var metaRows: {
    var out = []
    var value = plugin || ({})
    out.push({ key: "Author",
      value: String(value.author || "Unknown"), tone: "" })
    out.push({ key: "Version",
      value: String(value.version || "Unknown"), tone: "" })
    out.push({ key: "Source",
      value: String(value.sourceLabel || "Unknown")
        + (String(value.warning || "")
          ? "  -  " + String(value.warning) : ""),
      tone: String(value.warning || "") ? "warn" : "" })
    if (value.installed === true)
      out.push({ key: "Checkout",
        value: "~/.config/omarchy/plugins/" + String(value.id || ""),
        tone: "dim" })
    out.push({ key: "Repository",
      value: String(value.repository || "Not supplied"), tone: "" })
    if (reviewedCommit.length > 0)
      out.push({ key: "Reviewed", value: reviewedCommit, tone: "dim" })
    return out
  }
  readonly property var badgeItems: {
    var values = []
    if (activityState === "updated") values.push({
      label: "UPDATED", color: marketplaceYellow, tooltip: "Version updated "
        + "within the last 12 hours"
    })
    else if (activityState === "new") values.push({
      label: "NEW", color: marketplaceGreen, tooltip: "Listed within the "
        + "last 12 hours"
    })
    if (listedUserPlugin) values.push({
      label: verificationStatus === "verified" ? "VERIFIED" : "UNVERIFIED",
      color: verificationStatus === "verified"
        ? marketplaceGreen : marketplaceOrange,
      tooltip: verificationHelp
    })
    return values
  }
  readonly property var metricItems: {
    var values = []
    if (starsAvailable) values.push({
      label: "stars", icon: "\uf005", value: CatalogModel.formatCount(
        plugin.stars), color: marketplaceYellow,
      tooltip: "GitHub repository stars"
    })
    if (metricsAvailable && plugin) {
      values.push({ label: "views", icon: "\uf441",
        value: CatalogModel.formatCount(plugin.views),
        color: marketplaceOrange, tooltip: "Marketplace detail views" })
      values.push({ label: "copies", icon: "\uf0c5",
        value: CatalogModel.formatCount(plugin.copies),
        color: marketplaceOrange, tooltip: "Successful command copies" })
      values.push({ label: "hearts", icon: "\uf004",
        value: CatalogModel.formatCount(plugin.hearts),
        color: marketplaceRed, tooltip: "Anonymous marketplace hearts" })
    }
    return values
  }
  readonly property string verificationHelp: verificationStatus === "verified"
    ? "Verified means automated or maintainer checks were associated with "
      + "the listed commit. It is not a security audit."
    : "Unverified means there is no current verification. It does not mean "
      + "the plugin is malicious."
  readonly property string operationText: {
    var id = String(plugin && plugin.id || "")
    if (selectedOperation === "add") return (terminalInstall
      ? "omarchy plugin add <repository> --enable"
      : "omarchy plugin add <repository> --enable --yes")
        + " && omarchy restart shell"
    if (selectedOperation === "remove")
      return "omarchy plugin remove " + id + " --yes"
    if (selectedOperation === "update")
      return "omarchy plugin update " + id
        + " --yes && omarchy restart shell"
    if (selectedOperation === "enable")
      return "omarchy plugin enable " + id
    if (selectedOperation === "disable")
      return "omarchy plugin disable " + id
    return "No system change"
  }
  readonly property bool selectedMutates: ["add", "remove", "update",
    "enable", "disable"].indexOf(selectedOperation) >= 0

  signal actionRequested(string operation)
  signal canceled()
  signal previewRequested(string url, string name, int width, int height)
  signal terminalInstallToggled(bool enabled)

  function openDialog() {
    selectedChoice = 0
    helpText = ""
    helpDelay.stop()
    contentFlick.contentY = 0
    opened = true
  }

  function closeDialog() {
    helpDelay.stop()
    helpText = ""
    opened = false
  }

  function selectChoice(index, immediateHelp) {
    if (index < 0 || index >= actions.length) return
    selectedChoice = index
    helpDelay.stop()
    helpText = ""
    var action = actions[index]
    if (action.available === false && String(action.reason || "")) {
      if (immediateHelp === true) helpText = String(action.reason)
      else helpDelay.restart()
    }
  }

  function activateChoice(index) {
    if (busy) return
    selectChoice(index, true)
    choose()
  }

  function selectOperation(operation) {
    var target = String(operation || "")
    for (var i = 0; i < actions.length; i++) {
      if (String(actions[i].operation || "") === target) {
        selectChoice(i, true)
        return true
      }
    }
    return false
  }

  function actionCaption(action) {
    if (!action) return ""
    var label = String(action.label || "")
    if (action.available === false && String(action.reason || ""))
      return label + "  -  " + String(action.reason)
    if (action.operation === "remove")
      return label + "  -  deletes the checkout and its bar entry"
    return label
  }

  function moveChoice(offset) {
    if (actions.length === 0) return
    selectChoice((selectedChoice + offset + actions.length)
      % actions.length, false)
  }

  function choose() {
    var action = selectedAction
    if (!action) return
    if (readOnly) {
      canceled()
      return
    }
    if (action.available === false) {
      selectChoice(selectedChoice, true)
      return
    }
    if (action.operation === "cancel" || action.operation === "close") {
      canceled()
      return
    }
    if (!busy) actionRequested(String(action.operation))
  }

  function handleKey(event) {
    if (!opened) return false
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
      moveChoice(-1)
      return true
    }
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      moveChoice(1)
      return true
    }
    if (event.key === Qt.Key_T && terminalAllowed && !busy) {
      terminalInstallToggled(!installInTerminal)
      return true
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        || event.key === Qt.Key_Space) {
      choose()
      return true
    }
    return true
  }

  function requestPreview() {
    if (!previewReady) return
    previewRequested(previewDetailSource,
      String(plugin && plugin.name || "Plugin preview"),
      previewWidth, previewHeight)
  }

  visible: opened

  Timer {
    id: helpDelay
    interval: 1000
    repeat: false
    onTriggered: {
      var action = root.selectedAction
      if (action && action.available === false)
        root.helpText = String(action.reason || "")
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.background
    radius: Style.cornerRadius

    Flickable {
      id: contentFlick
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.bottom: actionArea.top
      anchors.left: parent.left
      anchors.topMargin: Style.spacing.md
      anchors.rightMargin: Style.spacing.md
      anchors.bottomMargin: Style.space(6)
      anchors.leftMargin: Style.spacing.md
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: contentColumn
        width: contentFlick.width
        spacing: Style.space(5)

      Row {
        id: detailHeader
        width: parent.width
        spacing: Style.spacing.sm

        // The detail replaces the table in place, so it needs a visible way
        // back to it; Esc and the Back action do the same thing.
        Rectangle {
          id: backButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.cornerRadius
          color: Util.alpha(root.foreground,
            backHover.containsMouse ? 0.16 : 0.06)
          border.width: Math.max(1, Style.space(1))
          border.color: Util.alpha(root.foreground, 0.12)

          MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.canceled()
          }

          Text {
            anchors.centerIn: parent
            text: Icons.glyph("back")
            textFormat: Text.PlainText
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          PanelToolTip {
            visible: backHover.containsMouse
            text: "Back to the plugin list  (Esc)"
            fontFamily: root.fontFamily
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(7)
          height: width
          radius: width
          color: root.plugin && root.plugin.enabled === false
            ? Util.alpha(root.foreground, 0.34) : root.marketplaceGreen
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, detailHeader.width * 0.60)
          text: String(root.plugin && root.plugin.name || "")
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: statePillText.implicitWidth + Style.spacing.md
          height: Style.space(18)
          radius: Style.space(4)
          color: Util.alpha(root.marketplaceGreen, 0.12)

          Text {
            id: statePillText
            anchors.centerIn: parent
            text: String(root.plugin && root.plugin.stateLabel || "")
            textFormat: Text.PlainText
            color: root.marketplaceGreen
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        width: parent.width
        text: String(root.plugin && root.plugin.id || "")
        textFormat: Text.PlainText
        color: root.foreground
        opacity: 0.48
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        visible: String(root.plugin && root.plugin.description || "").length > 0
        width: parent.width
        text: String(root.plugin && root.plugin.description || "")
        textFormat: Text.PlainText
        color: root.foreground
        opacity: 0.90
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        lineHeight: 1.35
        wrapMode: Text.Wrap
        maximumLineCount: root.readOnly ? 100 : 2
        elide: root.readOnly ? Text.ElideNone : Text.ElideRight
      }

      Rectangle {
        visible: root.hasPreview
        width: parent.width
        height: visible ? Style.space(150) : 0
        radius: Style.cornerRadius
        color: root.background
        border.width: Math.max(1, Style.space(1))
        border.color: Util.alpha(root.marketplaceOrange, 0.48)
        clip: true

        Image {
          id: previewThumbnail
          anchors.fill: parent
          anchors.margins: Math.max(1, Style.space(1))
          source: root.opened && root.previewReady
            ? root.previewCardSource : ""
          asynchronous: true
          cache: true
          fillMode: Image.PreserveAspectFit
          mipmap: true
        }

        Text {
          anchors.centerIn: parent
          visible: root.hasPreview && (root.previewLoading
            || previewThumbnail.status === Image.Null
            || previewThumbnail.status === Image.Loading
            || previewThumbnail.status === Image.Error
          )
          text: root.previewFailed || (!root.previewLoading
            && previewThumbnail.status === Image.Error)
            ? "Preview could not be loaded" : "Loading preview..."
          textFormat: Text.PlainText
          color: root.foreground
          opacity: 0.72
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: previewClickArea
          anchors.centerIn: previewThumbnail
          width: previewThumbnail.paintedWidth
          height: previewThumbnail.paintedHeight
          enabled: root.previewReady
            && previewThumbnail.status === Image.Ready
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.requestPreview()
        }

        Rectangle {
          visible: previewClickArea.enabled
          anchors.right: previewClickArea.right
          anchors.bottom: previewClickArea.bottom
          anchors.margins: Style.spacing.sm
          width: previewHint.implicitWidth + Style.spacing.sm
          height: Style.space(22)
          radius: Style.space(4)
          color: Util.alpha(root.background, 0.90)
          border.width: Math.max(1, Style.space(1))
          border.color: Util.alpha(root.marketplaceOrange, 0.62)

          Text {
            id: previewHint
            anchors.centerIn: parent
            text: "\uf065  Enlarge"
            textFormat: Text.PlainText
            color: root.marketplaceOrange
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Math.max(1, Style.space(1))
        color: Util.alpha(root.foreground, 0.16)
      }

      Column {
        id: metaList
        width: parent.width
        spacing: Style.space(3)

        Repeater {
          model: root.metaRows

          delegate: Item {
            id: metaRow
            required property var modelData
            width: metaList.width
            height: Style.space(17)

            Text {
              id: metaKey
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(78)
              text: metaRow.modelData.key
              textFormat: Text.PlainText
              color: root.marketplaceOrange
              opacity: 0.88
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.left: metaKey.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: metaRow.modelData.value
              textFormat: Text.PlainText
              color: metaRow.modelData.tone === "warn"
                ? root.warningColor : root.foreground
              opacity: metaRow.modelData.tone === "dim" ? 0.60 : 0.92
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }
        }
      }

      Flow {
        id: badgeFlow
        visible: root.badgeItems.length > 0
        width: parent.width
        height: visible ? Style.space(19) : 0
        spacing: Style.space(5)

        Repeater {
          model: root.badgeItems

          delegate: Rectangle {
            id: statusBadge
            required property var modelData
            width: badgeText.implicitWidth + Style.spacing.sm
            height: Style.space(19)
            radius: Style.space(3)
            color: Util.alpha(modelData.color, 0.10)
            border.width: Math.max(1, Style.space(1))
            border.color: Util.alpha(modelData.color, 0.72)

            Text {
              id: badgeText
              anchors.centerIn: parent
              text: statusBadge.modelData.label
              textFormat: Text.PlainText
              color: statusBadge.modelData.color
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: Style.space(1)
            }

            MouseArea {
              id: badgeHover
              anchors.fill: parent
              hoverEnabled: true
            }

            PanelToolTip {
              visible: badgeHover.containsMouse
              text: String(statusBadge.modelData.tooltip || "")
              fontFamily: root.fontFamily
            }
          }
        }
      }

      Flow {
        id: metricFlow
        readonly property int columnCount: width < Style.space(560) ? 2 : 4
        readonly property real chipWidth: (width - spacing
          * (columnCount - 1)) / columnCount
        visible: root.metricItems.length > 0
        width: parent.width
        height: visible ? Math.ceil(root.metricItems.length / columnCount)
          * Style.space(28) + Math.max(0,
            Math.ceil(root.metricItems.length / columnCount) - 1) * spacing : 0
        spacing: Style.space(5)

        Repeater {
          model: root.metricItems

          delegate: Rectangle {
            id: metricChip
            required property var modelData
            width: metricFlow.chipWidth
            height: Style.space(28)
            radius: Style.cornerRadius
            color: Util.alpha(modelData.color, 0.075)
            border.width: Math.max(1, Style.space(1))
            border.color: Util.alpha(modelData.color, 0.46)

            Row {
              id: metricContent
              anchors.centerIn: parent
              height: Math.max(metricIcon.implicitHeight,
                metricLabel.implicitHeight)
              spacing: Style.space(5)

              Text {
                id: metricIcon
                height: metricContent.height
                text: metricChip.modelData.icon
                textFormat: Text.PlainText
                color: metricChip.modelData.color
                font.family: Style.font.family
                font.pixelSize: Style.font.iconSmall
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                id: metricLabel
                height: metricContent.height
                text: metricChip.modelData.value + "  "
                  + metricChip.modelData.label
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: metricHover
              anchors.fill: parent
              hoverEnabled: true
            }

            PanelToolTip {
              visible: metricHover.containsMouse
              text: String(metricChip.modelData.tooltip || "")
              fontFamily: root.fontFamily
            }
          }
        }
      }

      Text {
        visible: root.marketplaceListed && !root.metricsAvailable
        width: parent.width
        text: "Interaction totals are not cached yet"
        textFormat: Text.PlainText
        color: root.marketplaceOrange
        opacity: 0.82
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        visible: !root.marketplaceListed
        width: parent.width
        text: "Not listed on Omarchy Plugins"
        textFormat: Text.PlainText
        color: root.marketplaceOrange
        opacity: 0.82
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Flow {
        visible: root.marketplaceListed && root.plugin
          && Array.isArray(root.plugin.tags) && root.plugin.tags.length > 0
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.plugin && Array.isArray(root.plugin.tags)
            ? root.plugin.tags : []

          delegate: Rectangle {
            required property string modelData
            width: tagText.implicitWidth + Style.spacing.sm
            height: Style.space(19)
            radius: Style.space(4)
            color: Util.alpha(root.marketplaceOrange, 0.065)
            border.width: Math.max(1, Style.space(1))
            border.color: Util.alpha(root.marketplaceOrange, 0.34)

            Text {
              id: tagText
              anchors.centerIn: parent
              text: modelData
              textFormat: Text.PlainText
              color: root.marketplaceOrange
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Item {
        visible: root.terminalAllowed
        width: parent.width
        height: visible ? Style.space(24) : 0

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Run Add in Omarchy terminal  (T)"
          textFormat: Text.PlainText
          color: root.installInTerminal ? root.foreground : Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        ToggleSwitch {
          id: terminalToggle
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          trackHeight: Style.space(18)
          cursorPad: Style.space(3)
          checked: root.installInTerminal
          foreground: root.foreground
          onToggled: root.terminalInstallToggled(!checked)

          PanelToolTip {
            visible: terminalToggle.containsMouse
            text: root.installInTerminal
              ? "Use the faster background installer"
              : "Stream output and use native interactive prompts"
            fontFamily: root.fontFamily
          }
        }
      }

      Rectangle {
        visible: root.selectedMutates
        width: parent.width
        height: visible ? Style.space(root.selectedOperation === "add"
          ? 40 : 26) : 0
        radius: Style.cornerRadius
        color: Util.alpha(root.selectedOperation === "add"
          ? root.warningColor : root.foreground, 0.10)

        Text {
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          text: root.selectedOperation === "add"
            ? "Plugins run unsandboxed. Marketplace checks are not a "
              + "security audit.\n" + root.operationText
            : root.operationText
          textFormat: Text.PlainText
          color: root.selectedOperation === "add"
            ? root.warningColor : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
      }

      Rectangle {
        visible: root.helpText.length > 0
        width: parent.width
        height: visible ? Style.space(34) : 0
        radius: Style.cornerRadius
        color: Util.alpha(root.warningColor, 0.12)

        Text {
          anchors.fill: parent
          anchors.margins: Style.spacing.sm
          text: root.helpText
          textFormat: Text.PlainText
          color: root.warningColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
      }

      }
    }

    Column {
      id: actionArea
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.rightMargin: Style.spacing.md
      anchors.bottomMargin: Style.spacing.md
      anchors.leftMargin: Style.spacing.md
      spacing: Style.spacing.xs

      Row {
        id: actionRow
        width: parent.width
        height: Style.space(34)
        spacing: Style.spacing.sm

        Repeater {
          model: root.actions

          delegate: Rectangle {
            id: actionButton
            required property var modelData
            required property int index
            readonly property bool active: root.selectedChoice === index
            readonly property bool danger: modelData.dangerous === true
            width: Style.space(34)
            height: parent.height
            radius: Style.cornerRadius
            color: active
              ? root.selectedBackground
              : (danger
                ? Util.alpha(root.warningColor,
                    actionHover.containsMouse ? 0.20 : 0.10)
                : Util.alpha(root.foreground,
                    actionHover.containsMouse ? 0.14 : 0.06))
            border.width: Math.max(1, Style.space(1))
            border.color: active
              ? root.marketplaceYellow
              : (danger ? Util.alpha(root.warningColor, 0.42)
                : Util.alpha(root.foreground, 0.12))
            opacity: modelData.available === false && !active ? 0.42 : 1

            MouseArea {
              id: actionHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: actionButton.modelData.available === false
                || root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
              onEntered: root.selectChoice(actionButton.index, false)
              onClicked: root.activateChoice(actionButton.index)
            }

            PanelToolTip {
              visible: actionHover.containsMouse
              text: root.actionCaption(actionButton.modelData)
              panelBorder: actionButton.danger
                ? root.warningColor : root.marketplaceYellow
              fontFamily: root.fontFamily
            }

            Text {
              anchors.centerIn: parent
              text: root.busy && actionButton.active
                && actionButton.modelData.operation !== "cancel"
                && actionButton.modelData.operation !== "close"
                ? Icons.glyph("refresh")
                : Icons.glyph(actionButton.modelData.operation)
              textFormat: Text.PlainText
              color: actionButton.active
                ? root.selectedText
                : (actionButton.danger ? root.warningColor : root.foreground)
              font.family: Style.font.family
              font.pixelSize: Style.font.icon
            }
          }
        }
      }

      Text {
        width: parent.width
        text: root.busy ? "Working..."
          : root.actionCaption(root.selectedAction)
        textFormat: Text.PlainText
        color: root.selectedAction
          && root.selectedAction.dangerous === true
          ? root.warningColor : root.foreground
        opacity: root.busy ? 1 : 0.68
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }
}
