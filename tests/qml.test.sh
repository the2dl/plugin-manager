#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
readonly ROOT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

qmllint_bin="$(command -v qmllint)"
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
  qmllint_bin=/usr/lib/qt6/bin/qmllint
fi
"$qmllint_bin" -I /usr/share/omarchy/shell \
  "$ROOT/Service.qml" "$ROOT/PluginControl.qml" "$ROOT/ActionDialog.qml" \
  "$ROOT/PluginControlBar.qml" "$ROOT/SelfRemovalDialog.qml" \
  "$ROOT/PaletteResultRow.qml" "$ROOT/PaletteFooter.qml" \
  "$ROOT/PaletteFilterRail.qml" \
  "$ROOT/lib/shortcuts/HyprlandBinding.qml"
printf 'ok - QML lint\n'

rg -q 'function open\(payloadJson\)' "$ROOT/PluginControl.qml"
rg -q 'function close\(\)' "$ROOT/PluginControl.qml"
rg -q 'function toggle\(\)' "$ROOT/PluginControl.qml"
rg -q 'TextInput \{' "$ROOT/PluginControl.qml"
rg -q 'Qt.Key_P' "$ROOT/PluginControl.qml"
rg -Fq 'event.key === Qt.Key_Escape' "$ROOT/PluginControl.qml"
# The six keyboard-shortcut chips are gone; the footer is now an icon
# action strip bound to the selected row.
if rg -q 'keyLabel' "$ROOT/PaletteFooter.qml"; then
  printf 'not ok - keyboard shortcut chips remain in the footer\n' >&2
  exit 1
fi
rg -Fq 'signal operationRequested(string operation)' "$ROOT/PaletteFooter.qml"
rg -Fq 'signal infoRequested()' "$ROOT/PaletteFooter.qml"
rg -Fq 'signal websiteRequested()' "$ROOT/PaletteFooter.qml"
rg -Fq 'signal sourceRequested()' "$ROOT/PaletteFooter.qml"
rg -Fq 'Icons.glyph(entry.operation)' "$ROOT/PaletteFooter.qml"
rg -Fq 'root.shortcutColor' "$ROOT/PaletteFooter.qml"

# Filters are a rail, not only a typed `plug-...:` prefix.
rg -Fq 'signal filterPicked(string id)' "$ROOT/PaletteFilterRail.qml"
for palette_filter in all installed available disabled updates \
  source-marketplace source-local; do
  rg -Fq "id: \"$palette_filter\"" "$ROOT/PaletteFilterRail.qml"
done
rg -Fq 'PaletteFilterRail {' "$ROOT/PluginControl.qml"
rg -Fq 'function setFilter(id)' "$ROOT/PluginControl.qml"
rg -Fq 'filterCounts = Fuzzy.counts(records)' "$ROOT/PluginControl.qml"
rg -Fq 'Fuzzy.search(records, query, 200, activeFilter)' \
  "$ROOT/PluginControl.qml"

# The detail dialog uses icons, not a row of equal-width text buttons.
rg -Fq 'Icons.glyph(actionButton.modelData.operation)' "$ROOT/ActionDialog.qml"
rg -Fq 'function selectOperation(operation)' "$ROOT/ActionDialog.qml"
if rg -q 'font.pixelSize: Style.font.title' "$ROOT/ActionDialog.qml" \
    | rg -q 'actionButton'; then
  printf 'not ok - text action buttons remain in the dialog\n' >&2
  exit 1
fi
if rg -q 'Ctrl\+Shift|isContextShortcut' "$ROOT/PluginControl.qml"; then
  printf 'not ok - shifted palette shortcuts remain\n' >&2
  exit 1
fi
rg -Fq 'sourcePath("scripts/open-settings.sh")' "$ROOT/PluginControl.qml"
rg -Fq 'openMarketplaceShortcut()' "$ROOT/PluginControl.qml"
rg -Fq 'openGithubShortcut()' "$ROOT/PluginControl.qml"
rg -q 'ListView \{' "$ROOT/PluginControl.qml"
rg -q 'textFormat: Text.PlainText' "$ROOT/PluginControl.qml"
rg -q 'queryInput.forceActiveFocus\(\)' "$ROOT/PluginControl.qml"
rg -q 'service.recordFocusReady\(\)' "$ROOT/PluginControl.qml"
rg -q 'service.recordSurfaceVisible\(\)' "$ROOT/PluginControl.qml"
rg -q 'cacheAgeSeconds' "$ROOT/PluginControl.qml"
rg -q '\[omarchyPath \+ "/bin/omarchy", "launch",' \
  "$ROOT/PluginControl.qml"
rg -q '"browser", url\]' "$ROOT/PluginControl.qml"
rg -q 'Qt.Key_Up' "$ROOT/PluginControl.qml"
rg -q 'Qt.Key_PageDown' "$ROOT/PluginControl.qml"
rg -q 'activateIndex\(selectedIndex\)' "$ROOT/PluginControl.qml"
rg -q 'Qt.Key_Tab' "$ROOT/PluginControl.qml"
rg -q 'event.key === Qt.Key_Space' "$ROOT/PluginControl.qml"
rg -Fq 'onTapped: root.spaceActivatesSelection = false' \
  "$ROOT/PluginControl.qml"
rg -q 'commandCompletion' "$ROOT/PluginControl.qml"
rg -q 'function clearCompletedCommandPrefix()' "$ROOT/PluginControl.qml"
rg -Fq 'repository: String(value.repository' "$ROOT/PaletteViewModel.js"
rg -Fq 'font.pixelSize: Style.font.caption' "$ROOT/PaletteResultRow.qml"
rg -q 'pendingSnapshotId = readOnly === true' \
  "$ROOT/PluginControl.qml"
rg -q 'String\(selectedRecord.id || ""\), pendingSnapshotId' \
  "$ROOT/PluginControl.qml"
rg -Fq '["add", "remove", "update", "enable", "disable"]' \
  "$ROOT/PluginControl.qml"
rg -Fq '+ " --yes && omarchy restart shell"' \
  "$ROOT/ActionDialog.qml"
[[ $(rg -c 'omarchy restart shell' "$ROOT/ActionDialog.qml") == 2 ]]
rg -Fq '? "omarchy plugin add <repository> --enable"' \
  "$ROOT/ActionDialog.qml"
rg -Fq ': "omarchy plugin add <repository> --enable --yes")' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'return "omarchy plugin enable " + id' "$ROOT/ActionDialog.qml"
rg -Fq 'return "omarchy plugin disable " + id' "$ROOT/ActionDialog.qml"
if rg -q 'add-bar|omarchy bar put' "$ROOT/PluginControl.qml" \
    "$ROOT/ActionDialog.qml" "$ROOT/Service.qml"; then
  printf 'not ok - obsolete bar placement action remains\n' >&2
  exit 1
fi
if rg -q 'horizontalAlignment: Text.AlignHCenter' "$ROOT/PluginControl.qml"; then
  printf 'not ok - result text must not be centered\n' >&2
  exit 1
fi
printf 'ok - overlay lifecycle input shortcuts and left-aligned rows\n'

rg -Fq 'BarIconButton {' "$ROOT/PluginControlBar.qml"
rg -Fq 'text: "󰏖"' "$ROOT/PluginControlBar.qml"
rg -Fq 'Qt.LeftButton' "$ROOT/PluginControlBar.qml"
rg -Fq 'root.bar.shell.toggle' "$ROOT/PluginControlBar.qml"
rg -Fq 'Qt.RightButton' "$ROOT/PluginControlBar.qml"
rg -Fq 'text: "Settings"' "$ROOT/PluginControlBar.qml"
rg -Fq "root.bar.shell.toggle(root.moduleName, '{\"settings\":true}')" \
  "$ROOT/PluginControlBar.qml"
if rg -q 'Remove Plugin Control|removePluginControl' \
  "$ROOT/PluginControlBar.qml"; then
  printf 'not ok - destructive action remains in the bar popup\n' >&2
  exit 1
fi
rg -Fq 'setting("trayIconHidden", false) === true' \
  "$ROOT/PluginControlBar.qml"
printf 'ok - bar launcher uses the native package button and settings menu\n'

rg -Fq 'color: Util.alpha(root.foreground, 0.16)' \
  "$ROOT/PaletteFooter.qml"
rg -q 'sourceLabel:' "$ROOT/PaletteViewModel.js"
rg -q 'service.actionRunning' "$ROOT/PluginControl.qml"
rg -Fq 'actionNoticeDurationMs: 10000' "$ROOT/Service.qml"
rg -Fq 'refreshSuccessDurationMs: 10000' "$ROOT/Service.qml"
if rg -q 'startupRefreshPending|requestRefresh\(false\)' "$ROOT/Service.qml"; then
  printf 'not ok - service automatically refreshes the catalog at startup\n' >&2
  exit 1
fi
component_completed="$(sed -n '/Component.onCompleted:/,/^  }/p' \
  "$ROOT/Service.qml")"
if grep -q 'requestUpdateCheck' <<<"$component_completed"; then
  printf 'not ok - service automatically checks updates at startup\n' >&2
  exit 1
fi
rg -Fq 'finishedUnacknowledged && isNewNotice' "$ROOT/Service.qml"
rg -Fq 'onTriggered: root.acknowledgeAction()' "$ROOT/Service.qml"
rg -Fq 'pluginRegistry.setBarWidget(' "$ROOT/Service.qml"
rg -Fq 'moduleName, "trayIconHidden", trayHidden, {}' "$ROOT/Service.qml"
rg -Fq 'property bool backgroundDim: false' "$ROOT/Service.qml"
rg -Fq 'backgroundDim = dimBackground' "$ROOT/Service.qml"
rg -Fq 'configSyncProcess.command = [helperPath, "config-status", sourceDir]' \
  "$ROOT/Service.qml"
rg -Fq 'root.configChangeRevision++' "$ROOT/Service.qml"
rg -Fq 'id: channelConfigFile' "$ROOT/Service.qml"
rg -Fq 'channelConfigFile.reload()' "$ROOT/Service.qml"
rg -Fq 'onHelperPathChanged: startInitialLoad()' "$ROOT/Service.qml"
rg -Fq 'id: configWatchRetry' "$ROOT/Service.qml"
rg -Fq 'configWatchRetry.restart()' "$ROOT/Service.qml"
rg -Fq 'omarchy-notification-send' "$ROOT/Service.qml"
rg -Fq 'root.notifyConfigProblem(output, revision)' "$ROOT/Service.qml"
rg -q 'actionDialog.openDialog\(\)' "$ROOT/PluginControl.qml"
rg -q 'function openSelectedInfo\(\)' "$ROOT/PluginControl.qml"
rg -q 'function showSettingsMenu\(\)' "$ROOT/PluginControl.qml"
rg -Fq 'name: "Cleanly remove Plugin Control and user data"' \
  "$ROOT/PaletteViewModel.js"
rg -Fq 'separatorBefore: true' "$ROOT/PaletteViewModel.js"
rg -q 'function openSelfRemovalDialog\(\)' "$ROOT/PluginControl.qml"
rg -Fq '"remove-purge"' "$ROOT/PluginControl.qml"
rg -Fq 'text: "Sure to remove Plugin Control?"' \
  "$ROOT/SelfRemovalDialog.qml"
rg -Fq '"Yes (preserve user data)"' "$ROOT/SelfRemovalDialog.qml"
rg -Fq '"Yes (delete user data)"' "$ROOT/SelfRemovalDialog.qml"
rg -Fq '"No / abort"' "$ROOT/SelfRemovalDialog.qml"
if rg -q 'removeSelf|tryOpenSelfRemoval|selfRemovalRequested' \
  "$ROOT/PluginControl.qml"; then
  printf 'not ok - obsolete self-removal payload remains\n' >&2
  exit 1
fi
rg -q 'Qt.Key_J' "$ROOT/PluginControl.qml"
rg -q 'Qt.Key_K' "$ROOT/PluginControl.qml"
rg -Fq 'readOnly: root.settingsMenuOpen' "$ROOT/PluginControl.qml"
rg -Fq 'name: "Cancel / Back"' "$ROOT/PaletteViewModel.js"
rg -Fq 'visible: root.paletteChromeVisible' "$ROOT/PluginControl.qml"
rg -Fq 'height: root.activeHeaderHeight' "$ROOT/PluginControl.qml"
rg -Fq 'height: root.activeFooterHeight' "$ROOT/PluginControl.qml"
rg -Fq 'Qt.callLater(card.forceActiveFocus)' "$ROOT/PluginControl.qml"
rg -q 'installInTerminal' "$ROOT/PluginControl.qml"
rg -q 'omarchy-launch-terminal' "$ROOT/lib/backend/actions.sh"
rg -q 'signal actionRequested\(string operation\)' "$ROOT/ActionDialog.qml"
rg -q 'signal previewRequested\(string url, string name, int width, int height\)' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'PaletteViewModel.actionOptions(plugin, readOnly)' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'interval: 1000' "$ROOT/ActionDialog.qml"
rg -Fq 'action.available === false' "$ROOT/ActionDialog.qml"
rg -Fq 'helpText = String(action.reason' "$ROOT/ActionDialog.qml"
rg -Fq 'plugin.commit || plugin.listingValidatedCommit' \
  "$ROOT/ActionDialog.qml"
rg -q 'ToggleSwitch \{' "$ROOT/ActionDialog.qml"
rg -q 'Run Add in Omarchy terminal' "$ROOT/ActionDialog.qml"
rg -q 'selectedChoice' "$ROOT/ActionDialog.qml"
rg -Fq 'maximumLineCount: root.readOnly ? 100 : 2' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'contentColumn.implicitHeight' "$ROOT/ActionDialog.qml"
# The detail no longer resizes the card to fit its content; it replaces
# the table inside the card the palette already has.
rg -Fq 'readonly property bool detailOpen: actionDialog.opened' \
  "$ROOT/PluginControl.qml"
rg -Fq '&& !detailOpen ? columnHeaderHeight : 0' "$ROOT/PluginControl.qml"
rg -Fq '&& !detailOpen ? footerHeight : 0' "$ROOT/PluginControl.qml"
if rg -q 'actionCardHeight' "$ROOT/PluginControl.qml"; then
  fail "detail view must not grow the palette card"
fi
rg -Fq 'fillMode: Image.PreserveAspectFit' "$ROOT/ActionDialog.qml"
rg -Fq 'width: previewThumbnail.paintedWidth' "$ROOT/ActionDialog.qml"
rg -Fq 'height: previewThumbnail.paintedHeight' "$ROOT/ActionDialog.qml"
rg -Fq 'anchors.right: previewClickArea.right' "$ROOT/ActionDialog.qml"
# The action row is pointer-driven as well as keyboard-driven: hovering an
# icon selects it (so the caption follows the mouse) and clicking runs it.
rg -Fq 'function activateChoice(index)' "$ROOT/ActionDialog.qml"
rg -Fq 'onClicked: root.activateChoice(actionButton.index)' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'onEntered: root.selectChoice(actionButton.index, false)' \
  "$ROOT/ActionDialog.qml"
if ! rg -Fq '|| root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor' \
    "$ROOT/ActionDialog.qml"; then
  fail "unavailable or busy actions must not present as clickable"
fi
rg -Fq 'root.marketplaceYellow' "$ROOT/ActionDialog.qml"
rg -Fq 'font.pixelSize: Style.font.icon' "$ROOT/ActionDialog.qml"
rg -Fq 'function returnToMainMenu()' "$ROOT/PluginControl.qml"
rg -Fq 'event.key === Qt.Key_Escape' "$ROOT/PluginControl.qml"
rg -Fq 'event.key === Qt.Key_Q' "$ROOT/PluginControl.qml"
if rg -q 'Qt.Key_(Escape|Q)' "$ROOT/ActionDialog.qml" \
    "$ROOT/SelfRemovalDialog.qml"; then
  fail "dialogs must not retain legacy close-key handlers"
fi
if rg -q 'submenuKeyCatcher|Shortcut \{' "$ROOT/PluginControl.qml"; then
  fail "legacy submenu focus and shortcut paths must be removed"
fi
rg -Fq 'id: card' "$ROOT/PluginControl.qml"
rg -Fq 'focus: true' "$ROOT/PluginControl.qml"
rg -Fq 'Keys.priority: Keys.BeforeItem' "$ROOT/PluginControl.qml"
rg -Fq 'if (actionDialog.readOnly || !selectedRecord || !service) return' \
  "$ROOT/PluginControl.qml"
rg -q 'function validPreviewUrl\(value\)' "$ROOT/PluginControl.qml"
rg -q 'previewCacheUrlPrefix' \
  "$ROOT/PluginControl.qml"
rg -Fq 'id: previewLayer' "$ROOT/PluginControl.qml"
rg -Fq 'width: fullPreview.paintedWidth' "$ROOT/PluginControl.qml"
rg -Fq 'height: fullPreview.paintedHeight' "$ROOT/PluginControl.qml"
if (( $(rg -c 'cursorShape: Qt.ArrowCursor' \
    "$ROOT/PluginControl.qml") < 3 )); then
  fail "non-interactive overlay surfaces must reclaim the arrow cursor"
fi
rg -Fq 'Not listed on Omarchy Plugins' "$ROOT/ActionDialog.qml"
rg -Fq 'marketplaceOrange: Color.accent' "$ROOT/ActionDialog.qml"
rg -Fq 'marketplaceGreen: Color.accent' "$ROOT/ActionDialog.qml"
rg -Fq 'marketplaceYellow: Color.accent' "$ROOT/ActionDialog.qml"
rg -Fq 'marketplaceRed: Color.urgent' "$ROOT/ActionDialog.qml"
rg -Fq 'readonly property color accent: Color.accent' \
  "$ROOT/PluginControl.qml"
rg -Fq 'color: marketplaceRed, tooltip: "Anonymous marketplace hearts"' \
  "$ROOT/ActionDialog.qml"
rg -Fq 'CatalogModel.activityState(' "$ROOT/ActionDialog.qml"
rg -Fq 'tooltip: "GitHub repository stars"' "$ROOT/ActionDialog.qml"
rg -Fq 'tooltip: "Marketplace detail views"' "$ROOT/ActionDialog.qml"
rg -Fq 'tooltip: "Successful command copies"' "$ROOT/ActionDialog.qml"
rg -Fq 'tooltip: "Anonymous marketplace hearts"' "$ROOT/ActionDialog.qml"
# Repository, author, version, source and the reviewed commit now render
# through one compact key/value list.
rg -Fq 'key: "Repository"' "$ROOT/ActionDialog.qml"
rg -Fq 'key: "Author"' "$ROOT/ActionDialog.qml"
rg -Fq 'key: "Version"' "$ROOT/ActionDialog.qml"
rg -Fq 'key: "Source"' "$ROOT/ActionDialog.qml"
rg -Fq 'key: "Reviewed"' "$ROOT/ActionDialog.qml"
rg -Fq 'not a security audit' "$ROOT/ActionDialog.qml"
rg -Fq 'does not mean "' "$ROOT/ActionDialog.qml"
rg -Fq 'root.plugin.tags' "$ROOT/ActionDialog.qml"
rg -Fq 'property bool pointerInteractive: true' "$ROOT/PaletteResultRow.qml"
row_hit_areas="$(rg -c 'MouseArea \{' "$ROOT/PaletteResultRow.qml")"
row_pointer_guards="$(rg -c 'cursorShape: root.pointerInteractive' \
  "$ROOT/PaletteResultRow.qml")"
if (( row_hit_areas != row_pointer_guards )); then
  fail "result row hit areas must share dialog pointer state"
fi
rg -Fq 'readonly property bool modalDialogOpened: actionDialog.opened' \
  "$ROOT/PluginControl.qml"
rg -Fq 'pointerInteractive: !root.modalDialogOpened' \
  "$ROOT/PluginControl.qml"
rg -Fq 'text: "Search plugins, or type \"plug-\" for commands."' \
  "$ROOT/PluginControl.qml"
rg -Fq 'fontSizeMode: Text.HorizontalFit' "$ROOT/PluginControl.qml"
rg -Fq 'visible: root.backgroundDim' "$ROOT/PluginControl.qml"
rg -Fq 'color: root.scrim' "$ROOT/PluginControl.qml"
rg -Fq 'id: previewClickArea' "$ROOT/ActionDialog.qml"
rg -Fq 'cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor' \
  "$ROOT/ActionDialog.qml"
rg -q 'applyBootstrap' "$ROOT/Service.qml"
rg -Fq 'readonly property var updateWarnings' "$ROOT/Service.qml"
rg -Fq 'readonly property string updateWarningText' "$ROOT/Service.qml"
rg -Fq 'property var refreshWarnings: []' "$ROOT/Service.qml"
rg -Fq 'readonly property bool hasRefreshWarnings' "$ROOT/PluginControl.qml"
rg -Fq 'readonly property string refreshWarningText' "$ROOT/PluginControl.qml"
rg -Fq 'readonly property bool refreshStatusUrgent' "$ROOT/PluginControl.qml"
rg -Fq 'return time + " (" + date + ")"' "$ROOT/PluginControl.qml"
# Both status streams still render; they share one slot in the action
# strip instead of owning a row of their own.
rg -Fq '? leftStatusText : rightStatusText' "$ROOT/PluginControl.qml"
rg -Fq 'statusText: root.stripStatusText' "$ROOT/PluginControl.qml"
rg -Fq 'horizontalAlignment: Text.AlignRight' "$ROOT/PaletteFooter.qml"
rg -Fq '"Last update: "' "$ROOT/PluginControl.qml"
rg -Fq '"Catalog refreshed: "' "$ROOT/PluginControl.qml"
rg -Fq '"Checking for updates..."' "$ROOT/PluginControl.qml"
# Update and catalog warnings still surface, now as one header icon
# whose tooltip carries both texts.
rg -Fq 'readonly property string combinedWarningText' "$ROOT/PluginControl.qml"
rg -Fq 'parts.push(updateWarningText)' "$ROOT/PluginControl.qml"
rg -Fq 'parts.push(refreshWarningText)' "$ROOT/PluginControl.qml"
rg -Fq 'action: "warning", label: combinedWarningText' \
  "$ROOT/PluginControl.qml"
rg -Fq 'panelBorder: root.shortcutColor' "$ROOT/PluginControl.qml"
if rg -q 'lastRefreshError|Offline/stale' "$ROOT/Service.qml" \
    "$ROOT/PluginControl.qml" "$ROOT/lib/backend"; then
  fail "legacy hard-failure refresh status remains"
fi
rg -Fq '"Updating plugins..."' "$ROOT/lib/backend/actions.sh"
rg -Fq '"Plugin already up-to-date!"' "$ROOT/lib/backend/actions.sh"
rg -Fq '"All plugins are up to date!"' "$ROOT/PluginControl.qml"
printf 'ok - footer source confirmation busy and bootstrap states\n'

open_body="$(sed -n '/function open(payloadJson)/,/^  }/p' \
  "$ROOT/PluginControl.qml")"
if grep -Eq 'curl|git|requestRefresh' <<<"$open_body"; then
  printf 'not ok - open path performs network or Git work\n' >&2
  exit 1
fi
printf 'ok - overlay open path has no network or Git action\n'

shared_shortcuts="$ROOT/../_shared/shortcuts"
if [[ -d $shared_shortcuts ]]; then
  cmp -s "$ROOT/lib/shortcuts/ShortcutFormat.js" \
    "$shared_shortcuts/ShortcutFormat.js"
  cmp -s "$ROOT/lib/shortcuts/HyprlandBinding.qml" \
    "$shared_shortcuts/HyprlandBinding.qml"
  printf 'ok - shared shortcut library copies are current\n'
else
  printf 'ok - shared shortcut comparison skipped outside the monorepo\n'
fi

runtime_root="$(mktemp -d /tmp/plugin-control-qml-load.XXXXXX)"
trap 'rm -rf -- "$runtime_root"' EXIT
mkdir -p "$runtime_root/config" "$runtime_root/home"
cp "$TEST_DIR/fixtures/qml-entrypoints/shell.qml" \
  "$runtime_root/config/shell.qml"
ln -s /usr/share/omarchy/shell/Commons "$runtime_root/config/Commons"
ln -s /usr/share/omarchy/shell/Ui "$runtime_root/config/Ui"
if ! env QT_QPA_PLATFORM=wayland HOME="$runtime_root/home" \
  XDG_CONFIG_HOME="$runtime_root/config" \
  XDG_CACHE_HOME="$runtime_root/cache" \
  XDG_STATE_HOME="$runtime_root/state" \
  OMARCHY_PATH=/usr/share/omarchy PLUGIN_CONTROL_SOURCE_DIR="$ROOT" \
  QML2_IMPORT_PATH=/usr/share/omarchy/shell \
  QML_IMPORT_PATH=/usr/share/omarchy/shell \
  timeout 20 quickshell -p "$runtime_root/config" --no-color \
  >"$runtime_root/quickshell.log" 2>&1; then
  sed -n '1,240p' "$runtime_root/quickshell.log" >&2
  exit 1
fi
grep -Fq 'PLUGIN_CONTROL_LOAD_OK service' "$runtime_root/quickshell.log"
grep -Fq 'PLUGIN_CONTROL_LOAD_OK overlay' "$runtime_root/quickshell.log"
grep -Fq 'PLUGIN_CONTROL_LOAD_OK bar-widget' "$runtime_root/quickshell.log"
grep -Fq 'PLUGIN_CONTROL_WATCH_OK fresh install save' \
  "$runtime_root/quickshell.log"
grep -Fq 'PLUGIN_CONTROL_INTERACTION_OK palette interactions' \
  "$runtime_root/quickshell.log"
test -f "$runtime_root/config/omarchy/ilyazar.plugin-control/channels.yaml"
if grep -Fq 'PLUGIN_CONTROL_LOAD_ERROR' "$runtime_root/quickshell.log"; then
  sed -n '1,240p' "$runtime_root/quickshell.log" >&2
  exit 1
fi
printf 'ok - fresh install watcher and entry points instantiate in Quickshell\n'
