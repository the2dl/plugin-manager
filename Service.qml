import QtQuick
import Quickshell
import Quickshell.Io
import "CatalogModel.js" as CatalogModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  property var records: []
  property var snapshot: ({})
  property var actionState: ({
    ok: true,
    running: false,
    acknowledged: true,
    message: "No action has run."
  })
  property bool ready: false
  property bool refreshing: false
  property bool checkingUpdates: false
  property bool previewLoading: false
  property var previewState: ({})
  property var previewQueuedRecord: null
  property bool actionStarting: false
  property var auditState: ({})
  property bool auditing: false
  property string auditForId: ""
  property var updatesReport: ({})
  property bool updatesScanning: false
  property bool updatingAll: false
  readonly property string pluginsRoot: (Quickshell.env("XDG_CONFIG_HOME")
    || Quickshell.env("HOME") + "/.config") + "/omarchy/plugins"
  property bool animationsEnabled: true
  property bool backgroundDim: false
  property string lastError: ""
  property var refreshWarnings: []
  property string lastSuccessfulRefresh: ""
  property string refreshBaselineTimestamp: ""
  property bool refreshSuccessVisible: false
  property string lastUpdateCheckError: ""
  property string lastUpdateCheckNotice: ""
  property string lastSuccessfulUpdateCheck: ""
  property string updateCheckBaselineTimestamp: ""
  property bool updateCheckSuccessVisible: false
  property real serviceReadyMs: -1
  property real lastOpenRequestMs: -1
  property real lastFocusReadyMs: -1
  property real lastFilterMs: -1
  property real lastRefreshDurationMs: 0
  property int catalogRecordCount: records.length
  property double componentStartedAt: Date.now()
  property double latestOpenStartedAt: 0
  property int configChangeRevision: 0
  property bool configSyncQueued: false
  property bool initialLoadStarted: false
  property bool channelConfigWatchReady: false
  readonly property int actionNoticeDurationMs: 10000
  readonly property int refreshSuccessDurationMs: 10000
  readonly property int updateCheckSuccessDurationMs: 10000

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
    || homeDir + "/.config"
  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir) : ""
  readonly property string helperPath: sourceDir
    ? sourceDir + "/bin/plugin-control" : ""
  readonly property string channelConfigPath: configHome
    + "/omarchy/ilyazar.plugin-control/channels.yaml"
  readonly property bool actionRunning: actionStarting
    || (actionState && actionState.running === true)
  readonly property string moduleName: "io.github.ilyazar.plugin-control"
  readonly property var updateWarnings: {
    var values = []
    for (var i = 0; i < records.length; i++) {
      var record = records[i]
      if (String(record.updateStatus || "") !== "error"
          || !String(record.updateReason || "")) continue
      values.push({
        id: String(record.id || ""),
        name: String(record.name || record.id || "Unknown plugin"),
        reason: String(record.updateReason)
      })
    }
    return values
  }
  readonly property string updateWarningText: {
    var lines = ["Update check warnings"]
    for (var i = 0; i < updateWarnings.length; i++) {
      var warning = updateWarnings[i]
      lines.push("")
      lines.push(warning.name + (warning.id
        ? " (" + warning.id + ")" : ""))
      lines.push(warning.reason)
    }
    return lines.join("\n")
  }

  signal actionFinished(var state)
  signal auditReady(string pluginId, var report)
  signal updatesReportReady(var report)
  signal updateAllFinished(var summary)

  function parseJson(raw, fallback) {
    try { return JSON.parse(String(raw || "")) } catch (error) { return fallback }
  }

  function applyRecords(values) {
    records = CatalogModel.prepareRecords(values)
    catalogRecordCount = records.length
    if (!ready && records.length > 0) {
      ready = true
      serviceReadyMs = Date.now() - componentStartedAt
    }
  }

  function applyBootstrap(raw) {
    var parsed = parseJson(raw, {})
    if (!parsed || !Array.isArray(parsed.plugins)) return
    if (records.length === 0) applyRecords(parsed.plugins)
  }

  function applyConfigStatus(raw, exitCode, revision) {
    if (revision !== configChangeRevision || exitCode !== 0) return false
    var parsed = parseJson(raw, null)
    if (!parsed || parsed.ok !== true || parsed.usingLastGood === true
        || !parsed.config || parsed.config.version !== 2) return false
    var settings = parsed.config.settings
    var trayHidden = settings ? settings["tray-icon-hidden"] : undefined
    var dimBackground = settings ? settings.background_dim : undefined
    if (typeof trayHidden !== "boolean"
        || typeof dimBackground !== "boolean") return false
    backgroundDim = dimBackground
    if (!pluginRegistry
        || typeof pluginRegistry.setBarWidget !== "function") return false
    var error = String(pluginRegistry.setBarWidget(
      moduleName, "trayIconHidden", trayHidden, {}) || "")
    if (error) {
      lastError = "Could not apply tray icon visibility."
      return false
    }
    return true
  }

  function requestConfigSync() {
    if (!helperPath) return
    if (configSyncProcess.running) {
      configSyncQueued = true
      return
    }
    configSyncQueued = false
    configSyncProcess.output = ""
    configSyncProcess.revision = configChangeRevision
    configSyncProcess.command = [helperPath, "config-status", sourceDir]
    configSyncProcess.running = true
  }

  function configProblemNotice(raw) {
    var parsed = parseJson(raw, null)
    if (!parsed || parsed.ok !== false) return ""
    var field = String(parsed.field || "configuration")
    var actual = String(parsed.actual || "")
    var expected = String(parsed.expected || "")
    var detail = String(parsed.error || "Invalid Plugin Manager settings.")
    if (expected) {
      detail = actual
        ? actual + " is not admissible for " + field
          + ". Set it to " + expected + "."
        : field + " is not admissible. Use " + expected + "."
    }
    var fallback = parsed.fallback === "defaults"
      ? "Using shipped defaults."
      : (parsed.fallback === "last-good"
        ? "Keeping the last valid settings."
        : "Fix the file before it can be used.")
    return (detail + " " + fallback).slice(0, 480)
  }

  function notifyConfigProblem(raw, revision) {
    if (revision !== configChangeRevision) return false
    var message = configProblemNotice(raw)
    if (!message) return false
    Quickshell.execDetached(["omarchy-notification-send", "-u", "normal",
      "Plugin Manager settings", message])
    return true
  }

  function clearRefreshSuccess() {
    refreshSuccessTimer.stop()
    refreshSuccessVisible = false
  }

  function clearUpdateCheckSuccess() {
    updateCheckSuccessTimer.stop()
    updateCheckSuccessVisible = false
  }

  function applySnapshot(raw, exitCode, refreshResult, updateResult) {
    var parsed = parseJson(raw, null)
    if (refreshResult === true) refreshing = false
    if (updateResult === true) checkingUpdates = false
    if (!parsed || parsed.ok !== true || !Array.isArray(parsed.records)) {
      if (refreshResult === true) clearRefreshSuccess()
      if (updateResult === true) clearUpdateCheckSuccess()
      if (updateResult === true && parsed && parsed.error)
        lastUpdateCheckError = String(parsed.error)
      else if (parsed && parsed.error) lastError = String(parsed.error)
      else if (exitCode !== 0) lastError = "Catalog helper failed."
      return false
    }

    snapshot = parsed
    backgroundDim = parsed.config && parsed.config.settings
      ? parsed.config.settings.background_dim === true : false
    applyRecords(parsed.records)
    refreshWarnings = parsed.cache && Array.isArray(parsed.cache.refreshWarnings)
      ? parsed.cache.refreshWarnings : []
    lastSuccessfulRefresh = parsed.cache
      ? String(parsed.cache.lastSuccessfulRefresh || "") : ""
    lastRefreshDurationMs = parsed.cache
      ? Number(parsed.cache.refreshDurationMs || 0) : 0
    lastUpdateCheckError = parsed.updates
      ? String(parsed.updates.lastCheckError || "") : ""
    lastUpdateCheckNotice = parsed.updates
      ? String(parsed.updates.lastCheckNotice || "") : ""
    lastSuccessfulUpdateCheck = parsed.updates
      ? String(parsed.updates.lastSuccessfulCheck || "") : ""
    lastError = ""
    if (refreshResult === true) {
      clearRefreshSuccess()
      if (exitCode === 0 && refreshWarnings.length === 0
          && lastSuccessfulRefresh
          && lastSuccessfulRefresh !== refreshBaselineTimestamp) {
        refreshSuccessVisible = true
        refreshSuccessTimer.restart()
      }
    }
    if (updateResult === true) {
      clearUpdateCheckSuccess()
      if (exitCode === 0 && !lastUpdateCheckError
          && lastSuccessfulUpdateCheck
          && lastSuccessfulUpdateCheck !== updateCheckBaselineTimestamp) {
        updateCheckSuccessVisible = true
        updateCheckSuccessTimer.restart()
      }
    }
    return true
  }

  function loadCached() {
    if (!helperPath || cachedProcess.running) return false
    cachedProcess.output = ""
    cachedProcess.command = [helperPath, "cached", sourceDir]
    cachedProcess.running = true
    return true
  }

  function startInitialLoad() {
    if (initialLoadStarted || !helperPath) return false
    initialLoadStarted = loadCached()
    return initialLoadStarted
  }

  function requestRefresh(force) {
    if (!helperPath) return
    if (refreshProcess.running) {
      refreshProcess.forceQueued = refreshProcess.forceQueued || force === true
      return
    }
    clearRefreshSuccess()
    refreshBaselineTimestamp = lastSuccessfulRefresh
    refreshing = true
    refreshProcess.output = ""
    var command = [helperPath, "refresh", sourceDir]
    if (force === true) command.push("--force")
    refreshProcess.command = command
    refreshProcess.running = true
  }

  function requestUpdateCheck() {
    if (!helperPath || updateCheckProcess.running) return false
    clearUpdateCheckSuccess()
    updateCheckBaselineTimestamp = lastSuccessfulUpdateCheck
    checkingUpdates = true
    updateCheckProcess.output = ""
    updateCheckProcess.command = [helperPath, "check-updates", sourceDir]
    updateCheckProcess.running = true
    return true
  }

  function requestPreview(record) {
    if (!helperPath || !record) return false
    var id = String(record.id || "")
    var cardUrl = String(record.previewThumbnailUrl || "")
    var detailUrl = String(record.previewImageUrl || "")
    if (!id || !cardUrl || !detailUrl) return false
    if (previewState && previewState.id === id
        && previewState.cardUrl && previewState.detailUrl) return true
    if (previewProcess.running) {
      previewQueuedRecord = JSON.parse(JSON.stringify(record))
      return true
    }
    previewLoading = true
    previewState = ({ id: id })
    previewProcess.output = ""
    previewProcess.requestedId = id
    previewProcess.command = [helperPath, "preview", id, cardUrl, detailUrl,
      String(record.versionUpdatedAt || record.version || "")]
    previewProcess.running = true
    return true
  }

  function acceptPreview(raw, exitCode) {
    previewLoading = false
    var parsed = parseJson(raw, null)
    if (exitCode !== 0 || !parsed || parsed.ok !== true
        || !parsed.id || !parsed.cardUrl || !parsed.detailUrl) {
      previewState = ({ id: previewProcess.requestedId, failed: true })
      return false
    }
    previewState = parsed
    return true
  }

  function requestStatus() {
    if (!helperPath || statusProcess.running) return
    statusProcess.output = ""
    statusProcess.command = [helperPath, "status"]
    statusProcess.running = true
  }

  function acceptStatus(raw) {
    var previousRunning = actionState && actionState.running === true
    var previousAcknowledged = actionState
      && actionState.acknowledged === false
    var previousActionId = String(actionState && actionState.actionId || "")
    var parsed = parseJson(raw, null)
    if (!parsed || typeof parsed !== "object") return
    actionState = parsed
    var finishedUnacknowledged = parsed.running !== true
      && parsed.acknowledged !== true
    var isNewNotice = previousRunning || !previousAcknowledged
      || previousActionId !== String(parsed.actionId || "")
    if (finishedUnacknowledged && isNewNotice)
      actionNoticeTimer.restart()
    if (previousRunning && parsed.running !== true) {
      loadCached()
      actionFinished(parsed)
    }
  }

  // Read-only pre-flight scan. Installed plugins scan their on-disk checkout;
  // an available plugin gets a throwaway shallow clone scanned and discarded.
  // Never enables or installs anything -- purely advisory input to the UI gate.
  function requestAudit(record) {
    if (!helperPath || !record || auditProcess.running) return false
    var id = String(record.id || "")
    if (!id) return false
    auditForId = id
    auditing = true
    auditState = ({})
    auditProcess.output = ""
    auditProcess.pluginId = id
    if (record.installed === true || record.builtIn === true) {
      // A plugin with a pending update: scan the code the update would BRING
      // (incoming diff), not just what is currently on disk.
      var pending = record.updateAvailable === true
        || record.warning === "Upstream changed"
      auditProcess.command = pending && record.builtIn !== true
        ? [helperPath, "audit-update", sourceDir, pluginsRoot + "/" + id]
        : [helperPath, "audit", sourceDir, pluginsRoot + "/" + id]
    } else {
      var repo = String(record.repository || "")
      if (!repo) { auditing = false; auditForId = ""; return false }
      var cmd = [helperPath, "audit-remote", sourceDir, repo]
      if (String(record.commit || "")) cmd.push(String(record.commit))
      auditProcess.command = cmd
    }
    auditProcess.running = true
    return true
  }

  // Scan the incoming diff of every plugin with a pending update, for the
  // Update All review. Read-only.
  function requestUpdatesReport() {
    if (!helperPath || updatesReportProcess.running || updatingAll) return false
    updatesScanning = true
    updatesReport = ({})
    updatesReportProcess.output = ""
    updatesReportProcess.command = [helperPath, "audit-updates", sourceDir]
    updatesReportProcess.running = true
    return true
  }

  // Update the given ids (a CSV the UI chose after seeing the scan).
  function startUpdateAll(idsCsv) {
    if (!helperPath || updateAllProcess.running || !String(idsCsv)) return false
    var ids = String(idsCsv).split(",").filter(function(x) { return x.length })
    if (ids.length === 0) return false
    updatingAll = true
    updateAllProcess.output = ""
    updateAllProcess.command = [helperPath, "update-all", sourceDir].concat(ids)
    updateAllProcess.running = true
    return true
  }

  function startAction(operation, pluginId, snapshotId, executionMode) {
    if (!helperPath || actionRunning || actionProcess.running) return false
    if (["add", "remove", "remove-purge", "enable", "disable", "update"]
        .indexOf(String(operation)) < 0) return false
    if (!String(pluginId) || !String(snapshotId)) return false
    if (["background", "terminal"].indexOf(String(executionMode)) < 0)
      return false
    if (executionMode === "terminal" && operation !== "add") return false
    actionStarting = true
    actionState = {
      ok: true,
      running: true,
      acknowledged: false,
      operation: String(operation),
      message: operation === "update"
        ? "Checking for updates..." : "Working..."
    }
    actionProcess.output = ""
    actionProcess.operation = String(operation)
    actionProcess.command = [helperPath, "action", sourceDir,
      String(operation), String(pluginId), String(snapshotId),
      String(executionMode)]
    actionProcess.running = true
    return true
  }

  function acceptActionStart(raw, exitCode) {
    actionStarting = false
    var parsed = parseJson(raw, null)
    if (!parsed || parsed.ok !== true || exitCode !== 0) {
      actionState = {
        ok: false,
        running: false,
        acknowledged: false,
        message: parsed && parsed.error
          ? String(parsed.error) : "Could not start the plugin action."
      }
      actionNoticeTimer.restart()
      actionFinished(actionState)
      return
    }
    actionState = {
      ok: true,
      running: true,
      acknowledged: false,
      actionId: String(parsed.actionId || ""),
      operation: actionProcess.operation,
      message: actionProcess.operation === "update"
        ? "Checking for updates..." : "Working..."
    }
    actionPoll.restart()
  }

  function acknowledgeAction() {
    var actionId = String(actionState && actionState.actionId || "")
    actionNoticeTimer.stop()
    if (helperPath && actionId)
      Quickshell.execDetached([helperPath, "ack", actionId])
    var copy = ({})
    for (var key in actionState) copy[key] = actionState[key]
    copy.acknowledged = true
    actionState = copy
  }

  function recordOpenRequest() {
    latestOpenStartedAt = Date.now()
    lastOpenRequestMs = 0
  }

  function recordSurfaceVisible() {
    if (latestOpenStartedAt > 0)
      lastOpenRequestMs = Date.now() - latestOpenStartedAt
  }

  function recordFocusReady() {
    if (latestOpenStartedAt > 0)
      lastFocusReadyMs = Date.now() - latestOpenStartedAt
  }

  function recordFilterDuration(durationMs) {
    lastFilterMs = Number(durationMs)
  }

  function cacheAgeSeconds() {
    var refreshed = Date.parse(lastSuccessfulRefresh)
    if (!isFinite(refreshed)) return -1
    return Math.max(0, Math.floor((Date.now() - refreshed) / 1000))
  }

  FileView {
    path: root.sourceDir ? root.sourceDir + "/bootstrap/catalog.json" : ""
    printErrors: false
    onLoaded: root.applyBootstrap(text())
  }

  FileView {
    id: channelConfigFile
    path: root.channelConfigPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.channelConfigWatchReady = true
      configWatchRetry.stop()
    }
    onLoadFailed: {
      root.channelConfigWatchReady = false
      configWatchRetry.restart()
    }
    onFileChanged: {
      root.channelConfigWatchReady = false
      reload()
      root.configChangeRevision++
      configRefreshDebounce.restart()
    }
  }

  Timer {
    id: configWatchRetry
    interval: 1000
    repeat: false
    onTriggered: channelConfigFile.reload()
  }

  Process {
    id: configSyncProcess
    property string output: ""
    property int revision: -1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: configSyncProcess.output = text
    }
    onExited: function(exitCode) {
      root.applyConfigStatus(output, exitCode, revision)
      root.notifyConfigProblem(output, revision)
      if (root.configSyncQueued || revision !== root.configChangeRevision)
        Qt.callLater(root.requestConfigSync)
    }
  }

  Process {
    id: updateCheckProcess
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: updateCheckProcess.output = text
    }
    onExited: function(exitCode) {
      root.applySnapshot(output, exitCode, false, true)
    }
  }

  Process {
    id: cachedProcess
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: cachedProcess.output = text
    }
    onExited: function(exitCode) {
      root.applySnapshot(output, exitCode, false)
      channelConfigFile.reload()
      Qt.callLater(root.requestStatus)
    }
  }

  Process {
    id: refreshProcess
    property string output: ""
    property bool forceQueued: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: refreshProcess.output = text
    }
    onExited: function(exitCode) {
      root.applySnapshot(output, exitCode, true)
      if (forceQueued) {
        forceQueued = false
        Qt.callLater(function() { root.requestRefresh(true) })
      }
    }
  }

  Process {
    id: statusProcess
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: statusProcess.output = text
    }
    onExited: root.acceptStatus(output)
  }

  Process {
    id: updatesReportProcess
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: updatesReportProcess.output = text
    }
    onExited: function(exitCode) {
      var report = ({ plugins: [], counts: { total: 0, clean: 0, flagged: 0 } })
      try { report = JSON.parse(updatesReportProcess.output || "{}") }
      catch (e) {}
      root.updatesReport = report
      root.updatesScanning = false
      root.updatesReportReady(report)
    }
  }

  Process {
    id: updateAllProcess
    property string output: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: updateAllProcess.output = text
    }
    onExited: function(exitCode) {
      var summary = ({ ok: 0, failed: 0, results: [] })
      try { summary = JSON.parse(updateAllProcess.output || "{}") }
      catch (e) {}
      root.updatingAll = false
      root.updateAllFinished(summary)
      root.requestRefresh(true)   // rebuild the snapshot so updated plugins clear
    }
  }

  Process {
    id: auditProcess
    property string output: ""
    property string pluginId: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: auditProcess.output = text
    }
    onExited: function(exitCode) {
      var report = ({})
      try { report = JSON.parse(auditProcess.output || "{}") }
      catch (e) { report = ({ summary: { verdict: "scan-error",
        caveat: "The security scan produced no readable result." },
        findings: [], limitations: [] }) }
      root.auditState = report
      root.auditing = false
      root.auditReady(auditProcess.pluginId, report)
    }
  }

  Process {
    id: previewProcess
    property string output: ""
    property string requestedId: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: previewProcess.output = text
    }
    onExited: function(exitCode) {
      root.acceptPreview(output, exitCode)
      if (root.previewQueuedRecord) {
        var queued = root.previewQueuedRecord
        root.previewQueuedRecord = null
        Qt.callLater(function() { root.requestPreview(queued) })
      }
    }
  }

  Process {
    id: actionProcess
    property string output: ""
    property string operation: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: actionProcess.output = text
    }
    onExited: function(exitCode) {
      root.acceptActionStart(output, exitCode)
    }
  }

  Process {
    id: animationProbe
    command: ["hyprctl", "-j", "getoption", "animations:enabled"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, {})
        root.animationsEnabled = parsed.int === undefined
          ? true : Number(parsed.int) !== 0
      }
    }
  }

  Timer {
    id: configRefreshDebounce
    interval: 300
    repeat: false
    onTriggered: {
      root.requestConfigSync()
      root.requestRefresh(true)
    }
  }

  Timer {
    id: updateCheckSuccessTimer
    interval: root.updateCheckSuccessDurationMs
    repeat: false
    onTriggered: root.updateCheckSuccessVisible = false
  }

  Timer {
    id: actionPoll
    interval: 500
    repeat: true
    running: root.actionRunning
    onTriggered: root.requestStatus()
  }

  Timer {
    id: actionNoticeTimer
    interval: root.actionNoticeDurationMs
    repeat: false
    onTriggered: root.acknowledgeAction()
  }

  Timer {
    id: refreshSuccessTimer
    interval: root.refreshSuccessDurationMs
    repeat: false
    onTriggered: root.refreshSuccessVisible = false
  }

  onHelperPathChanged: startInitialLoad()

  Component.onCompleted: {
    animationProbe.running = true
    startInitialLoad()
  }
}
