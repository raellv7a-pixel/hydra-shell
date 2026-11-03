import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property var launcher
  property var folder: launcher.activeFolder
  property real connectorX: width / 2
  readonly property var subfolders: folder?.children || []
  readonly property var entries: subfolders.concat(folder?.entries || [])
  readonly property int columns: Math.max(1, Math.min(3, Math.floor((width - launcher.metrics.padding * 2) / (240 * Style.uiScaleRatio))))
  readonly property real rowHeight: launcher.metrics.folderAppHeight + launcher.metrics.gapS
  implicitHeight: launcher.metrics.padding * 2 + Math.max(launcher.metrics.pillHeight, 48 * Style.uiScaleRatio) + launcher.metrics.gapL + (launcher.appPanelOpen ? 340 * Style.uiScaleRatio : Math.max(1, Math.ceil(entries.length / columns)) * rowHeight)
  Accessible.role: Accessible.Pane
  Accessible.name: folder?.name || ""
  OpacityAnimator {
    target: root
    from: 0
    to: 1
    duration: Style.animationFast
    easing.type: Easing.OutCubic
    running: root.visible && Style.animationFast > 0
  }

  // A short tonal neck joins the selected card to its in-flow collection.
  Rectangle {
    width: Style.margin2XL
    height: root.launcher.metrics.gapL + Style.radiusS
    radius: Style.radiusXS
    x: Math.max(Style.radiusL, Math.min(root.width - Style.radiusL - width, root.connectorX - width / 2))
    y: -root.launcher.metrics.gapL
    color: HydraColor.mSecondaryContainer
    Accessible.ignored: true
  }
  NBox {
    anchors.fill: parent
    forceOpaque: true
    color: HydraColor.mSecondaryContainer
    radius: Style.radiusL
    border.width: 0
  }

  function focusFirst() {
    if (apps.count) {
      apps.currentIndex = 0;
      apps.positionViewAtBeginning();
      Qt.callLater(() => { if (apps.currentItem) apps.currentItem.forceActiveFocus(); });
    } else closeButton.forceActiveFocus();
  }
  function navigate(index, event) {
    if (launcher.appPanelOpen && launcher.handleAppPanelKeyPress(event)) return;
    let next = index;
    if (event.key === Qt.Key_Left) next--;
    else if (event.key === Qt.Key_Right) next++;
    else if (event.key === Qt.Key_Up) {
      if (index < columns && launcher.folderAnchor) {
        launcher.folderAnchor.forceActiveFocus();
        event.accepted = true;
        return;
      }
      next -= columns;
    } else if (event.key === Qt.Key_Down) next += columns;
    else { launcher.handleHomeItemKey(event, apps.currentItem); return; }
    apps.currentIndex = Math.max(0, Math.min(apps.count - 1, next));
    apps.positionViewAtIndex(apps.currentIndex, GridView.Contain);
    Qt.callLater(() => { if (apps.currentItem) apps.currentItem.forceActiveFocus(); });
    event.accepted = true;
  }
  function scrollContent(view, event) {
    if (!view.interactive) return false;
    const delta = event.pixelDelta.y || event.angleDelta.y / 120 * rowHeight;
    const next = Math.max(view.originY, Math.min(view.originY + Math.max(0, view.contentHeight - view.height), view.contentY - delta));
    if (Math.abs(next - view.contentY) < 0.5) return false;
    view.contentY = next;
    return true;
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.launcher.metrics.padding
    spacing: root.launcher.metrics.gapL
    RowLayout {
      Layout.fillWidth: true
      spacing: root.launcher.metrics.gapM
      NIconButton {
        visible: root.launcher.activeSubfolderId !== ""
        icon: "arrow-left"
        tooltipText: I18n.tr("launcher-home.back")
        onClicked: root.launcher.backToParentFolder()
        Keys.onPressed: event => root.launcher.handleHomeItemKey(event, root)
      }
      Loader {
        Layout.preferredWidth: Math.round(48 * Style.uiScaleRatio)
        Layout.preferredHeight: Layout.preferredWidth
        sourceComponent: root.folder?.mode === "pinned" ? pinnedIcon : folderIcon
        Component { id: pinnedIcon; NColorIcon { icon: "pin" } }
        Component { id: folderIcon; LauncherFolderIcon { folder: root.folder || { mode: "manual", icon: "folder" } } }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS
        NText { Layout.fillWidth: true; text: root.folder?.name || ""; color: HydraColor.mOnSecondaryContainer; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightBold; elide: Text.ElideRight }
        NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.app-count", { count: root.folder?.entries.length || 0 }); pointSize: Style.fontSizeS; color: HydraColor.mOnSecondaryContainer; elide: Text.ElideRight }
      }
      LauncherHomeButton {
        launcher: root.launcher
        visible: root.width >= 600 * Style.uiScaleRatio && (root.folder?.entries.length || 0) > 0
        text: I18n.tr("launcher-home.open-all")
        implicitHeight: root.launcher.metrics.pillHeight
        surface: HydraColor.mSurfaceContainerHighest
        onClicked: {
          const entries = root.folder.entries.slice();
          for (const entry of entries) root.launcher.activateEntry(entry);
        }
      }
      NIconButton {
        visible: root.folder?.mode === "manual" && !root.launcher.activeSubfolderId
        icon: "folder-plus"
        tooltipText: I18n.tr("launcher-home.new-subfolder")
        onClicked: root.launcher.editFolder(null, "", root.launcher.activeFolderId)
        Keys.onPressed: event => root.launcher.handleHomeItemKey(event, root)
      }
      NIconButton {
        visible: root.folder?.mode === "manual"
        icon: "edit"
        tooltipText: I18n.tr("launcher-home.edit-folder")
        onClicked: root.launcher.editFolder(root.folder)
        Keys.onPressed: event => root.launcher.handleHomeItemKey(event, root)
      }
      NIconButton {
        id: closeButton
        icon: "x"
        tooltipText: I18n.tr("common.close")
        onClicked: root.launcher.closeExpandedFolder()
        Keys.onPressed: event => root.launcher.handleHomeItemKey(event, root)
      }
    }
    GridView {
      id: apps
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: !root.launcher.appPanelOpen && count > 0
      cellWidth: width / root.columns
      cellHeight: root.rowHeight
      model: root.entries
      boundsBehavior: Flickable.StopAtBounds
      interactive: !Settings.data.appLauncher.ignoreMouseInput && contentHeight > height
      keyNavigationEnabled: false
      clip: true
      delegate: LauncherHomeButton {
        id: appButton
        required property var modelData
        required property int index
        readonly property bool isFolder: index < root.subfolders.length
        readonly property var badgeState: !isFolder && modelData.provider?.packageStateForItem ? modelData.provider.packageStateForItem(modelData) : ({})
        launcher: root.launcher
        width: apps.cellWidth - root.launcher.metrics.gapS
        height: apps.cellHeight - root.launcher.metrics.gapS
        padding: root.launcher.metrics.padding
        cornerRadius: Style.radiusM
        surface: HydraColor.mSurfaceContainerHighest
        pressFeedback: true
        text: modelData.name
        onClicked: isFolder ? launcher.openSubfolder(modelData.id) : launcher.activateEntry(modelData)
        onContextRequested: isFolder ? launcher.editFolder(modelData) : launcher.showHomeAppActions(modelData)
        Keys.onPressed: event => root.navigate(index, event)
        onActiveFocusChanged: if (activeFocus) apps.positionViewAtIndex(index, GridView.Contain)
        contentItem: RowLayout {
          spacing: root.launcher.metrics.gapM
          Item {
            Layout.preferredWidth: Math.round(48 * Style.uiScaleRatio)
            Layout.preferredHeight: Layout.preferredWidth
            LauncherAppIcon { anchors.fill: parent; visible: !appButton.isFolder; appIcon: appButton.modelData.icon || "" }
            Loader { anchors.fill: parent; active: appButton.isFolder; sourceComponent: LauncherFolderIcon { folder: appButton.modelData } }
            NIcon { anchors.right: parent.right; anchors.bottom: parent.bottom; visible: !!appButton.badgeState.badgeIcon; icon: appButton.badgeState.badgeIcon || ""; pointSize: Style.fontSizeS; color: HydraColor.mPrimary }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText { Layout.fillWidth: true; text: appButton.text; pointSize: Style.fontSizeL; font.weight: Style.fontWeightSemiBold; elide: Text.ElideRight }
            NText { Layout.fillWidth: true; text: appButton.isFolder ? I18n.tr("launcher-home.app-count", {count: appButton.modelData.entries.length}) : appButton.modelData.description || ""; pointSize: Style.fontSizeS; color: HydraColor.mOnSurfaceVariant; elide: Text.ElideRight }
          }
        }
      }
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: false
        onWheel: event => { blocking = root.scrollContent(apps, event); event.accepted = blocking; }
      }
    }
    NText { visible: !root.entries.length && !root.launcher.appPanelOpen; Layout.fillWidth: true; text: I18n.tr("launcher-home.empty-folder"); color: HydraColor.mOnSecondaryContainer; wrapMode: Text.Wrap }
    Flickable {
      id: actionsScroll
      visible: root.launcher.appPanelOpen
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: width
      contentHeight: actions.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      interactive: !Settings.data.appLauncher.ignoreMouseInput && contentHeight > height
      clip: true
      LauncherAppActionsPanel {
        id: actions
        width: parent.width
        launcher: root.launcher
        item: root.launcher.appPanelItem
        actions: root.launcher.appPanelActions
        propertiesApp: root.launcher.propertiesApp
        showingProperties: root.launcher.appPanelShowingProperties
        activeActionIndex: root.launcher.appPanelActionIndex
        confirmIndex: root.launcher.appPanelConfirmIndex
        connectedToEntry: false
        open: root.launcher.appPanelOpen
      }
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: false
        onWheel: event => { blocking = root.scrollContent(actionsScroll, event); event.accepted = blocking; }
      }
    }
  }
}
