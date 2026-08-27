import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Fuzzy.js" as Fuzzy
import "Icons.js" as Icons
import "PaletteViewModel.js" as PaletteViewModel
import "lib/shortcuts" as Shortcuts

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var service: null

  property bool opened: false
  property bool surfaceVisible: false
  property alias query: queryInput.text
  property string mode: "browse"
  property string activeFilter: "all"
  property var filterCounts: ({})
  property int selectedIndex: 0
  property var filteredRecords: []
  property var selectedRecord: null
  property string pendingOperation: "browse"
  property string pendingSnapshotId: ""
  property string transientMessage: ""
  property var targetScreen: null
  property double filterStartedAt: 0
  property bool installInTerminal: false
  property bool settingsMenuOpen: false
  property bool spaceActivatesSelection: false
  property bool previewOpen: false
  property string previewUrl: ""
  property string previewName: ""
  property int previewWidth: 0
  property int previewHeight: 0
  property var savedSettings: ({})
  property color shortcutColor: Color.accent
  property color successColor: Color.accent
  property color marketplaceOrange: Color.accent

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.ilyazar.plugin-control"
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
    || Quickshell.env("HOME") + "/.config"
  readonly property string settingsPath: configHome
    + "/omarchy/ilyazar.plugin-control/settings.json"
  readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME")
    || Quickshell.env("HOME") + "/.cache"
  readonly property string previewCacheUrlPrefix: "file://" + cacheHome
    + "/omarchy/ilyazar.plugin-control/previews/"
  readonly property string themeColorsPath: Color.currentThemePath
    + "/colors.toml"
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color borderColor: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property bool backgroundDim: service
    && service.backgroundDim === true
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property var borderSpec: Border.surfaceSpec(
    "menu", "border", borderColor, Math.max(1, Style.space(2)))
  readonly property int cardPadding: Style.space(6)
  readonly property int cardWidth: Math.min(Style.space(760),
    Math.max(Style.space(420), panel.width - Style.gapsOut * 2))
  readonly property int railWidth: Style.space(150)
  readonly property int railMinHeight: Style.space(288)
  readonly property int rowSpacing: Style.space(1)
  readonly property int rowHeight: settingsMenuOpen
    ? Style.space(44) : Style.space(28)
  readonly property int headerHeight: Style.space(46)
  readonly property int columnHeaderHeight: Style.space(22)
  readonly property int footerHeight: Style.space(38)
  readonly property bool paletteChromeVisible: !settingsMenuOpen
  // The detail replaces the table inside the same card: the search row and
  // the rail stay put, the column header and action strip fold away.
  readonly property bool detailOpen: actionDialog.opened
  readonly property int activeHeaderHeight: paletteChromeVisible
    ? headerHeight : 0
  readonly property int activeColumnHeaderHeight: paletteChromeVisible
    && !detailOpen ? columnHeaderHeight : 0
  readonly property int activeFooterHeight: paletteChromeVisible
    && !detailOpen ? footerHeight : 0
  readonly property int visibleRows: Math.max(1,
    Math.min(14, filteredRecords.length || 1))
  readonly property int resultRowsHeight: visibleRows * rowHeight
    + Math.max(0, visibleRows - 1) * rowSpacing
  readonly property int desiredCardHeight: cardPadding * 2
    + activeHeaderHeight + activeColumnHeaderHeight + resultRowsHeight
    + activeFooterHeight
  readonly property int availableCardHeight: Math.max(Style.space(180),
    panel.height - restingY - Style.gapsOut)
  readonly property int browseCardHeight: Math.min(Style.space(600),
    Math.max(paletteChromeVisible ? railMinHeight : Style.space(180),
      Math.min(desiredCardHeight, availableCardHeight)))
  // Only a floor, never growth: the card keeps its browse height unless the
  // table was so short that the detail would not be usable.
  readonly property int detailCardHeight: Math.max(browseCardHeight,
    Style.space(560))
  readonly property int cardHeight: selfRemovalDialog.opened
    ? Math.min(Style.space(280), availableCardHeight)
    : (detailOpen
      ? Math.min(detailCardHeight, availableCardHeight)
      : Math.min(browseCardHeight, availableCardHeight))
  readonly property int topBarOffset: shell && shell.bar
    && shell.bar.position === "top" && shell.bar.barHidden !== true
    ? Number(shell.bar.barSize || 0) : 0
  readonly property int restingY: topBarOffset + Style.gapsOut
  readonly property var shortcutRecord: {
    if (selectedIndex < 0 || selectedIndex >= filteredRecords.length)
      return null
    var record = filteredRecords[selectedIndex]
    return record && record.id && !record.commandCompletion ? record : null
  }
  readonly property bool shortcutHasPluginPage: shortcutRecord
    && shortcutRecord.marketplaceListed === true
  readonly property string marketplaceShortcutLabel: shortcutHasPluginPage
    ? "Plugin website" : "Marketplace"
  readonly property bool actionDialogReadOnly: actionDialog.readOnly
  readonly property bool modalDialogOpened: actionDialog.opened
    || selfRemovalDialog.opened || previewOpen
  readonly property bool hasUpdateWarnings: service
    && service.updateWarnings && service.updateWarnings.length > 0
  readonly property string updateWarningText: hasUpdateWarnings
    ? String(service.updateWarningText || "") : ""
  readonly property bool hasRefreshWarnings: service
    && service.refreshWarnings && service.refreshWarnings.length > 0
  readonly property string refreshWarningText: {
    if (!hasRefreshWarnings) return ""
    var lines = [service.refreshWarnings.length === 1
      ? "Catalog refresh warning" : "Catalog refresh warnings"]
    for (var i = 0; i < service.refreshWarnings.length; i++) {
      var warning = service.refreshWarnings[i]
      var fallback = String(warning.fallback || "")
      lines.push("")
      lines.push(String(warning.channelName || warning.channelId
        || "Catalog source"))
      if (fallback === "cache") {
        lines.push("Could not refresh this source. Using its last valid cache.")
        var retrievedAt = String(warning.cacheRetrievedAt || "")
        if (retrievedAt)
          lines.push("Last valid catalog: " + formatStatusTimestamp(retrievedAt))
      } else if (fallback === "bundled") {
        lines.push("Could not refresh this source. Using the bundled catalog.")
      } else {
        lines.push("Could not refresh this source. No cached records are available.")
      }
    }
    return lines.join("\n")
  }
  readonly property string leftStatusText: {
    if (transientMessage) return transientMessage
    if (service && service.actionRunning)
      return String(service.actionState.message || "Working...")
    if (service && service.checkingUpdates) return "Checking for updates..."
    if (service && service.actionState
        && service.actionState.acknowledged === false)
      return String(service.actionState.message || "Action finished.")
    if (service && service.lastUpdateCheckError)
      return "Update check incomplete: " + service.lastUpdateCheckError
    if (service && service.lastSuccessfulUpdateCheck) {
      var timestamp = "Last update: "
        + formatStatusTimestamp(service.lastSuccessfulUpdateCheck)
      if (service.updateCheckSuccessVisible
          && service.lastUpdateCheckNotice)
        return timestamp + "  " + service.lastUpdateCheckNotice
      return timestamp
    }
    return "Updates not checked"
  }
  readonly property string rightStatusText: {
    if (service && service.refreshing) return "Refreshing catalog..."
    if (service && service.lastError) return service.lastError
    if (service && service.lastSuccessfulRefresh)
      return "Catalog refreshed: "
        + formatStatusTimestamp(service.lastSuccessfulRefresh)
    return service && service.ready ? "Catalog cache ready" : "Loading local cache..."
  }
  readonly property bool leftStatusActive: service
    && (service.checkingUpdates
      || (service.actionRunning && ["Checking for updates...",
        "Updating plugins..."].indexOf(leftStatusText) >= 0))
  readonly property bool leftSuccessActive: service
    && ((service.updateCheckSuccessVisible === true
        && leftStatusText.indexOf("Last update: ") === 0)
      || (service.actionState && service.actionState.running !== true
        && service.actionState.acknowledged === false
        && service.actionState.ok === true))
  readonly property bool leftUrgent: service
    && ((service.actionState && service.actionState.running !== true
        && service.actionState.acknowledged === false
        && service.actionState.ok === false)
      || service.lastUpdateCheckError)
  readonly property color leftStatusColor: leftStatusActive
    ? shortcutColor : (leftSuccessActive ? successColor
      : (leftUrgent ? urgent : foreground))
  readonly property real leftStatusOpacity: leftStatusActive
    || leftSuccessActive || leftUrgent ? 1 : 0.70
  readonly property bool refreshStatusActive:
    rightStatusText === "Refreshing catalog..."
  readonly property bool refreshSuccessActive: service
    && service.refreshSuccessVisible === true
    && rightStatusText.indexOf("Catalog refreshed: ") === 0
  readonly property bool refreshStatusUrgent: service
    && service.refreshing !== true && String(service.lastError || "") !== ""
  readonly property color rightStatusColor: refreshStatusActive
    ? shortcutColor : (refreshSuccessActive ? successColor
      : (refreshStatusUrgent ? urgent : foreground))
  readonly property real rightStatusOpacity: refreshStatusActive
    || refreshSuccessActive || refreshStatusUrgent ? 1 : 0.70

  // A typed `plug-...:` command overrides the rail, so clear the rail
  // highlight rather than showing a filter that is not being applied.
  readonly property string railActiveFilter: mode === "browse"
    ? activeFilter : ""
  readonly property string railFooterText: {
    if (service && service.refreshing) return "refreshing"
    if (service && service.lastSuccessfulRefresh) {
      var instant = new Date(String(service.lastSuccessfulRefresh))
      if (isFinite(instant.getTime()))
        return padTimePart(instant.getHours()) + ":"
          + padTimePart(instant.getMinutes())
    }
    return "not refreshed"
  }
  readonly property var stripActions: shortcutRecord
    ? PaletteViewModel.actionOptions(shortcutRecord, false) : []
  readonly property bool stripUsesLeftStatus: transientMessage.length > 0
    || leftStatusActive || leftSuccessActive || leftUrgent
  readonly property string stripStatusText: stripUsesLeftStatus
    ? leftStatusText : rightStatusText
  readonly property color stripStatusColor: stripUsesLeftStatus
    ? leftStatusColor : rightStatusColor
  readonly property real stripStatusOpacity: stripUsesLeftStatus
    ? leftStatusOpacity : rightStatusOpacity
  readonly property bool stripStatusAcknowledgeable: service
    && service.actionState && service.actionState.acknowledged === false
  readonly property string stripHintText: displayModel.count > 0
    ? "Select a plugin for its actions" : ""
  readonly property int pendingUpdateCount: {
    var numeric = Number(filterCounts ? filterCounts["updates"] : 0)
    return isFinite(numeric) && numeric > 0 ? numeric : 0
  }
  readonly property string combinedWarningText: {
    var parts = []
    if (hasUpdateWarnings && !(service && service.checkingUpdates))
      parts.push(updateWarningText)
    if (hasRefreshWarnings && !(service && service.refreshing))
      parts.push(refreshWarningText)
    return parts.join("\n\n")
  }
  readonly property var headerActions: {
    var out = []
    if (combinedWarningText.length > 0)
      out.push({ action: "warning", label: combinedWarningText })
    out.push({ action: "refresh", label: "Refresh catalog" })
    out.push({ action: "updates", label: "Check for plugin updates" })
    out.push({ action: "settings", label: "Settings" })
    return out
  }
  readonly property string emptyStateText: {
    if (mode === "update") {
      if (service && service.checkingUpdates)
        return "Checking installed plugins..."
      return service && service.lastUpdateCheckError
        ? "No safely updateable plugins found"
        : "All plugins are up to date!"
    }
    if (mode === "add") return "No plugins available to add match this query"
    if (mode === "remove")
      return "No removable local plugins match this query"
    if (mode === "enable") return "No disabled plugins match this query"
    if (mode === "disable") return "No enabled plugins match this query"
    if (mode === "installed") return "No installed plugins match this query"
    if (mode === "command") return "No command matches this query"
    if (activeFilter === "updates")
      return service && service.checkingUpdates
        ? "Checking installed plugins..."
        : "No plugin updates are pending."
    if (activeFilter !== "all")
      return "No plugins in this filter match this query."
    return "No plugins match this query"
  }

  function resolveTargetScreen() {
    var focused = Hyprland.focusedMonitor
    var name = focused ? String(focused.name || "") : ""
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === name) {
        targetScreen = screens[i]
        return
      }
    }
    targetScreen = screens.length > 0 ? screens[0] : null
  }

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(String(payloadJson || "{}")) }
    catch (error) { payload = ({}) }
    resolveTargetScreen()
    if (service) service.recordOpenRequest()
    if (service) service.loadCached()
    closeTimer.stop()
    surfaceVisible = true
    if (service) service.recordSurfaceVisible()
    opened = true
    transientMessage = ""
    query = ""
    selectedIndex = 0
    selectedRecord = null
    pendingSnapshotId = ""
    settingsMenuOpen = false
    previewOpen = false
    previewUrl = ""
    actionDialog.closeDialog()
    if (payload.settings === true) showSettingsMenu()
    else rebuildResults()
    Qt.callLater(function() {
      if (settingsMenuOpen) card.forceActiveFocus()
      else queryInput.forceActiveFocus()
      if (service) service.recordFocusReady()
    })
  }

  function close() {
    if (!surfaceVisible) return
    opened = false
    settingsMenuOpen = false
    previewOpen = false
    previewUrl = ""
    actionDialog.closeDialog()
    closeTimer.interval = service && service.animationsEnabled ? 80 : 0
    closeTimer.restart()
  }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function toggle() {
    if (opened) dismiss()
    else open("{}")
  }

  function debugMetrics() {
    return JSON.stringify({
      opened: opened,
      surfaceVisible: surfaceVisible,
      serviceReadyMs: service ? service.serviceReadyMs : -1,
      openRequestMs: service ? service.lastOpenRequestMs : -1,
      focusReadyMs: service ? service.lastFocusReadyMs : -1,
      filterMs: service ? service.lastFilterMs : -1,
      refreshMs: service ? service.lastRefreshDurationMs : -1,
      recordCount: service ? service.catalogRecordCount : 0,
      cacheAgeSeconds: service ? service.cacheAgeSeconds() : -1,
      cacheRefreshedAt: service ? service.lastSuccessfulRefresh : "",
      updateCheckedAt: service ? service.lastSuccessfulUpdateCheck : ""
    })
  }

  function rebuildResults() {
    filterStartedAt = Date.now()
    var records = service && Array.isArray(service.records)
      ? service.records : []
    filterCounts = Fuzzy.counts(records)
    var result = settingsMenuOpen ? PaletteViewModel.settingsResult()
      : Fuzzy.search(records, query, 200, activeFilter)
    mode = result.mode
    filteredRecords = result.results
    displayModel.clear()
    spaceActivatesSelection = false
    for (var i = 0; i < filteredRecords.length; i++) {
      displayModel.append(PaletteViewModel.displayRecord(filteredRecords[i]))
    }
    selectedIndex = displayModel.count > 0
      ? Math.max(0, Math.min(selectedIndex, displayModel.count - 1)) : 0
    if (service) service.recordFilterDuration(Date.now() - filterStartedAt)
    Qt.callLater(positionSelection)
  }

  function positionSelection() {
    if (displayModel.count > 0)
      resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function select(index, byKeyboard) {
    if (displayModel.count === 0) return
    selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    spaceActivatesSelection = byKeyboard === true
    positionSelection()
  }

  function completeCommand(index) {
    if (index < 0 || index >= filteredRecords.length) return false
    var candidate = filteredRecords[index]
    if (!candidate) return false
    var completion = String(candidate.commandCompletion || "")
    if (!completion) return false
    queryInput.text = completion
    queryInput.cursorPosition = queryInput.text.length
    queryInput.forceActiveFocus()
    if (String(candidate.operation || "") === "update"
        && service) service.requestUpdateCheck()
    return true
  }

  function runHeaderAction(action) {
    var value = String(action || "")
    if (value === "refresh") {
      transientMessage = ""
      if (service) service.requestRefresh(true)
    } else if (value === "updates") {
      transientMessage = ""
      if (activeFilter !== "updates") setFilter("updates")
      if (service) service.requestUpdateCheck()
    } else if (value === "settings") {
      openSettings()
    }
  }

  function cycleFilter(offset) {
    var names = Fuzzy.FILTERS
    var current = names.indexOf(activeFilter)
    if (current < 0) current = 0
    var next = (current + offset + names.length) % names.length
    setFilterExact(String(names[next]))
  }

  function setFilterExact(id) {
    activeFilter = String(id || "all")
    selectedIndex = 0
    transientMessage = ""
    rebuildResults()
    Qt.callLater(queryInput.forceActiveFocus)
  }

  function setFilter(id) {
    var next = String(id || "all")
    if (!settingsMenuOpen && activeFilter === next) next = "all"
    activeFilter = next
    selectedIndex = 0
    transientMessage = ""
    if (settingsMenuOpen) closeSettingsMenu()
    else rebuildResults()
    Qt.callLater(queryInput.forceActiveFocus)
  }

  function requestStripOperation(operation) {
    if (!openDialogFor(shortcutRecord, false)) return
    actionDialog.selectOperation(String(operation))
  }

  function openDialogFor(record, readOnly) {
    if (!record || !record.id || record.commandCompletion) return false
    selectedRecord = JSON.parse(JSON.stringify(record))
    if (service) service.requestAudit(selectedRecord)
    pendingOperation = "browse"
    pendingSnapshotId = readOnly === true ? ""
      : (service && service.snapshot
          ? String(service.snapshot.snapshotId || "") : "")
    actionDialog.readOnly = readOnly === true
    if (readOnly === true && service) service.requestPreview(selectedRecord)
    actionDialog.openDialog()
    return true
  }

  function activateIndex(index) {
    if (index < 0 || index >= filteredRecords.length) return
    if (filteredRecords[index].settingsAction) {
      activateSettings(filteredRecords[index].settingsAction)
      return
    }
    if (completeCommand(index)) return
    var record = filteredRecords[index]
    openDialogFor(record, false)
  }

  function openSelectedInfo() {
    return openDialogFor(shortcutRecord, true)
  }

  function validPreviewUrl(value) {
    var url = String(value || "")
    if (url.indexOf(previewCacheUrlPrefix) !== 0) return false
    return /^[A-Za-z0-9._-]+-detail-[a-f0-9]{16}\.png$/.test(
      url.slice(previewCacheUrlPrefix.length))
  }

  function openPreview(url, name, width, height) {
    if (!actionDialog.readOnly || !validPreviewUrl(url)) return false
    previewUrl = String(url)
    previewName = String(name || "Plugin")
    previewWidth = Math.max(0, Math.min(10000, Number(width || 0)))
    previewHeight = Math.max(0, Math.min(10000, Number(height || 0)))
    previewOpen = true
    return true
  }

  function closePreview() {
    if (!previewOpen) return
    previewOpen = false
    previewUrl = ""
  }

  function handlePreviewKey(event) {
    if (!previewOpen) return false
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        || event.key === Qt.Key_Space) closePreview()
    return true
  }

  function confirmAction(operation) {
    if (actionDialog.readOnly || !selectedRecord || !service) return
    pendingOperation = String(operation || "")
    if (["add", "remove", "update", "enable", "disable"]
        .indexOf(pendingOperation) < 0) return
    if (pendingOperation === "remove"
        && String(selectedRecord.id || "") === pluginId) {
      actionDialog.closeDialog()
      openSelfRemovalDialog()
      return
    }
    if (!pendingSnapshotId) {
      transientMessage = "No actionable catalog snapshot is available."
      actionDialog.closeDialog()
      return
    }
    var executionMode = actionDialog.terminalInstall
      ? "terminal" : "background"
    if (service.startAction(pendingOperation,
        String(selectedRecord.id || ""), pendingSnapshotId, executionMode)) {
      transientMessage = executionMode === "terminal"
        ? "Opening Omarchy terminal..." : ""
      actionDialog.closeDialog()
      if (executionMode === "terminal") dismiss()
      else Qt.callLater(queryInput.forceActiveFocus)
    }
  }

  function deletePreviousWord(value) {
    var text = String(value || "")
    var trimmed = text.replace(/\s+$/, "")
    return trimmed.replace(/\S+$/, "")
  }

  function loadSettings(raw) {
    try {
      var value = JSON.parse(String(raw || "{}"))
      savedSettings = value && typeof value === "object"
        && !Array.isArray(value) ? value : ({})
    } catch (error) {
      savedSettings = ({})
    }
    installInTerminal = savedSettings.installInTerminal === true
  }

  function setInstallInTerminal(enabled) {
    var next = ({ installInTerminal: enabled === true })
    savedSettings = next
    installInTerminal = next.installInTerminal
    settingsFile.setText(JSON.stringify(next, null, 2) + "\n")
  }

  function padTimePart(value) {
    return Number(value) < 10 ? "0" + Number(value) : String(Number(value))
  }

  function formatStatusTimestamp(value) {
    var instant = new Date(String(value || ""))
    if (!isFinite(instant.getTime())) return String(value || "")
    var time = padTimePart(instant.getHours()) + ":"
      + padTimePart(instant.getMinutes()) + ":"
      + padTimePart(instant.getSeconds())
    var date = instant.getFullYear() + "-"
      + padTimePart(instant.getMonth() + 1) + "-"
      + padTimePart(instant.getDate())
    return time + " (" + date + ")"
  }

  function loadStatusColors(raw) {
    var yellowMatch = String(raw || "").match(
      /^\s*(?:yellow|color3)\s*=\s*["']?(#[0-9A-Fa-f]{6})/im)
    var greenMatch = String(raw || "").match(
      /^\s*(?:green|color2)\s*=\s*["']?(#[0-9A-Fa-f]{6})/im)
    var orangeMatch = String(raw || "").match(
      /^\s*orange\s*=\s*["']?(#[0-9A-Fa-f]{6})/im)
    shortcutColor = yellowMatch ? yellowMatch[1] : accent
    successColor = greenMatch ? greenMatch[1] : accent
    marketplaceOrange = orangeMatch ? orangeMatch[1] : accent
  }

  function launchDeepScan() {
    if (!selectedRecord || !service) return
    var id = String(selectedRecord.id || "")
    var installed = selectedRecord.installed === true
      || selectedRecord.builtIn === true
    if (!id || !installed) return
    var dir = service.pluginsRoot + "/" + id
    transientMessage = "Opening the agent to review " + id + "..."
    // Hand the plugin and the static report to the configured coding agent.
    // plugin-audit-review re-runs the static pass, builds the prompt from it,
    // and launches `omarchy agent` in its own terminal.
    Quickshell.execDetached([sourcePath("bin/plugin-audit-review"), dir])
    dismiss()
  }

  function openWebsite(url) {
    dismiss()
    Quickshell.execDetached([omarchyPath + "/bin/omarchy", "launch",
      "browser", url])
  }

  function validGithubRepository(value) {
    return /^https:\/\/github\.com\/[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}\/?$/
      .test(String(value || ""))
  }

  function marketplaceShortcutUrl() {
    if (!shortcutHasPluginPage) return "https://omarchyplugins.com/"
    return "https://omarchyplugins.com/plugin.html?id="
      + encodeURIComponent(String(shortcutRecord.id))
  }

  function githubShortcutUrl() {
    if (shortcutRecord && validGithubRepository(shortcutRecord.repository))
      return String(shortcutRecord.repository).replace(/\/$/, "")
    return "https://github.com/HANCORE-linux/omarchy-plugin-marketplace"
  }

  function openMarketplaceShortcut() {
    openWebsite(marketplaceShortcutUrl())
  }

  function openGithubShortcut() {
    openWebsite(githubShortcutUrl())
  }

  function openSettings() {
    showSettingsMenu()
  }

  function showSettingsMenu() {
    settingsMenuOpen = true
    queryInput.text = ""
    selectedIndex = 0
    rebuildResults()
    Qt.callLater(card.forceActiveFocus)
  }

  function closeSettingsMenu() {
    settingsMenuOpen = false
    queryInput.text = ""
    selectedIndex = 0
    rebuildResults()
    Qt.callLater(queryInput.forceActiveFocus)
  }

  function returnToMainMenu() {
    if (!modalDialogOpened && !settingsMenuOpen) return false
    var resetSelection = settingsMenuOpen
    previewOpen = false
    previewUrl = ""
    selfRemovalDialog.closeDialog()
    actionDialog.closeDialog()
    settingsMenuOpen = false
    if (resetSelection) {
      selectedIndex = 0
      rebuildResults()
    }
    Qt.callLater(queryInput.forceActiveFocus)
    return true
  }

  function activateSettings(action) {
    if (action === "cancel") {
      closeSettingsMenu()
      return
    }
    if (action === "remove-self") {
      openSelfRemovalDialog()
      return
    }
    if (["plugin", "keybindings"].indexOf(String(action)) < 0) return
    dismiss()
    Quickshell.execDetached([sourcePath("scripts/open-settings.sh"),
      String(action), sourceDir()])
  }

  function openSelfRemovalDialog() {
    if (!service || !Array.isArray(service.records) || !service.snapshot
        || !service.snapshot.snapshotId) {
      transientMessage = "No current plugin snapshot is available."
      return false
    }
    var record = PaletteViewModel.removableRecord(service.records, pluginId)
    if (record) {
      selectedRecord = JSON.parse(JSON.stringify(record))
      pendingSnapshotId = String(service.snapshot.snapshotId)
      selfRemovalDialog.openDialog()
      return true
    }
    transientMessage = "Plugin Control is not available for removal."
    return false
  }

  function confirmSelfRemoval(deleteUserData) {
    if (!service || !selectedRecord || !pendingSnapshotId) return
    var operation = deleteUserData === true ? "remove-purge" : "remove"
    if (service.startAction(operation, pluginId, pendingSnapshotId,
        "background")) {
      transientMessage = deleteUserData === true
        ? "Cleaning user data and removing Plugin Control..."
        : "Removing Plugin Control and preserving user data..."
      selfRemovalDialog.closeDialog()
      if (!settingsMenuOpen) Qt.callLater(queryInput.forceActiveFocus)
    }
  }

  function dismissStatus() {
    transientMessage = ""
    if (service) service.acknowledgeAction()
  }

  function sourceDir() {
    return manifest && manifest.__sourceDir
      ? String(manifest.__sourceDir) : ""
  }

  function sourcePath(relative) {
    return sourceDir() + "/" + relative
  }

  function isControlShortcut(event, key) {
    return event.modifiers === Qt.ControlModifier && event.key === key
  }

  function isCompletedCommandPrefix(value, cursor, selectionStart,
      selectionEnd) {
    var text = String(value || "")
    return cursor === text.length && selectionStart === selectionEnd
      && ["plug-add:", "plug-remove:", "plug-enable:", "plug-disable:",
        "plug-update:"].indexOf(text) >= 0
  }

  function clearCompletedCommandPrefix() {
    if (!isCompletedCommandPrefix(queryInput.text, queryInput.cursorPosition,
        queryInput.selectionStart, queryInput.selectionEnd)) return false
    queryInput.text = ""
    queryInput.cursorPosition = 0
    return true
  }

  function startTypedUpdateCommand() {
    var current = String(queryInput.text || "")
    if (/\s$/.test(current) || current.trim().toLowerCase()
        !== "plug-update:") return false
    queryInput.text = "plug-update: "
    queryInput.cursorPosition = queryInput.text.length
    if (service) service.requestUpdateCheck()
    return true
  }

  function handleKey(event) {
    var returnKey = event.key === Qt.Key_Escape
      || (event.modifiers === Qt.NoModifier && event.key === Qt.Key_Q)
    if (returnKey) {
      if (returnToMainMenu()) return true
      if (event.key === Qt.Key_Escape) {
        dismiss()
        return true
      }
      return false
    }
    if (previewOpen) return handlePreviewKey(event)
    if (selfRemovalDialog.opened) return selfRemovalDialog.handleKey(event)
    if (actionDialog.opened) return actionDialog.handleKey(event)
    var control = (event.modifiers & Qt.ControlModifier) !== 0
    var alt = (event.modifiers & Qt.AltModifier) !== 0

    if (settingsMenuOpen) {
      if (event.key === Qt.Key_Up
          || (event.modifiers === Qt.NoModifier && event.key === Qt.Key_K))
        select(selectedIndex - 1, true)
      else if (event.key === Qt.Key_Down
          || (event.modifiers === Qt.NoModifier && event.key === Qt.Key_J))
        select(selectedIndex + 1, true)
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        activateIndex(selectedIndex)
      return true
    }

    if (isControlShortcut(event, Qt.Key_P)) {
      dismiss()
    } else if (isControlShortcut(event, Qt.Key_I)) {
      openSelectedInfo()
    } else if (isControlShortcut(event, Qt.Key_W)) {
      openMarketplaceShortcut()
    } else if (isControlShortcut(event, Qt.Key_G)) {
      openGithubShortcut()
    } else if (isControlShortcut(event, Qt.Key_F)) {
      cycleFilter(1)
    } else if (isControlShortcut(event, Qt.Key_S)) {
      openSettings()
    } else if (isControlShortcut(event, Qt.Key_R)) {
      transientMessage = ""
      if (service) service.requestRefresh(true)
    } else if (isControlShortcut(event, Qt.Key_U)) {
      transientMessage = ""
      queryInput.text = "plug-update: "
      queryInput.cursorPosition = queryInput.text.length
      if (service) service.requestUpdateCheck()
    } else if (isControlShortcut(event, Qt.Key_Backspace)) {
      queryInput.text = deletePreviousWord(queryInput.text)
    } else if (event.modifiers === Qt.NoModifier
        && event.key === Qt.Key_Backspace) {
      return clearCompletedCommandPrefix()
    } else if (event.key === Qt.Key_Up) {
      select(selectedIndex - 1, true)
    } else if (event.key === Qt.Key_Down) {
      select(selectedIndex + 1, true)
    } else if (event.key === Qt.Key_PageUp) {
      select(selectedIndex - 5, true)
    } else if (event.key === Qt.Key_PageDown) {
      select(selectedIndex + 5, true)
    } else if (event.key === Qt.Key_Home) {
      select(0, true)
    } else if (event.key === Qt.Key_End) {
      select(displayModel.count - 1, true)
    } else if (!control && !alt && event.key === Qt.Key_Tab) {
      if (!startTypedUpdateCommand()) completeCommand(selectedIndex)
    } else if (event.key === Qt.Key_Space) {
      if (!startTypedUpdateCommand()) {
        if (!spaceActivatesSelection) return false
        activateIndex(selectedIndex)
      }
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (!startTypedUpdateCommand()) activateIndex(selectedIndex)
    } else {
      return false
    }
    return true
  }

  ListModel { id: displayModel }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
    onFileChanged: reload()
  }

  FileView {
    id: themeColorsFile
    path: root.themeColorsPath
    watchChanges: false
    printErrors: false
    onLoaded: root.loadStatusColors(text())
  }

  Connections {
    target: Color
    function onShellValuesChanged() { themeColorsFile.reload() }
  }

  Shortcuts.HyprlandBinding {
    id: paletteBinding
    actionDescription: "Plugin Control"
  }

  Connections {
    target: root.service
    function onRecordsChanged() { root.rebuildResults() }
    function onActionFinished(state) {
      root.transientMessage = ""
      root.rebuildResults()
    }
  }

  Timer {
    id: closeTimer
    repeat: false
    onTriggered: root.surfaceVisible = false
  }

  PanelWindow {
    id: panel
    visible: root.surfaceVisible
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ilyazar.plugin-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.surfaceVisible
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      visible: root.backgroundDim
      color: root.scrim
      opacity: card.reveal
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.ArrowCursor
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      property real reveal: root.opened ? 1 : 0

      width: root.cardWidth
      height: root.cardHeight
      x: Math.round((panel.width - width) / 2)

      Behavior on height {
        NumberAnimation {
          duration: root.service && root.service.animationsEnabled ? 110 : 0
          easing.type: Easing.OutCubic
        }
      }

      y: root.restingY - Math.round((1 - reveal) * Style.space(18))
      opacity: reveal
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.cardPadding
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (root.handleKey(event)) event.accepted = true
      }

      Behavior on reveal {
        enabled: root.service ? root.service.animationsEnabled : true
        NumberAnimation {
          duration: root.opened ? 110 : 75
          easing.type: Easing.OutCubic
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: {}
      }

      SelfRemovalDialog {
        id: selfRemovalDialog
        anchors.fill: parent
        z: 30
        busy: root.service ? root.service.actionRunning : false
        background: root.background
        foreground: root.foreground
        selectedBackground: root.selectedBackground
        selectedText: root.selectedText
        warningColor: root.urgent
        onCanceled: {
          closeDialog()
          if (!root.settingsMenuOpen)
            Qt.callLater(queryInput.forceActiveFocus)
        }
        onRemoveRequested: function(deleteUserData) {
          root.confirmSelfRemoval(deleteUserData)
        }
      }

      Row {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.cardPadding

        PaletteFilterRail {
          id: filterRail
          visible: root.paletteChromeVisible
          width: visible ? root.railWidth : 0
          height: parent.height
          counts: root.filterCounts
          activeFilter: root.railActiveFilter
          foreground: root.foreground
          accent: root.accent
          urgent: root.urgent
          pointerInteractive: !root.modalDialogOpened
          footerText: root.railFooterText
          footerBusy: root.service ? root.service.refreshing === true : false
          onFilterPicked: function(id) { root.setFilter(id) }
        }

        Column {
          id: tableColumn
          width: parent.width
            - (filterRail.visible ? filterRail.width + parent.spacing : 0)
          height: parent.height
          spacing: 0

          Item {
            id: headerArea
            visible: root.paletteChromeVisible
            width: parent.width
            height: root.activeHeaderHeight

            Rectangle {
              anchors.left: parent.left
              anchors.right: headerActions.left
              anchors.rightMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(32)
              radius: Style.cornerRadius
              color: Util.alpha(root.foreground, 0.06)
              border.width: Math.max(1, Style.space(1))
              border.color: Util.alpha(root.foreground, 0.09)

              Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.glyph("search")
                textFormat: Text.PlainText
                color: root.foreground
                opacity: 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.iconSmall
              }

              TextInput {
                id: queryInput
                anchors.left: searchIcon.right
                anchors.leftMargin: Style.spacing.sm
                anchors.right: shortcutLabel.left
                anchors.rightMargin: Style.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                color: root.foreground
                selectionColor: root.selectedBackground
                selectedTextColor: root.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                clip: true
                readOnly: root.settingsMenuOpen
                selectByMouse: true
                activeFocusOnTab: true
                onTextChanged: {
                  root.selectedIndex = 0
                  root.transientMessage = ""
                  root.rebuildResults()
                }
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                  if (root.handleKey(event)) event.accepted = true
                }

                TapHandler {
                  acceptedButtons: Qt.LeftButton
                  onTapped: root.spaceActivatesSelection = false
                }

                Text {
                  visible: !queryInput.text
                  anchors.fill: parent
                  text: "Search plugins, or type \"plug-\" for commands."
                  textFormat: Text.PlainText
                  color: root.foreground
                  opacity: 0.42
                  font: queryInput.font
                  fontSizeMode: Text.HorizontalFit
                  minimumPixelSize: Math.max(Style.font.caption,
                    queryInput.font.pixelSize - 2)
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }
              }

              Text {
                id: shortcutLabel
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                text: paletteBinding.label
                textFormat: Text.PlainText
                color: root.foreground
                opacity: 0.40
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              id: headerActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.sm

              Repeater {
                model: root.headerActions

                delegate: Rectangle {
                  id: headerButton
                  required property var modelData
                  width: Style.space(32)
                  height: Style.space(32)
                  radius: Style.cornerRadius
                  color: Util.alpha(root.foreground,
                    headerButtonHover.containsMouse ? 0.14 : 0.06)
                  border.width: Math.max(1, Style.space(1))
                  border.color: Util.alpha(root.foreground, 0.09)

                  MouseArea {
                    id: headerButtonHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.modalDialogOpened
                      ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                      if (root.modalDialogOpened) return
                      root.runHeaderAction(String(headerButton.modelData.action))
                    }
                  }

                  Text {
                    anchors.centerIn: parent
                    text: Icons.glyph(headerButton.modelData.action)
                    textFormat: Text.PlainText
                    color: headerButton.modelData.action === "warning"
                      ? root.shortcutColor : root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.iconSmall
                  }

                  Rectangle {
                    visible: headerButton.modelData.action === "updates"
                      && root.pendingUpdateCount > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(4)
                    width: Style.space(6)
                    height: width
                    radius: width
                    color: root.shortcutColor
                  }

                  PanelToolTip {
                    visible: headerButtonHover.containsMouse
                    text: headerButton.modelData.label
                    panelBorder: root.shortcutColor
                    fontFamily: Style.font.menuFamily
                  }
                }
              }
            }
          }

          Item {
            id: columnHeader
            visible: root.paletteChromeVisible
            width: parent.width
            height: root.activeColumnHeaderHeight

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Math.max(1, Style.space(1))
              color: Util.alpha(root.foreground, 0.10)
            }

            Text {
              id: stateHeading
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(78)
              text: "STATE"
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.40
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: Style.spaceReal(1)
              elide: Text.ElideRight
            }

            Text {
              id: versionHeading
              anchors.right: stateHeading.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(54)
              text: "VER"
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.40
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: Style.spaceReal(1)
              elide: Text.ElideRight
            }

            Text {
              id: authorHeading
              anchors.right: versionHeading.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(118)
              text: "AUTHOR"
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.40
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: Style.spaceReal(1)
              elide: Text.ElideRight
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16) + Style.spacing.md
              anchors.right: authorHeading.left
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              text: "PLUGIN"
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.40
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: Style.spaceReal(1)
              elide: Text.ElideRight
            }
          }

          Item {
            width: parent.width
            height: Math.max(root.rowHeight, parent.height
              - root.activeHeaderHeight - root.activeColumnHeaderHeight
              - root.activeFooterHeight)
            clip: true

            ListView {
              id: resultList
              anchors.fill: parent
              anchors.topMargin: Style.space(2)
              visible: !root.detailOpen && displayModel.count > 0
              model: displayModel
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              spacing: root.rowSpacing
              delegate: PaletteResultRow {
                width: ListView.view.width
                selected: index === root.selectedIndex
                settingsMenuOpen: root.settingsMenuOpen
                pointerInteractive: !root.modalDialogOpened
                rowHeight: root.rowHeight
                foreground: root.foreground
                selectedBackground: root.selectedBackground
                selectedText: root.selectedText
                accent: root.accent
                successColor: root.successColor
                urgent: root.urgent
                onHovered: root.select(index)
                onActivated: {
                  root.select(index)
                  root.activateIndex(index)
                }
                onRepositoryRequested: function(url) { root.openWebsite(url) }
              }
            }

            Text {
              visible: !root.detailOpen && displayModel.count === 0
              anchors.fill: parent
              anchors.leftMargin: Style.space(16) + Style.spacing.md
              text: root.emptyStateText
              textFormat: Text.PlainText
              color: root.foreground
              opacity: 0.55
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
            }

            ActionDialog {
              id: actionDialog
              anchors.fill: parent
              z: 20
              opacity: actionDialog.opened ? 1 : 0

              transform: Translate {
                x: actionDialog.opened ? 0 : Style.space(14)

                Behavior on x {
                  NumberAnimation {
                    duration: root.service && root.service.animationsEnabled
                      ? 110 : 0
                    easing.type: Easing.OutCubic
                  }
                }
              }
              plugin: root.selectedRecord
              selfId: root.pluginId
              securityReport: root.service
                && root.service.auditForId === String(root.selectedRecord
                  && root.selectedRecord.id || "")
                ? root.service.auditState : ({})
              securityScanning: root.service
                && root.service.auditing === true
                && root.service.auditForId === String(root.selectedRecord
                  && root.selectedRecord.id || "")
              busy: root.service ? root.service.actionRunning : false
              installInTerminal: root.installInTerminal
              background: root.background
              foreground: root.foreground
              selectedBackground: root.selectedBackground
              selectedText: root.selectedText
              warningColor: root.urgent
              marketplaceOrange: root.marketplaceOrange
              marketplaceGreen: root.successColor
              marketplaceYellow: root.shortcutColor
              marketplaceRed: root.urgent
              previewLoading: root.service ? root.service.previewLoading : false
              previewFailed: root.service && root.service.previewState
                && root.selectedRecord
                && root.service.previewState.id === root.selectedRecord.id
                && root.service.previewState.failed === true
              previewCardSource: root.service && root.service.previewState
                && root.selectedRecord
                && root.service.previewState.id === root.selectedRecord.id
                ? String(root.service.previewState.cardUrl || "") : ""
              previewDetailSource: root.service && root.service.previewState
                && root.selectedRecord
                && root.service.previewState.id === root.selectedRecord.id
                ? String(root.service.previewState.detailUrl || "") : ""
              onCanceled: {
                closeDialog()
                Qt.callLater(queryInput.forceActiveFocus)
              }
              onTerminalInstallToggled: function(enabled) {
                root.setInstallInTerminal(enabled)
              }
              onPreviewRequested: function(url, name, width, height) {
                root.openPreview(url, name, width, height)
              }
              onActionRequested: function(operation) {
                root.confirmAction(operation)
              }
              onDeepScanRequested: root.launchDeepScan()
            }
          }

          PaletteFooter {
            visible: root.paletteChromeVisible
            width: parent.width
            height: root.activeFooterHeight
            record: root.shortcutRecord
            actions: root.stripActions
            statusText: root.stripStatusText
            statusColor: root.stripStatusColor
            statusOpacity: root.stripStatusOpacity
            statusAcknowledgeable: root.stripStatusAcknowledgeable
            hintText: root.stripHintText
            busy: root.service ? root.service.actionRunning === true : false
            pointerInteractive: !root.modalDialogOpened
            foreground: root.foreground
            shortcutColor: root.shortcutColor
            urgent: root.urgent
            onOperationRequested: function(operation) {
              root.requestStripOperation(operation)
            }
            onInfoRequested: root.openSelectedInfo()
            onWebsiteRequested: root.openMarketplaceShortcut()
            onSourceRequested: root.openGithubShortcut()
            onStatusDismissed: root.dismissStatus()
          }
        }
      }
    }

    FocusScope {
      id: previewLayer
      visible: root.previewOpen
      anchors.fill: parent
      z: 100

      Rectangle {
        anchors.fill: parent
        color: root.background
        opacity: 0.97
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: root.closePreview()
      }

      Image {
        id: fullPreview
        anchors.fill: parent
        anchors.margins: Style.space(48)
        source: root.previewOpen ? root.previewUrl : ""
        sourceSize.width: root.previewWidth > 0 ? root.previewWidth : -1
        sourceSize.height: root.previewHeight > 0 ? root.previewHeight : -1
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        mipmap: true

        MouseArea {
          anchors.centerIn: fullPreview
          width: fullPreview.paintedWidth
          height: fullPreview.paintedHeight
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closePreview()
        }
      }

      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.spacing.md
        width: Math.min(parent.width - Style.spacing.panelPadding * 2,
          previewLabel.implicitWidth + Style.spacing.lg)
        height: Style.space(34)
        radius: Style.cornerRadius
        color: Util.alpha(root.background, 0.94)
        border.width: Math.max(1, Style.space(1))
        border.color: Util.alpha(root.marketplaceOrange, 0.62)

        Text {
          id: previewLabel
          anchors.centerIn: parent
          width: Math.min(implicitWidth, parent.width - Style.spacing.md)
          text: root.previewName + " preview  -  Esc / Q / Enter / Space closes"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
    }
  }
}
