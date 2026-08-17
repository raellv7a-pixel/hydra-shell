import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

PanelWindow {
  id: root

  screen: PanelService.workspaceManagerScreen
  anchors {
    top: true
    right: true
    bottom: true
    left: true
  }
  color: "transparent"

  WlrLayershell.namespace: "noctalia-workspace-manager-" + (screen?.name || "unknown")
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  readonly property var cfg: Settings.data.workspaceManager
  readonly property string presentationMode: cfg.presentationMode || "adaptive"
  readonly property bool floatingMode: presentationMode === "floating"
  readonly property bool framedBar: Settings.data.bar.barType === "framed"
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name) || "top"
  readonly property real barThickness: Style.getBarHeightForScreen(screen?.name)
  readonly property real frameThickness: Settings.data.bar.frameThickness || 8
  readonly property var normalWorkspaces: Hyprland.workspaces.values.filter(workspace => !workspace.name.startsWith("special:") && workspace.monitor?.name === root.screen?.name).sort((left, right) => left.id - right.id)
  readonly property var specialWorkspaces: Hyprland.workspaces.values.filter(workspace => workspace.name.startsWith("special:")).sort((left, right) => left.id - right.id)

  property bool showingSettings: false
  property bool closing: false
  property real revealProgress: 0
  property bool dragging: false
  property string dragAddr: ""
  property int dragSrcWs: -999
  property var dragTl: null
  property bool newWorkspacePrivate: false
  property string specialLaunchCommand: ""

  property bool overviewGrid: false
  property string searchQuery: ""
  property var selectedWindowAddresses: []
  property string tagFilterQuery: ""
  property var privateWindowOverrides: ({})
  property real swipeX: 0
  property real swipeY: 0

  readonly property bool gameMode: cfg.gameMode || false
  readonly property var recentWorkspaces: HyprlandService.recentWorkspaces || []

  readonly property var privateWindowToastInfo: {
    const toplevels = Hyprland.toplevels.values || [];
    for (let i = 0; i < toplevels.length; i++) {
      const tl = toplevels[i];
      const ipc = tl?.lastIpcObject;
      const wsName = tl?.workspace?.name || String(tl?.workspace?.id || "");
      if (!wsName || root.isWorkspacePrivate(tl?.workspace?.id, wsName))
        continue;
      if (ipc?.no_screen_share === true || ipc?.setprop_no_screen_share === 1) {
        return {
          "title": ipc?.title || ipc?.class || "Window",
          "workspace": wsName
        };
      }
    }
    return null;
  }

  function requestClose() {
    if (closing)
      return;
    closing = true;
    revealProgress = 0;
    closeTimer.restart();
  }

  function startDrag(toplevel, address, sourceWorkspace) {
    dragging = true;
    dragAddr = address;
    dragSrcWs = sourceWorkspace;
    dragTl = toplevel;
  }

  function endDrag() {
    dragging = false;
    dragAddr = "";
    dragSrcWs = -999;
    dragTl = null;
  }

  function switchWorkspace(workspaceId, workspaceName) {
    const useName = workspaceName && (workspaceName.startsWith("special:") || String(workspaceName) !== String(workspaceId));
    CompositorService.switchToWorkspace(useName ? {
                                                    "name": workspaceName
                                                  } : {
                                          "idx": workspaceId
                                        });
    requestClose();
  }

  function moveWindowToWs(address, workspaceId, workspaceName) {
    const useName = workspaceName && (workspaceName.startsWith("special:") || String(workspaceName) !== String(workspaceId));
    CompositorService.moveWindowToWorkspace(address, useName ? {
                                                                 "name": workspaceName
                                                               } : {
                                              "idx": workspaceId
                                            });
  }

  function closeWindow(toplevel, address) {
    if (toplevel?.wayland)
      toplevel.wayland.close();
    else
      CompositorService.closeWindowByAddress(address);
    Hyprland.refreshToplevels();
    Hyprland.refreshWorkspaces();
  }

  function isWorkspacePrivate(workspaceId, workspaceName) {
    const key = workspaceName || String(workspaceId);
    return Array.from(root.cfg.privateWorkspaces || []).includes(key);
  }

  function toggleWorkspacePrivacy(workspaceId, workspaceName, enabled) {
    CompositorService.setWorkspacePrivate(workspaceName ? {
                                                            "name": workspaceName,
                                                            "idx": workspaceId
                                                          } : {
                                            "idx": workspaceId
                                          }, enabled);
  }

  function toggleWindowSelection(address) {
    if (!address)
      return;
    const current = Array.from(selectedWindowAddresses || []);
    const idx = current.indexOf(address);
    if (idx !== -1)
      current.splice(idx, 1);
    else
      current.push(address);
    selectedWindowAddresses = current;
  }

  function clearWindowSelection() {
    selectedWindowAddresses = [];
  }

  function batchMoveSelected(targetWsId, targetWsName) {
    const addrs = Array.from(selectedWindowAddresses || []);
    for (let i = 0; i < addrs.length; i++) {
      moveWindowToWs(addrs[i], targetWsId, targetWsName);
    }
    clearWindowSelection();
  }

  function batchCloseSelected() {
    const addrs = Array.from(selectedWindowAddresses || []);
    for (let i = 0; i < addrs.length; i++) {
      CompositorService.closeWindowByAddress(addrs[i]);
    }
    clearWindowSelection();
    Hyprland.refreshToplevels();
    Hyprland.refreshWorkspaces();
  }

  function batchToggleFloatSelected() {
    const addrs = Array.from(selectedWindowAddresses || []);
    for (let i = 0; i < addrs.length; i++) {
      const addr = addrs[i].startsWith("0x") ? addrs[i] : `0x${addrs[i]}`;
      Quickshell.execDetached(["hyprctl", "dispatch", "togglefloating", `address:${addr}`]);
    }
    clearWindowSelection();
  }

  function batchSetPrivateSelected(enabled) {
    const addrs = Array.from(selectedWindowAddresses || []);
    const overrides = Object.assign({}, privateWindowOverrides);
    for (let i = 0; i < addrs.length; i++) {
      const addr = addrs[i].startsWith("0x") ? addrs[i] : `0x${addrs[i]}`;
      overrides[addr] = enabled;
      Quickshell.execDetached(["hyprctl", "setprop", `address:${addr}`, "no_screen_share", enabled ? "1" : "unset"]);
    }
    privateWindowOverrides = overrides;
    clearWindowSelection();
  }

  function isWindowPrivate(address, fallback) {
    const addr = String(address || "");
    const normalized = addr.startsWith("0x") ? addr : `0x${addr}`;
    return privateWindowOverrides[normalized] !== undefined ? privateWindowOverrides[normalized] : fallback;
  }

  function batchAddTagSelected(tagName) {
    const cleanTag = String(tagName || "").trim();
    if (!cleanTag)
      return;
    const addrs = Array.from(selectedWindowAddresses || []);
    for (let i = 0; i < addrs.length; i++) {
      const addr = addrs[i].startsWith("0x") ? addrs[i] : `0x${addrs[i]}`;
      Quickshell.execDetached(["hyprctl", "dispatch", "tagwindow", `+${cleanTag}`, `address:${addr}`]);
    }
    clearWindowSelection();
  }

  function toggleGameMode() {
    const next = !gameMode;
    cfg.gameMode = next;
    HyprlandService.applyGameMode(next);
  }

  function searchResults() {
    if (!searchQuery)
      return [];
    const results = [];
    const toplevels = Hyprland.toplevels.values || [];
    for (let i = 0; i < toplevels.length; i++) {
      const tl = toplevels[i];
      const ipc = tl?.lastIpcObject;
      const title = String(ipc?.title || "").toLowerCase();
      const cls = String(ipc?.class || ipc?.initialClass || "").toLowerCase();
      const wsName = String(tl?.workspace?.name || tl?.workspace?.id || "").toLowerCase();
      const tags = Array.from(ipc?.tags || []).join(" ").toLowerCase();
      if (title.includes(searchQuery) || cls.includes(searchQuery) || wsName.includes(searchQuery) || tags.includes(searchQuery)) {
        results.push({
                       "addr": ipc?.address,
                       "title": ipc?.title || cls || "Window",
                       "class": cls,
                       "tags": tags,
                       "workspaceId": tl?.workspace?.id,
                       "workspaceName": tl?.workspace?.name || String(tl?.workspace?.id || ""),
                       "isPrivate": root.isWorkspacePrivate(tl?.workspace?.id, tl?.workspace?.name) || ipc?.no_screen_share === true
                     });
      }
    }
    return results;
  }

  function focusSearchResult(result) {
    if (!result?.addr)
      return;
    CompositorService.focusWindowByAddress(result.addr);
    requestClose();
  }

  function moveWorkspaceOrder(workspaceId, offset) {
    const visibleIds = normalWorkspaces.map(workspace => String(workspace.id));
    let order = Array.from(cfg.customOrder || []).filter(id => visibleIds.includes(id));
    for (let i = 0; i < visibleIds.length; i++) {
      if (!order.includes(visibleIds[i]))
        order.push(visibleIds[i]);
    }
    const key = String(workspaceId);
    const from = order.indexOf(key);
    const to = Math.max(0, Math.min(order.length - 1, from + offset));
    if (from < 0 || from === to)
      return;
    order.splice(from, 1);
    order.splice(to, 0, key);
    cfg.customOrder = order;
  }

  function openCreateWorkspace() {
    showingSettings = true;
    Qt.callLater(() => specialNameInput.inputItem.forceActiveFocus());
  }

  function createSpecialWorkspace() {
    const cleanName = specialNameInput.text.trim().replace(/^special:/, "");
    if (!cleanName)
      return;
    if (HyprlandService.createSpecialWorkspace) {
      HyprlandService.createSpecialWorkspace(cleanName, newWorkspacePrivate, specialLaunchCommand);
    } else {
      const workspace = {
        "name": "special:" + cleanName
      };
      if (newWorkspacePrivate)
        CompositorService.setWorkspacePrivate(workspace, true);
      CompositorService.switchToWorkspace(workspace);
      if (specialLaunchCommand.trim())
        Quickshell.execDetached(["sh", "-c", specialLaunchCommand.trim()]);
    }
    specialNameInput.text = "";
    specialLaunchCommand = "";
    newWorkspacePrivate = false;
    showingSettings = false;
  }

  Component.onCompleted: {
    overviewGrid = PanelService.workspaceManagerOverviewMode;
    revealProgress = 1;
    panelFocusScope.forceActiveFocus();
  }

  Connections {
    target: PanelService
    function onWorkspaceManagerOverviewModeChanged() {
      if (PanelService.workspaceManagerOverviewMode)
        root.overviewGrid = true;
    }
  }

  Behavior on revealProgress {
    NumberAnimation {
      duration: Settings.data.general.animationDisabled ? 0 : (root.closing ? 210 : 290)
      easing.type: root.closing ? Easing.InCubic : Easing.OutQuint
    }
  }

  Timer {
    id: closeTimer
    interval: Settings.data.general.animationDisabled ? 1 : 220
    onTriggered: PanelService.closeWorkspaceManager()
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    onActivated: root.requestClose()
  }

  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: root.cfg.dimBackground ? (root.floatingMode ? 0.38 : 0.1) * root.revealProgress : 0

    MouseArea {
      anchors.fill: parent
      onClicked: root.requestClose()
    }
  }

  FocusScope {
    id: panelFocusScope
    anchors.fill: parent
    focus: true

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        root.requestClose();
        event.accepted = true;
      } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
        const wsNum = event.key - Qt.Key_0;
        root.switchWorkspace(wsNum, String(wsNum));
        event.accepted = true;
      } else if (event.key === Qt.Key_P) {
        const curr = CompositorService.getCurrentWorkspace();
        if (curr)
          root.toggleWorkspacePrivacy(curr.id, curr.name, !root.isWorkspacePrivate(curr.id, curr.name));
        event.accepted = true;
      } else if (event.key === Qt.Key_S) {
        cfg.hideSpecials = !cfg.hideSpecials;
        event.accepted = true;
      } else if (event.key === Qt.Key_O) {
        root.overviewGrid = !root.overviewGrid;
        event.accepted = true;
      } else if (event.key === Qt.Key_G) {
        root.toggleGameMode();
        event.accepted = true;
      }
    }

    Rectangle {
      id: panel
      z: 2
      width: {
        if (root.floatingMode)
          return Math.min(root.width - 2 * Style.margin2L, 980 * Style.uiScaleRatio);
        if (root.framedBar)
          return Math.min(root.width * 0.46, 820 * Style.uiScaleRatio);
        return Math.min(root.width - 2 * Style.margin2L, 940 * Style.uiScaleRatio);
      }
      height: Math.min(root.height - root.barThickness - 3 * Style.marginL, 620 * Style.uiScaleRatio)
      x: {
        if (root.floatingMode)
          return Math.round((root.width - width) / 2);
        if (root.framedBar || root.barPosition === "right")
          return root.width - width;
        if (root.barPosition === "left")
          return 0;
        return Math.round((root.width - width) / 2);
      }
      y: {
        if (root.floatingMode)
          return Math.round((root.height - height) / 2);
        const topInset = root.barPosition === "top" ? root.barThickness : root.frameThickness;
        const bottomInset = root.barPosition === "bottom" ? root.barThickness : root.frameThickness;
        if (root.barPosition === "top" && !root.framedBar)
          return topInset + Style.marginM;
        if (root.barPosition === "bottom" && !root.framedBar)
          return root.height - bottomInset - Style.marginM - height;
        return Math.round(topInset + (root.height - topInset - bottomInset - height) / 2);
      }
      radius: Style.radiusL * 1.65
      color: Color.mSurface
      border.width: Style.borderS
      border.color: Qt.alpha(Color.mOutline, 0.44)
      opacity: root.revealProgress
      scale: root.floatingMode ? 0.965 + 0.035 * root.revealProgress : 1
      transform: [
        Translate {
          x: {
            if (root.floatingMode)
              return 0;
            if (root.framedBar || root.barPosition === "right")
              return (1 - root.revealProgress) * panel.width;
            if (root.barPosition === "left")
              return -(1 - root.revealProgress) * panel.width;
            return 0;
          }
          y: {
            if (root.floatingMode || root.framedBar || root.barPosition === "left" || root.barPosition === "right")
              return 0;
            return (root.barPosition === "bottom" ? 1 : -1) * (1 - root.revealProgress) * panel.height;
          }
        },
        Translate {
          x: root.swipeX
          y: root.swipeY
        }
      ]

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => mouse.accepted = true
      }

      DragHandler {
        id: swipeOutHandler
        target: null
        yAxis.enabled: true
        xAxis.enabled: true
        grabPermissions: PointerHandler.CanTakeOverFromHandlersOfSameType
        onActiveTranslationChanged: {
          root.swipeX = activeTranslation.x;
          root.swipeY = activeTranslation.y;
        }
        onActiveChanged: {
          if (!active) {
            if (Math.abs(root.swipeX) > 140 || Math.abs(root.swipeY) > 140)
              root.requestClose();
            root.swipeX = 0;
            root.swipeY = 0;
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        Rectangle {
          Layout.fillWidth: true
          height: 28 * Style.uiScaleRatio
          radius: Style.radiusS
          color: Qt.alpha(Color.mErrorContainer, 0.9)
          visible: root.privateWindowToastInfo !== null

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginS
            spacing: Style.marginS

            NIcon {
              icon: "alert-triangle"
              pointSize: Style.fontSizeS
              color: Color.mOnErrorContainer || Color.mOnError
            }
            NText {
              Layout.fillWidth: true
              text: qsTr("⚠️ Private window '%1' is in public workspace '%2'").arg(root.privateWindowToastInfo?.title || "").arg(root.privateWindowToastInfo?.workspace || "")
              pointSize: Style.fontSizeXS
              color: Color.mOnErrorContainer || Color.mOnError
              font.weight: Style.fontWeightBold
            }
            NButton {
              text: qsTr("Protect WS")
              icon: "shield-lock"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: {
                if (root.privateWindowToastInfo?.workspace)
                  root.toggleWorkspacePrivacy(0, root.privateWindowToastInfo.workspace, true);
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: root.showingSettings ? "settings" : (root.overviewGrid ? "layout-grid" : "apps")
            pointSize: Style.fontSizeXL
            color: Color.mPrimary
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            NText {
              Layout.fillWidth: true
              text: root.showingSettings ? qsTr("Workspace manager settings") : (root.overviewGrid ? qsTr("Overview mode") : qsTr("Workspace manager"))
              pointSize: Style.fontSizeXL
              font.weight: Style.fontWeightBold
            }
            NText {
              Layout.fillWidth: true
              text: root.showingSettings ? qsTr("Layout, previews and workspace privacy") : qsTr("Hold a window to move · 'o' grid mode · 'g' game mode · 'p' privacy")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          NIconButton {
            icon: root.overviewGrid ? "carousel-horizontal" : "layout-grid"
            tooltipText: root.overviewGrid ? qsTr("Carousel view") : qsTr("Overview grid view")
            onClicked: root.overviewGrid = !root.overviewGrid
          }
          NIconButton {
            icon: root.gameMode ? "device-gamepad-filled" : "device-gamepad"
            colorFg: root.gameMode ? Color.mPrimary : Color.mOnSurfaceVariant
            tooltipText: root.gameMode ? qsTr("Disable Game Mode") : qsTr("Enable Game Mode (Performance)")
            onClicked: root.toggleGameMode()
          }
          NIconButton {
            icon: root.showingSettings ? "arrow-left" : "settings"
            tooltipText: root.showingSettings ? qsTr("Back") : qsTr("Settings")
            onClicked: root.showingSettings = !root.showingSettings
          }
          NIconButton {
            icon: "close"
            tooltipText: qsTr("Close")
            onClicked: root.requestClose()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: !root.showingSettings

          NTextInput {
            id: searchInput
            Layout.fillWidth: true
            placeholderText: qsTr("Search workspace, window title, class or tag…")
            text: root.searchQuery
            onTextChanged: root.searchQuery = text.trim().toLowerCase()
            onAccepted: {
              const results = root.searchResults();
              if (results.length > 0)
                root.focusSearchResult(results[0]);
            }
          }

          Row {
            spacing: Style.marginXS
            visible: root.recentWorkspaces.length > 0 && !root.searchQuery

            NText {
              anchors.verticalCenter: parent.verticalCenter
              text: qsTr("Recent:")
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            Repeater {
              model: root.recentWorkspaces.slice(0, 5)
              delegate: Rectangle {
                width: recentLabel.implicitWidth + Style.marginM
                height: 24 * Style.uiScaleRatio
                radius: height / 2
                color: Qt.alpha(Color.mSurfaceContainerHigh, 0.9)
                border.width: 1
                border.color: Qt.alpha(Color.mOutline, 0.5)

                NText {
                  id: recentLabel
                  anchors.centerIn: parent
                  text: modelData
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurface
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (/^\d+$/.test(modelData))
                      root.switchWorkspace(parseInt(modelData), modelData);
                    else
                      root.switchWorkspace(0, modelData);
                  }
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 36 * Style.uiScaleRatio
          radius: Style.radiusM
          color: Qt.alpha(Color.mPrimaryContainer || Color.mPrimary, 0.9)
          visible: root.selectedWindowAddresses.length > 0

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginS
            spacing: Style.marginS

            NText {
              text: qsTr("%1 window(s) selected").arg(root.selectedWindowAddresses.length)
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: Color.mOnPrimaryContainer || Color.mOnPrimary
            }

            Item {
              Layout.fillWidth: true
            }

            NButton {
              text: qsTr("Move here")
              icon: "arrow-right"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: {
                const curr = CompositorService.getCurrentWorkspace();
                if (curr)
                  root.batchMoveSelected(curr.id, curr.name);
              }
            }
            NButton {
              text: qsTr("Close")
              icon: "x"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: root.batchCloseSelected()
            }
            NButton {
              text: qsTr("Float")
              icon: "window"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: root.batchToggleFloatSelected()
            }
            NButton {
              text: qsTr("Private")
              icon: "shield-lock"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: root.batchSetPrivateSelected(true)
            }
            NButton {
              text: qsTr("Clear")
              icon: "x"
              fontSize: Style.fontSizeXS
              iconSize: Style.fontSizeS
              onClicked: root.clearWindowSelection()
            }
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.showingSettings ? 1 : (root.searchQuery ? 2 : 0)

          ColumnLayout {
            spacing: Style.marginM
            visible: !root.searchQuery

            Flickable {
              visible: root.overviewGrid
              Layout.fillWidth: true
              Layout.fillHeight: true
              contentWidth: width
              contentHeight: gridFlow.height
              clip: true

              Flow {
                id: gridFlow
                width: parent.width
                spacing: Style.marginM

                Repeater {
                  model: root.normalWorkspaces
                  delegate: Item {
                    width: Math.round((gridFlow.width - Style.marginM) / 2)
                    height: Math.round(width * 0.58)

                    WorkspaceCell {
                      anchors.fill: parent
                      wsId: modelData.id
                      wsName: modelData.name
                      overview: root
                      isSpecial: false
                      livePreviews: root.cfg.livePreviews && !root.gameMode
                      isPrivate: root.isWorkspacePrivate(modelData.id, modelData.name)
                      inViewport: root.overviewGrid
                    }
                  }
                }
              }
            }

            ColumnLayout {
              visible: !root.overviewGrid
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.marginM

              WorkspaceCarousel {
                Layout.fillWidth: true
                overview: root
                title: qsTr("Workspaces")
                workspaces: root.normalWorkspaces.length ? root.normalWorkspaces : [
                                                             {
                                                               "id": 1,
                                                               "name": "1"
                                                             }
                                                           ]
                livePreviews: root.cfg.livePreviews && !root.gameMode
              }
              WorkspaceCarousel {
                Layout.fillWidth: true
                overview: root
                title: qsTr("Special workspaces")
                workspaces: root.specialWorkspaces
                special: true
                livePreviews: root.cfg.livePreviews && !root.gameMode
              }
              Item {
                Layout.fillHeight: true
              }
            }
          }

          Flickable {
            contentWidth: width
            contentHeight: settingsContent.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: settingsContent
              width: parent.width
              spacing: Style.marginL

              NText {
                text: qsTr("Presentation & Performance")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NButton {
                  Layout.fillWidth: true
                  text: qsTr("Adaptive")
                  icon: "columns"
                  outlined: root.presentationMode !== "adaptive"
                  onClicked: root.cfg.presentationMode = "adaptive"
                }
                NButton {
                  Layout.fillWidth: true
                  text: qsTr("Floating")
                  icon: "window"
                  outlined: root.presentationMode !== "floating"
                  onClicked: root.cfg.presentationMode = "floating"
                }
              }

              NToggle {
                Layout.fillWidth: true
                label: qsTr("Game Mode / Performance")
                description: qsTr("Disables Hyprland blur/animations/gaps and uses lightweight static previews.")
                checked: root.gameMode
                onToggled: root.toggleGameMode()
              }

              NToggle {
                Layout.fillWidth: true
                label: qsTr("Live previews")
                description: qsTr("Protected windows are replaced by a privacy card.")
                checked: root.cfg.livePreviews
                onToggled: checked => root.cfg.livePreviews = checked
              }
              NToggle {
                Layout.fillWidth: true
                label: qsTr("Border-only privacy mode")
                description: qsTr("Shows only a colored border for private workspaces instead of cards.")
                checked: root.cfg.borderOnlyPrivacy || false
                onToggled: checked => root.cfg.borderOnlyPrivacy = checked
              }
              NToggle {
                Layout.fillWidth: true
                label: qsTr("Dim background")
                description: qsTr("Reduce distractions behind the workspace panel.")
                checked: root.cfg.dimBackground
                onToggled: checked => root.cfg.dimBackground = checked
              }

              NDivider {
                Layout.fillWidth: true
              }

              NText {
                text: qsTr("Create a special workspace")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
              }
              NTextInput {
                id: specialNameInput
                Layout.fillWidth: true
                label: qsTr("Workspace name")
                placeholderText: qsTr("music, chat, private…")
                onAccepted: root.createSpecialWorkspace()
              }
              NTextInput {
                id: specialCmdInput
                Layout.fillWidth: true
                label: qsTr("Auto-launch application (optional)")
                placeholderText: qsTr("kitty, foot, firefox, Discord…")
                text: root.specialLaunchCommand
                onTextChanged: root.specialLaunchCommand = text
              }
              NToggle {
                Layout.fillWidth: true
                label: qsTr("Create as private")
                description: qsTr("Hyprland will hide every window in this workspace from screen sharing.")
                checked: root.newWorkspacePrivate
                onToggled: checked => root.newWorkspacePrivate = checked
              }
              NButton {
                Layout.fillWidth: true
                text: qsTr("Create and open")
                icon: root.newWorkspacePrivate ? "shield-lock" : "plus"
                enabled: specialNameInput.text.trim().length > 0
                onClicked: root.createSpecialWorkspace()
              }

              NDivider {
                Layout.fillWidth: true
              }

              NText {
                text: qsTr("Batch Tag Actions")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                NTextInput {
                  id: tagInput
                  Layout.fillWidth: true
                  label: qsTr("Tag name")
                  placeholderText: qsTr("code, media, dev…")
                }
                NTextInput {
                  id: tagTargetWsInput
                  Layout.fillWidth: true
                  label: qsTr("Target Workspace")
                  placeholderText: qsTr("1, 2, special:chat…")
                }
              }

              NButton {
                Layout.fillWidth: true
                text: qsTr("Move all windows with tag to target workspace")
                icon: "arrow-right"
                enabled: tagInput.text.trim().length > 0 && tagTargetWsInput.text.trim().length > 0
                onClicked: {
                  const tag = tagInput.text.trim();
                  const target = tagTargetWsInput.text.trim();
                  if (tag && target) {
                    Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", `${target},tag:${tag}`]);
                  }
                }
              }
            }
          }

          Flickable {
            contentWidth: width
            contentHeight: searchResultsCol.implicitHeight
            clip: true

            ColumnLayout {
              id: searchResultsCol
              width: parent.width
              spacing: Style.marginS

              NText {
                text: qsTr("Search Results for '%1'").arg(root.searchQuery)
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
              }

              Repeater {
                model: root.searchResults()
                delegate: Rectangle {
                  Layout.fillWidth: true
                  height: 48 * Style.uiScaleRatio
                  radius: Style.radiusM
                  color: itemArea.containsMouse ? Color.mSurfaceContainerHigh : Color.mSurfaceContainer
                  border.width: Style.borderS
                  border.color: itemArea.containsMouse ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.4)

                  RowLayout {
                    z: 1
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NIcon {
                      icon: modelData.isPrivate ? "shield-lock" : "window"
                      pointSize: Style.fontSizeM
                      color: modelData.isPrivate ? Color.mPrimary : Color.mOnSurfaceVariant
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      NText {
                        text: modelData.isPrivate ? qsTr("Private Window") : modelData.title
                        pointSize: Style.fontSizeS
                        font.weight: Style.fontWeightBold
                        elide: Text.ElideRight
                      }
                      NText {
                        text: qsTr("Class: %1 · WS: %2").arg(modelData.class).arg(modelData.workspaceName)
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                      }
                    }

                    NButton {
                      text: qsTr("Focus")
                      icon: "eye"
                      fontSize: Style.fontSizeXS
                      iconSize: Style.fontSizeS
                      onClicked: {
                        root.focusSearchResult(modelData);
                      }
                    }
                    NButton {
                      text: qsTr("Move to Current")
                      icon: "arrow-right"
                      fontSize: Style.fontSizeXS
                      iconSize: Style.fontSizeS
                      onClicked: {
                        const curr = CompositorService.getCurrentWorkspace();
                        if (curr)
                          root.moveWindowToWs(modelData.addr, curr.id, curr.name);
                      }
                    }
                  }

                  MouseArea {
                    id: itemArea
                    z: 0
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.focusSearchResult(modelData);
                    }
                  }
                }
              }
            }
          }
        }

        NText {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: root.dragging ? qsTr("Scroll to navigate · release over a workspace to move the window") : (root.selectedWindowAddresses.length > 0 ? qsTr("Use batch bar above to move, close or protect selected windows") : qsTr("Hold window to move · Shift/Ctrl+Click multi-select · Esc to close"))
          pointSize: Style.fontSizeXS
          color: root.dragging ? Color.mPrimary : Color.mOnSurfaceVariant
        }
      }
    }
  }
}
