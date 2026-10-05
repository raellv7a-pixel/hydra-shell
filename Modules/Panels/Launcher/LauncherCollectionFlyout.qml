import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property var launcher
  readonly property var folder: launcher.activeFolder
  readonly property var subfolders: folder?.children || []
  readonly property var entries: subfolders.concat(folder?.entries || [])
  implicitHeight: {
    const header = Math.max(launcher.metrics.pillHeight, Settings.data.appLauncher.folderIconSize * Style.uiScaleRatio);
    const columns = Math.max(1, Math.floor((width - launcher.metrics.padding * 2) / launcher.metrics.gridCell));
    const rows = Math.max(1, Math.ceil(entries.length / columns));
    const content = launcher.appPanelOpen ? 360 * Style.uiScaleRatio : rows * launcher.metrics.folderAppHeight;
    return launcher.metrics.padding * 2 + header + launcher.metrics.gapS + content;
  }
  NDropShadow {
    anchors.fill: surface
    source: surface
    autoPaddingEnabled: true
    shadowColor: Color.mShadow
    shadowOpacity: Style.shadowOpacity * Style.opacityLight
    shadowHorizontalOffset: 0
    shadowVerticalOffset: Style.marginXXS
  }
  NBox {
    id: surface
    anchors.fill: parent
    forceOpaque: true
    color: Color.mSurfaceContainerHighest
    radius: Style.radiusL
    border.width: 0
  }
  Accessible.role: Accessible.Pane
  Accessible.name: folder?.name || ""
  MouseArea { anchors.fill: parent; onWheel: event => event.accepted = false }

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
    else if (event.key === Qt.Key_Up) next -= apps.columns;
    else if (event.key === Qt.Key_Down) next += apps.columns;
    else { launcher.handleHomeItemKey(event, apps.currentItem); return; }
    apps.currentIndex = Math.max(0, Math.min(apps.count - 1, next));
    apps.positionViewAtIndex(apps.currentIndex, GridView.Contain);
    Qt.callLater(() => { if (apps.currentItem) apps.currentItem.forceActiveFocus(); });
    event.accepted = true;
  }
  function scrollContent(view, event) {
    if (!view.interactive) return false;
    const delta = event.pixelDelta.y || event.angleDelta.y / 120 * launcher.metrics.folderAppHeight;
    const next = Math.max(view.originY, Math.min(view.originY + Math.max(0, view.contentHeight - view.height), view.contentY - delta));
    if (Math.abs(next - view.contentY) < 0.5) return false;
    view.contentY = next;
    return true;
  }
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.launcher.metrics.padding
    spacing: root.launcher.metrics.gapS
    RowLayout {
      Layout.fillWidth: true
      spacing: root.launcher.metrics.gapS
      LauncherHomeButton {
        visible: root.launcher.activeSubfolderId !== ""
        launcher: root.launcher
        text: I18n.tr("launcher-home.back")
        implicitHeight: root.launcher.metrics.pillHeight
        onClicked: root.launcher.backToParentFolder()
      }
      Loader {
        Layout.preferredWidth: root.folder?.mode === "pinned" ? root.launcher.metrics.pillHeight : Settings.data.appLauncher.folderIconSize * Style.uiScaleRatio
        Layout.preferredHeight: Layout.preferredWidth
        sourceComponent: root.folder?.mode === "pinned" ? pinnedIcon : folderIcon
        Component { id: pinnedIcon; NIcon { icon: "pin"; color: Color.mPrimary } }
        Component { id: folderIcon; LauncherFolderIcon { folder: root.folder || { mode: "manual", icon: "folder" } } }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        NText { Layout.fillWidth: true; text: root.folder?.name || ""; pointSize: Style.fontSizeM; font.weight: Style.fontWeightSemiBold; elide: Text.ElideRight }
        NText { text: I18n.tr("launcher-home.app-count", { count: root.folder?.entries.length || 0 }); pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
      }
      LauncherHomeButton {
        visible: root.folder?.mode === "manual" && !root.launcher.activeSubfolderId
        launcher: root.launcher
        text: I18n.tr("launcher-home.new-subfolder")
        implicitHeight: root.launcher.metrics.pillHeight
        onClicked: root.launcher.editFolder(null, "", root.launcher.activeFolderId)
      }
      LauncherHomeButton {
        visible: root.folder?.mode === "manual"
        launcher: root.launcher
        text: I18n.tr("launcher-home.edit-folder")
        implicitWidth: root.launcher.metrics.pillHeight
        implicitHeight: implicitWidth
        contentItem: NIcon { icon: "edit" }
        onClicked: root.launcher.editFolder(root.folder)
      }
      LauncherHomeButton {
        id: closeButton
        launcher: root.launcher
        text: I18n.tr("common.close")
        implicitWidth: root.launcher.metrics.pillHeight
        implicitHeight: implicitWidth
        contentItem: NIcon { icon: "x" }
        onClicked: root.launcher.closeExpandedFolder()
      }
    }
    GridView {
      id: apps
      readonly property int columns: Math.max(1, Math.floor(width / root.launcher.metrics.gridCell))
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: !root.launcher.appPanelOpen
      cellWidth: width / columns
      cellHeight: root.launcher.metrics.folderAppHeight
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
        width: apps.cellWidth
        height: apps.cellHeight
        padding: root.launcher.metrics.gapXS
        cornerRadius: Style.radiusM
        surface: "transparent"
        text: modelData.name
        onClicked: isFolder ? launcher.openSubfolder(modelData.id) : launcher.activateEntry(modelData)
        onContextRequested: isFolder ? launcher.editFolder(modelData) : launcher.showHomeAppActions(modelData)
        Keys.onPressed: event => root.navigate(index, event)
        onActiveFocusChanged: if (activeFocus) apps.positionViewAtIndex(index, GridView.Contain)
        contentItem: ColumnLayout {
          spacing: root.launcher.metrics.gapXS
          Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(40 * Style.uiScaleRatio)
            Layout.preferredHeight: Layout.preferredWidth
            LauncherAppIcon { anchors.fill: parent; visible: !appButton.isFolder; appIcon: appButton.modelData.icon || "" }
            Loader { anchors.centerIn: parent; active: appButton.isFolder; sourceComponent: LauncherFolderIcon { folder: appButton.modelData } }
            NIcon { anchors.right: parent.right; anchors.bottom: parent.bottom; visible: !!appButton.badgeState.badgeIcon; icon: appButton.badgeState.badgeIcon || ""; pointSize: Style.fontSizeS; color: Color.mPrimary }
          }
          NText { Layout.fillWidth: true; text: appButton.text; pointSize: Style.fontSizeXS; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        }
      }
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: false
        onWheel: event => {
          blocking = root.scrollContent(apps, event);
          event.accepted = blocking;
        }
      }
    }
    NText { visible: !root.entries.length && !root.launcher.appPanelOpen; Layout.fillWidth: true; text: I18n.tr("launcher-home.empty-folder"); color: Color.mOnSurfaceVariant; wrapMode: Text.Wrap }
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
        onWheel: event => {
          blocking = root.scrollContent(actionsScroll, event);
          event.accepted = blocking;
        }
      }
    }
  }
}
