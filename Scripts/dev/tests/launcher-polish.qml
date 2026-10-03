import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Modules.MainScreen.Backgrounds
import qs.Modules.Panels.Launcher
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// Runs only in a private test checkout facade/XDG runtime. Product components
// are real; the test runner supplies read-only ALPM/Shelly command fixtures.
ShellRoot {
  id: root
  property bool showingLauncher: false
  property var savedResults: null
  property var savedRow: null
  property var savedEntry: null
  property var savedPanel: null
  property var savedActionRow: null

  function findItem(item, propertyName) {
    if (!item)
      return null;
    if (item[propertyName] !== undefined)
      return item;
    for (const child of item.children || []) {
      const found = findItem(child, propertyName);
      if (found)
        return found;
    }
    return null;
  }

  function findAction(item, actionId) {
    if (!item)
      return null;
    if (item.isConfirming !== undefined && item.modelData?.id === actionId)
      return item;
    for (const child of item.children || []) {
      const found = findAction(child, actionId);
      if (found)
        return found;
    }
    return null;
  }

  PanelWindow {
    id: window
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hydra-polish-regression"
    color: Color.mSurface

    Item {
      visible: !root.showingLauncher
      QtObject {
        id: panel
        property var panelRegion: region
        property bool cachedShouldAnimateWidth: false
        property bool cachedShouldAnimateHeight: true
        property bool cachedAnimateFromTop: true
        property bool cachedAnimateFromBottom: false
        property bool cachedAnimateFromLeft: false
        property bool cachedAnimateFromRight: false
      }
      QtObject {
        id: region
        property bool visible: true
        property var panelItem: geometry
      }
      Rectangle {
        id: geometry
        x: 120
        y: 120
        width: 360
        height: 220
        radius: 24
        color: "#f3eef4"
        property real targetWidth: 360
        property real targetHeight: 220
      }
      PanelRevealSeam {
        id: seam
        assignedPanel: panel
      }
      Row {
        x: 120
        y: 450
        spacing: 24
        NButton {
          id: a
          text: "A"
          backgroundColor: "transparent"
        }
        NButton {
          id: b
          text: "B"
          backgroundColor: "transparent"
        }
        NIconButton {
          id: c
          icon: "settings"
          colorBg: "transparent"
        }
      }
    }

    LauncherCore {
      id: core
      x: 140
      y: 20
      width: 720
      height: 740
      screen: window.screen
      visible: root.showingLauncher
      isOpen: root.showingLauncher
    }
  }

  IpcHandler {
    target: "test"
    function prepare(): void {
    root.showingLauncher = true;
    Settings.data.appLauncher.viewMode = "list";
    Settings.data.appLauncher.showCategories = false;
    Settings.data.appLauncher.sortByMostUsed = false;
    core.closeAppPanel();
    const entries = [];
    for (let i = 0; i < 100; i++) {
      const id = "app-" + String(i).padStart(3, "0");
      entries.push({
        id: id,
        name: id,
        command: [id],
        categories: ["System"],
        icon: Quickshell.iconPath("application-x-executable", true)
      });
    }
    core.defaultProvider.entries = entries;
    core.defaultProvider.selectedCategory = "all";
    core.providers = [core.defaultProvider];
    core.searchText = "";
    core.updateResults();
  }
    function panel(index: int): void {
    core.openAppPanel(core.results[index]);
    core.showAppProperties(core.results[index]);
  }
    function position(): void {
                           core.resultsView.contentY = Math.max(600, core.resultsView.currentItem.y - 100);
                         }
    function remember(): void {
    root.savedResults = core.results;
    root.savedRow = core.resultsView.currentItem;
    root.savedEntry = root.findItem(root.savedRow, "badgeState");
    root.savedPanel = root.findItem(root.savedRow, "contentAlive");
    root.savedActionRow = root.findItem(root.savedPanel, "isConfirming");
  }
    function showActions(): void {
                              core.appPanelShowingProperties = false;
                            }
    function actionLocation(actionId: string): string {
      const panel = root.findItem(core.resultsView.currentItem, "contentAlive");
      const action = root.findAction(panel, actionId);
      return JSON.stringify(action ? action.mapToItem(window.contentItem, action.width / 2, action.height / 2) : null);
    }
    function scan(): void {
    PackageManagerService.refresh(true);
  }
    function update(index: int): void {
    core.defaultProvider.updateApp(core.results[index]);
  }
    function remove(index: int): void {
    core.defaultProvider.removeApp(core.results[index]);
  }
    function clearUpdates(): void {
                               PackageManagerService.updateRecords = [];
                             }
    function contains(appId: string): bool {
      return core.results.some(entry => entry.appId === appId);
    }
    function requestPanel(appId: string): void {
    PanelService.pendingLauncherAppPanelId = appId;
  }
    function search(query: string): void {
    core.closeAppPanel();
    core.searchText = query;
    core.updateResults();
  }
    function keyDown(): void {
                          core.closeAppPanel();
                          core.handleKeyPress({
                                                key: Qt.Key_Down,
                                                modifiers: Qt.NoModifier,
                                                accepted: false
                                              }, core.results.length);
                        }
    function snapshot(): string {
      const row = core.resultsView.currentItem;
      const entry = root.findItem(row, "badgeState");
      const panel = root.findItem(row, "contentAlive");
      const actionRow = root.findItem(panel, "isConfirming");
      const location = panel ? panel.mapToItem(window.contentItem, 0, 0) : null;
      const center = entry ? entry.mapToItem(window.contentItem, entry.width / 2, entry.height / 2) : null;
      return JSON.stringify({
                              y: core.resultsView.contentY,
                              selected: core.results[core.selectedIndex]?.appId,
                              panel: core.appPanelItem?.appId,
                              open: core.appPanelOpen,
                              pendingPanel: PanelService.pendingLauncherAppPanelId,
                              properties: core.appPanelShowingProperties,
                              panelY: location?.y,
                              panelHeight: panel?.height,
                              panelTargetHeight: panel?.implicitHeight,
                              resultsStable: root.savedResults === core.results,
                              rowStable: root.savedRow === row,
                              entryStable: root.savedEntry === entry,
                              panelStable: root.savedPanel === panel,
                              actionPresent: !!actionRow,
                              actionStable: root.savedActionRow === actionRow,
                              badge: entry?.badgeState.badgeIcon,
                              selectedStyle: entry?.isSelected,
                              hoveredStyle: entry?.isHovered,
                              contextTarget: entry?.isContextMenuTarget,
                              entryColor: entry ? String(entry.color) : "",
                              entryCenter: center,
                              actions: core.appPanelActions.map(action => ({
                                                                             id: action.id,
                                                                             enabled: action.enabled,
                                                                             busy: action.busy,
                                                                             label: action.label
                                                                           })),
                              count: core.results.length
                            });
    }
    function state(): string {
      return JSON.stringify({
                              ready: PackageManagerService.metadataReady,
                              scan: PackageManagerService.scanRunning,
                              busy: PackageManagerService.busy,
                              phase: PackageManagerService.operationState,
                              records: PackageManagerService.updateRecords.length,
                              error: PackageManagerService.lastError || PackageManagerService.scanError
                            });
    }
    function mapping(choice: int): string {
      const apps = [
              {
                id: "code",
                command: ["code"],
                name: "Code"
              },
              {
                id: "org.mozilla.firefox",
                command: ["flatpak", "run", "--branch=stable", "--arch=x86_64", "--command", "org.not.TheApp", "org.mozilla.firefox"],
                name: "Firefox"
              },
              {
                id: "manual",
                command: ["/opt/manual/code"],
                name: "Manual"
              },
              {
                id: "stale",
                command: ["flatpak", "run", "org.not.Installed"],
                name: "Stale"
              }
            ];
      const app = apps[choice];
      const entry = core.defaultProvider.createResultEntry(app);
      const action = core.defaultProvider.getContextMenuActions(entry).find(action => action.id === "uninstall");
      return JSON.stringify({
                              package: core.defaultProvider.getPackageForApp(app),
                              removeEnabled: action.enabled
                            });
    }
    function setGeometry(height: real): string {
      root.showingLauncher = false;
      geometry.height = height;
      return JSON.stringify({
                              visible: seam.visible,
                              opacity: seam.opacity
                            });
    }
    function hover(index: int): void {
    root.showingLauncher = false;
    a.hovered = index === 0;
    b.hovered = index === 1;
    c.hovering = index === 2;
  }
    function hoverState(): string {
      return JSON.stringify({
        a: root.findItem(a, "color").color.a,
        b: root.findItem(b, "color").color.a,
        c: root.findItem(c, "color").color.a,
        enter: Style.hoverEnterDuration,
        leave: Style.hoverLeaveDuration
      });
    }
  }
}
