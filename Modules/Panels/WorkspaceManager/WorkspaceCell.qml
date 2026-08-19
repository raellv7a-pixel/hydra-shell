import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.Commons
import qs.Services.Compositor
import qs.Widgets

Item {
  id: cell

  property int wsId: 0
  property string wsName: ""
  property var overview: null
  property bool isSpecial: false
  property bool livePreviews: true
  property bool isPrivate: false
  property bool inViewport: true

  readonly property var activeMonitor: overview?.screen ? Hyprland.monitors.values.find(monitor => monitor.name === overview.screen.name) : null
  readonly property bool active: !isSpecial && activeMonitor && (activeMonitor.activeWorkspace?.id === wsId || activeMonitor.activeWorkspace?.name === wsName)
  readonly property bool isDropTarget: overview?.dragging && dropArea.containsDrag
  readonly property bool borderOnlyPrivacy: Settings.data.workspaceManager.borderOnlyPrivacy || false
  readonly property string layoutName: {
    const workspace = (Hyprland.workspaces.values || []).find(ws => ws.id === cell.wsId || ws.name === cell.wsName);
    return workspace?.lastIpcObject?.tiledLayout || workspace?.tiledLayout || "dwindle";
  }

  readonly property bool isUrgent: {
    const toplevels = Hyprland.toplevels.values || [];
    for (let i = 0; i < toplevels.length; i++) {
      const tl = toplevels[i];
      if (tl?.workspace?.id === cell.wsId || tl?.workspace?.name === cell.wsName) {
        const addr = String(tl?.lastIpcObject?.address || "");
        if (addr && HyprlandService.urgentAddresses && HyprlandService.urgentAddresses[addr])
          return true;
      }
    }
    return false;
  }

  readonly property bool isScreenshareActive: {
    if (!HyprlandService.screenshareActive || cell.isPrivate)
      return false;
    return previewArea.windowGeometry.length > 0;
  }

  readonly property var appIcons: {
    const icons = [];
    const seen = {};
    const windows = previewArea.windowGeometry || [];
    for (let i = 0; i < windows.length; i++) {
      const cls = String(windows[i].appId || windows[i].title || "").trim();
      if (cls && !seen[cls]) {
        seen[cls] = true;
        icons.push({
                     "class": cls,
                     "icon": ThemeIcons.iconForAppId(cls, "application-x-executable")
                   });
        if (icons.length >= 4)
          break;
      }
    }
    return icons;
  }

  function closeAllWindows() {
    const windows = previewArea.windowGeometry || [];
    for (let i = 0; i < windows.length; i++) {
      cell.overview?.closeWindow(windows[i].tl, windows[i].addr);
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusCard
    color: cell.active ? Qt.alpha(Color.mPrimary, 0.18) : (cell.isDropTarget ? Qt.alpha(Color.mSecondary, 0.28) : Color.mSurfaceContainer)
    border.width: cell.active || cell.isDropTarget || cell.isUrgent ? Style.borderM : Style.borderS
    border.color: cell.isUrgent ? Color.mError : (cell.active ? Color.mPrimary : (cell.isDropTarget ? Color.mSecondary : Qt.alpha(Color.mOutline, 0.72)))

    Behavior on color {
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }
    Behavior on border.color {
      NColorAnimation {
        motionType: NColorAnimation.Standard
      }
    }
    NStateLayer {
      anchors.fill: parent
      hovered: cellMouseArea.containsMouse
      pressed: cellMouseArea.pressed
      selected: cell.active
      dragged: cell.isDropTarget
      stateColor: Color.mPrimary
      radius: Style.radiusCard
    }

    MouseArea {
      id: cellMouseArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onPressed: {
        longPressTimer.triggered = false;
        longPressTimer.restart();
      }
      onReleased: {
        longPressTimer.stop();
        if (!longPressTimer.triggered)
          cell.overview?.switchWorkspace(cell.wsId, cell.wsName);
      }
      onCanceled: longPressTimer.stop()

      Timer {
        id: longPressTimer
        interval: 500
        property bool triggered: false
        onTriggered: {
          triggered = true;
          cellContextMenu.openAtItem(cell, cellMouseArea.mouseX, cellMouseArea.mouseY);
        }
      }
    }

    Item {
      id: previewArea
      anchors.fill: parent
      anchors.margins: Style.spaceS
      anchors.topMargin: Style.spaceXL + Style.spaceXS
      clip: true

      readonly property var windowGeometry: {
        const toplevels = Hyprland.toplevels.values || [];
        const windows = [];
        let minX = 99999;
        let minY = 99999;
        let maxX = -99999;
        let maxY = -99999;

        for (let index = 0; index < toplevels.length; index++) {
          const toplevel = toplevels[index];
          const ipc = toplevel?.lastIpcObject;
          const wsMatch = cell.isSpecial ? (toplevel?.workspace?.name === cell.wsName) : (toplevel?.workspace?.id === cell.wsId);
          if (!wsMatch)
            continue;
          if (!ipc?.at || !ipc?.size || ipc.mapped === false)
            continue;
          const x = ipc.at[0];
          const y = ipc.at[1];
          const width = ipc.size[0];
          const height = ipc.size[1];
          const appId = String(ipc.class || ipc.initialClass || ipc.appId || "").trim();
          windows.push({
                         "addr": ipc.address,
                         "tl": toplevel,
                         "x": x,
                         "y": y,
                         "width": width,
                         "height": height,
                         "title": ipc.title || appId || "",
                         "appId": appId,
                         "workspaceId": cell.wsId,
                         "workspaceName": cell.wsName,
                         "grouped": Array.isArray(ipc.grouped) && ipc.grouped.length > 0
                       });
          minX = Math.min(minX, x);
          minY = Math.min(minY, y);
          maxX = Math.max(maxX, x + width);
          maxY = Math.max(maxY, y + height);
        }

        if (!windows.length)
          return [];
        const contentWidth = Math.max(1, maxX - minX);
        const contentHeight = Math.max(1, maxY - minY);
        const aspect = Math.max(0.01, previewArea.height / previewArea.width);
        const scale = Math.min(1 / contentWidth, aspect / contentHeight);
        const offsetX = (1 - contentWidth * scale) / 2;
        const offsetY = (aspect - contentHeight * scale) / (2 * aspect);

        return windows.map(window => ({
                                        "addr": window.addr,
                                        "tl": window.tl,
                                        "title": window.title,
                                        "appId": window.appId,
                                        "workspaceId": window.workspaceId,
                                        "workspaceName": window.workspaceName,
                                        "grouped": window.grouped,
                                        "fx": offsetX + (window.x - minX) * scale,
                                        "fy": offsetY + (window.y - minY) * scale / aspect,
                                        "fw": window.width * scale,
                                        "fh": window.height * scale / aspect
                                      }));
      }

      Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Style.spaceS
        spacing: Style.spaceXXS
        visible: cell.isPrivate || previewArea.windowGeometry.length === 0

        NIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          icon: cell.isPrivate ? "shield-lock" : "apps"
          pointSize: Style.fontSizeHeadlineSmall
          color: cell.isPrivate ? Color.mPrimary : Color.mOnSurfaceVariant
        }
        NText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: cell.isPrivate ? qsTr("Private workspace") : qsTr("Empty workspace")
          pointSize: Style.fontSizeBodyMedium
          color: Color.mOnSurfaceVariant
        }
        NText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: cell.borderOnlyPrivacy ? qsTr("Border-only privacy active") : qsTr("Previews are hidden while privacy is enabled")
          pointSize: Style.fontSizeLabelSmall
          color: Color.mOnSurfaceVariant
          visible: cell.isPrivate
        }
      }

      Repeater {
        model: (cell.isPrivate || !cell.inViewport) ? [] : previewArea.windowGeometry
        delegate: WorkspaceWindowPreview {
          required property var modelData
          windowData: modelData
          overview: cell.overview
          livePreviews: cell.livePreviews
          active: cell.inViewport
          x: modelData.fx * parent.width
          y: modelData.fy * parent.height
          width: Math.max(32 * Style.uiScaleRatio, modelData.fw * parent.width)
          height: Math.max(24 * Style.uiScaleRatio, modelData.fh * parent.height)
        }
      }
    }

    RowLayout {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.spaceS
      spacing: Style.spaceXS
      z: 5

      Rectangle {
        width: workspaceLabel.implicitWidth + 2 * Style.spaceS
        height: workspaceLabel.implicitHeight + Style.spaceXS
        radius: Style.radiusCapsule
        color: cell.active ? Color.mPrimary : Qt.alpha(Color.mSurface, 0.9)

        NText {
          id: workspaceLabel
          anchors.centerIn: parent
          text: cell.isSpecial ? cell.wsName.replace("special:", "") : cell.wsName
          pointSize: Style.fontSizeTitleSmall
          font.weight: Style.fontWeightBold
          color: cell.active ? Color.mOnPrimary : Color.mOnSurface
        }
      }

      Row {
        spacing: 3
        Layout.alignment: Qt.AlignVCenter
        visible: cell.appIcons.length > 0 && !cell.isPrivate

        Repeater {
          model: cell.appIcons
          delegate: Image {
            width: 16 * Style.uiScaleRatio
            height: 16 * Style.uiScaleRatio
            source: modelData.icon.startsWith("file://") || modelData.icon.startsWith("/") ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : modelData.icon) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true

            NIcon {
              anchors.centerIn: parent
              visible: !parent.source || parent.status !== Image.Ready
              icon: "apps"
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }
        }

        NText {
          anchors.verticalCenter: parent.verticalCenter
          text: `(${previewArea.windowGeometry.length})`
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Rectangle {
        visible: cell.isUrgent
        width: urgentText.implicitWidth + Style.spaceS
        height: 20 * Style.uiScaleRatio
        radius: Style.radiusCapsule
        color: Color.mError

        NText {
          id: urgentText
          anchors.centerIn: parent
          text: "🔔 Urgent"
          pointSize: Style.fontSizeLabelSmall
          color: Color.mOnError
          font.weight: Style.fontWeightBold
        }
      }

      Rectangle {
        visible: cell.isScreenshareActive
        width: shareText.implicitWidth + Style.spaceS
        height: 20 * Style.uiScaleRatio
        radius: Style.radiusCapsule
        color: Qt.alpha(Color.mError, 0.85)

        NText {
          id: shareText
          anchors.centerIn: parent
          text: "🔴 Sharing"
          pointSize: Style.fontSizeLabelSmall
          color: Color.mOnError
        }
      }

      Rectangle {
        width: layoutText.implicitWidth + Style.spaceS
        height: 20 * Style.uiScaleRatio
        radius: Style.radiusCapsule
        color: Qt.alpha(Color.mSurfaceContainerHigh, 0.9)
        border.width: 1
        border.color: Qt.alpha(Color.mOutline, 0.5)

        NText {
          id: layoutText
          anchors.centerIn: parent
          text: cell.layoutName
          pointSize: Style.fontSizeLabelSmall
          color: Color.mOnSurface
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (CompositorService.backend?.cycleWorkspaceLayout)
              CompositorService.backend.cycleWorkspaceLayout(cell.wsName || cell.wsId);
          }
        }
      }

      NIconButton {
        icon: cell.isPrivate ? "shield-lock" : "shield"
        baseSize: Style.baseWidgetSize * 0.72
        colorBg: cell.isPrivate ? Qt.alpha(Color.mPrimary, 0.2) : Qt.alpha(Color.mSurface, 0.86)
        colorFg: cell.isPrivate ? Color.mPrimary : Color.mOnSurfaceVariant
        tooltipText: cell.isPrivate ? qsTr("Disable workspace privacy") : qsTr("Make workspace private")
        onClicked: cell.overview?.toggleWorkspacePrivacy(cell.wsId, cell.wsName, !cell.isPrivate)
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.radiusCard
      color: Qt.alpha(Color.mSurfaceContainerHighest, 0.92)
      border.width: Style.borderM
      border.color: cell.isPrivate ? Color.mError : Color.mPrimary
      visible: cell.isDropTarget
      z: 10

      Column {
        anchors.centerIn: parent
        spacing: Style.spaceXS

        NIcon {
          anchors.horizontalCenter: parent.horizontalCenter
          icon: cell.isPrivate ? "shield-alert" : "arrow-down-to-arc"
          pointSize: Style.fontSizeTitleLarge
          color: cell.isPrivate ? Color.mError : Color.mPrimary
        }
        NText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("Move to workspace %1").arg(cell.isSpecial ? cell.wsName : cell.wsId)
          pointSize: Style.fontSizeTitleSmall
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
        NText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: qsTr("Destination is private — window preview will be hidden")
          pointSize: Style.fontSizeLabelSmall
          color: Color.mError
          visible: cell.isPrivate
        }
      }
    }

    DropArea {
      id: dropArea
      anchors.fill: parent
      onDropped: {
        if (cell.overview?.dragAddr)
          cell.overview.moveWindowToWs(cell.overview.dragAddr, cell.wsId, cell.wsName);
      }
    }

    NContextMenu {
      id: cellContextMenu
      parent: Overlay.overlay
      model: [
        {
          "label": cell.isPrivate ? qsTr("Disable privacy") : qsTr("Make private"),
          "action": "privacy",
          "icon": cell.isPrivate ? "shield-off" : "shield-lock"
        },
        {
          "label": qsTr("Cycle layout"),
          "action": "layout",
          "icon": "layout"
        },
        {
          "label": qsTr("Move earlier"),
          "action": "order_up",
          "icon": "arrow-left"
        },
        {
          "label": qsTr("Move later"),
          "action": "order_down",
          "icon": "arrow-right"
        },
        {
          "label": qsTr("Close all windows"),
          "action": "close_all",
          "icon": "trash"
        }
      ]
      onTriggered: action => {
                     if (action === "privacy") {
                       cell.overview?.toggleWorkspacePrivacy(cell.wsId, cell.wsName, !cell.isPrivate);
                     } else if (action === "layout") {
                       if (CompositorService.backend?.cycleWorkspaceLayout)
                       CompositorService.backend.cycleWorkspaceLayout(cell.wsName || cell.wsId);
                     } else if (action === "order_up") {
                       cell.overview?.moveWorkspaceOrder(cell.wsId, -1);
                     } else if (action === "order_down") {
                       cell.overview?.moveWorkspaceOrder(cell.wsId, 1);
                     } else if (action === "close_all") {
                       cell.closeAllWindows();
                     }
                   }
    }
  }
}
