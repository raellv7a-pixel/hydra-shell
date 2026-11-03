import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Flickable {
  id: root
  required property var launcher
  readonly property var browse: launcher.browseModel
  readonly property bool wide: width >= 560 * Style.uiScaleRatio
  readonly property real sectionHeight: Math.max(launcher.metrics.pinnedHeight + Style.margin2L, pinnedBody.implicitHeight, recentBody.implicitHeight) + launcher.metrics.padding * 2
  property var displayedFolder: null
  readonly property var expandedView: expansion.status === Loader.Ready ? expansion.item : null
  function revealExpanded() {
    if (!expandedView) return;
    const panelBottom = expansion.y + expansion.height;
    const contextFits = panelBottom - folderCards.y <= height;
    const top = contextFits ? folderCards.y : expansion.y;
    const next = Math.max(0, Math.min(Math.max(0, contentHeight - height), Math.max(panelBottom - height, Math.min(contentY, top))));
    if (Math.abs(next - contentY) > 0.5) {
      revealScroll.from = contentY;
      revealScroll.to = next;
      revealScroll.restart();
    }
  }
  function focusExpanded() {
    revealExpanded();
    if (expandedView) expandedView.focusFirst();
  }
  Connections {
    target: root.launcher
    function onActiveFolderChanged() {
      if (root.launcher.activeFolder) root.displayedFolder = root.launcher.activeFolder;
    }
    function onFolderExpandedChanged() {
      if (root.launcher.folderExpanded) {
        closeDelay.stop();
        Qt.callLater(root.focusExpanded);
      } else if (expansion.active) {
        revealScroll.stop();
        closeDelay.restart();
      }
    }
  }
  Timer { id: closeDelay; interval: Style.animationFast }
  NumberAnimation { id: revealScroll; target: root; property: "contentY"; duration: Style.animationNormal; easing.type: Easing.OutCubic }
  onDraggingChanged: if (dragging) revealScroll.stop()
  onVisibleChanged: if (!visible) revealScroll.stop()
  onHeightChanged: if (launcher.folderExpanded) Qt.callLater(root.revealExpanded)
  contentWidth: width
  contentHeight: body.implicitHeight + launcher.metrics.gapM
  implicitHeight: contentHeight
  flickableDirection: Flickable.VerticalFlick
  boundsBehavior: Flickable.StopAtBounds
  interactive: !Settings.data.appLauncher.ignoreMouseInput && contentHeight > height
  clip: true
  function focusFirst() {
    if (folderCards.count) folderCards.focusIndex(0);
    else allApps.forceActiveFocus();
  }
  function navigateFolder(index, event) {
    if (event.key === Qt.Key_Up) launcher.focusHomeCategories();
    else if (event.key === Qt.Key_Down) {
      if (launcher.folderExpanded) focusExpanded();
      else allApps.forceActiveFocus();
    }
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      const target = index + (event.key === Qt.Key_Left ? -1 : 1);
      if (target < 0) launcher.focusHomeCategories();
      else if (target >= folderCards.count) allApps.forceActiveFocus();
      else folderCards.focusIndex(target);
    } else return false;
    event.accepted = true;
    return true;
  }
  function scrollVertically(event) {
    if (!interactive) return false;
    revealScroll.stop();
    const delta = event.pixelDelta.y || event.angleDelta.y / 120 * Style.baseWidgetSize;
    const next = Math.max(0, Math.min(contentHeight - height, contentY - delta));
    const consumed = Math.abs(next - contentY) > 0.5;
    contentY = next;
    return consumed;
  }
  function ensureVisible(item) {
    if (item.folderIndex !== undefined) folderCards.containIndex(item.folderIndex);
    const position = item.mapToItem(body, 0, 0);
    if (position.y < 0) return;
    if (position.y < contentY) contentY = position.y;
    else if (position.y + item.height > contentY + height) contentY = position.y + item.height - height;
  }
  ColumnLayout {
    id: body
    width: root.width
    spacing: root.launcher.metrics.gapL
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: root.launcher.metrics.gapS
      NIcon { icon: "folder"; pointSize: Style.fontSizeXL; color: HydraColor.mOnSurface }
      NText { text: I18n.tr("launcher-home.folders-title"); font.weight: Style.fontWeightBold; pointSize: Style.fontSizeXL }
      Item { Layout.fillWidth: true }
      LauncherHomeButton {
        launcher: root.launcher
        text: I18n.tr("launcher-home.new-folder")
        surface: "transparent"
        implicitHeight: Math.round(32 * Style.uiScaleRatio)
        onClicked: launcher.editFolder(null)
      }
    }
    LauncherFolderCarousel {
      id: folderCards
      launcher: root.launcher
      homeView: root
      visible: count > 0
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
    }
    Loader {
      id: expansion
      Layout.fillWidth: true
      Layout.preferredHeight: active ? Math.min(item?.implicitHeight || 0, Math.max(180 * Style.uiScaleRatio, root.height * 0.6)) : 0
      visible: active
      active: root.launcher.folderExpanded || closeDelay.running
      opacity: root.launcher.folderExpanded ? 1 : 0
      Behavior on opacity {
        enabled: Style.animationFast > 0
        OpacityAnimator { duration: Style.animationFast; easing.type: Easing.OutCubic }
      }
      sourceComponent: LauncherCollectionFlyout {
        launcher: root.launcher
        folder: root.displayedFolder
        connectorX: {
          const anchor = root.launcher.folderAnchor;
          if (!anchor) return width / 2;
          if (anchor.folderIndex !== undefined)
            return folderCards.x + anchor.x - folderCards.contentX + anchor.width / 2;
          return anchor.mapToItem(root, anchor.width / 2, 0).x;
        }
      }
    }
    LauncherHomeButton {
      id: allApps
      launcher: root.launcher
      text: I18n.tr("launcher-home.all-apps")
      Accessible.description: I18n.tr("launcher-home.all-apps-description")
      Layout.fillWidth: true
      Layout.preferredHeight: root.launcher.metrics.allAppsHeight
      surface: HydraColor.mPrimaryContainer
      foreground: HydraColor.mOnPrimaryContainer
      onClicked: launcher.openAllApps("all")
      contentItem: RowLayout {
        spacing: root.launcher.metrics.gapL
        NIcon { icon: "apps"; pointSize: Style.fontSizeXXL; color: HydraColor.mOnPrimaryContainer }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS
          NText { text: allApps.text; pointSize: Style.fontSizeL; font.weight: Style.fontWeightBold; color: HydraColor.mOnPrimaryContainer }
          NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.all-apps-description"); pointSize: Style.fontSizeS; color: HydraColor.mOnPrimaryContainer; elide: Text.ElideRight }
        }
        NIcon { icon: "chevron-right"; color: HydraColor.mOnPrimaryContainer }
      }
    }
    GridLayout {
      Layout.fillWidth: true
      columns: root.wide ? 2 : 1
      columnSpacing: root.launcher.metrics.gapL
      rowSpacing: root.launcher.metrics.gapL
      NBox {
        Layout.fillWidth: true
        Layout.preferredWidth: root.width * 0.55
        readonly property real padding: root.launcher.metrics.padding
        Layout.preferredHeight: root.wide ? root.sectionHeight : Math.max(root.launcher.metrics.pinnedHeight + Style.margin2L, pinnedBody.implicitHeight) + padding * 2
        Layout.alignment: Qt.AlignTop
        forceOpaque: true
        color: HydraColor.mSurfaceContainerHigh
        border.width: 0
        radius: Style.radiusL
        ColumnLayout {
          id: pinnedBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: parent.padding
          spacing: root.browse.pinned.length ? root.launcher.metrics.gapM : root.launcher.metrics.gapXS
          RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: Math.round(32 * Style.uiScaleRatio)
            NIcon { icon: "pin"; pointSize: Style.fontSizeL; color: HydraColor.mOnSurface }
            NText { text: I18n.tr("launcher-home.pinned"); pointSize: Style.fontSizeL; font.weight: Style.fontWeightSemiBold }
            Item { Layout.fillWidth: true }
            LauncherHomeButton {
              id: pinnedExpand
              launcher: root.launcher
              visible: root.browse.pinned.length > 0
              text: I18n.tr("launcher-home.view-pinned")
              surface: "transparent"
              implicitWidth: Math.round(32 * Style.uiScaleRatio)
              implicitHeight: implicitWidth
              padding: Style.marginXS
              contentItem: NIcon { icon: "chevron-right"; color: HydraColor.mOnSurfaceVariant }
              onClicked: launcher.openPinned(pinnedExpand)
            }
          }
          GridLayout {
            visible: root.browse.pinned.length > 0
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(6, Math.floor(width / root.launcher.metrics.gridCell)))
            rowSpacing: root.launcher.metrics.gapS
            columnSpacing: root.launcher.metrics.gapXS
            Repeater {
              model: root.browse.pinned.slice(0, 6)
              LauncherHomeButton {
                id: pinnedApp
                required property var modelData
                launcher: root.launcher
                text: modelData.name
                Layout.fillWidth: true
                Layout.preferredWidth: root.launcher.metrics.gridCell
                Layout.preferredHeight: root.launcher.metrics.pinnedHeight
                padding: root.launcher.metrics.gapXS
                surface: "transparent"
                pressFeedback: true
                onClicked: launcher.activateEntry(modelData)
                onContextRequested: {
                  launcher.openPinned(pinnedExpand);
                  launcher.showHomeAppActions(modelData);
                }
                contentItem: ColumnLayout {
                  spacing: root.launcher.metrics.gapS
                  LauncherAppIcon { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: root.launcher.metrics.pinnedIconSize; Layout.preferredHeight: Layout.preferredWidth; appIcon: pinnedApp.modelData.icon }
                  NText { Layout.fillWidth: true; text: pinnedApp.text; pointSize: Style.fontSizeS; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                }
              }
            }
          }
          NText { visible: root.browse.pinned.length === 0; Layout.fillWidth: true; text: I18n.tr("launcher-home.no-pinned"); color: HydraColor.mOnSurfaceVariant; wrapMode: Text.Wrap; pointSize: Style.fontSizeS }
        }
      }
      NBox {
        Layout.fillWidth: true
        Layout.preferredWidth: root.width * 0.45
        readonly property real padding: root.launcher.metrics.padding
        Layout.preferredHeight: root.wide ? root.sectionHeight : Math.max(root.launcher.metrics.pinnedHeight + Style.margin2L, recentBody.implicitHeight) + padding * 2
        Layout.alignment: Qt.AlignTop
        forceOpaque: true
        color: HydraColor.mSurfaceContainerHigh
        border.width: 0
        radius: Style.radiusL
        ColumnLayout {
          id: recentBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: parent.padding
          spacing: root.launcher.metrics.gapS
          RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: Math.round(32 * Style.uiScaleRatio)
            NIcon { icon: "clock"; pointSize: Style.fontSizeL; color: HydraColor.mOnSurface }
            NText { text: I18n.tr("launcher-home.recent"); pointSize: Style.fontSizeL; font.weight: Style.fontWeightSemiBold }
            Item { Layout.fillWidth: true }
            LauncherHomeButton {
              launcher: root.launcher
              visible: root.browse.recentItems.length > 0 || root.browse.recentApps.length > 0
              text: I18n.tr("launcher-home.clear")
              surface: "transparent"
              implicitHeight: Math.round(32 * Style.uiScaleRatio)
              padding: Style.marginXS
              onClicked: root.browse.clearRecents()
            }
          }
          Repeater {
            model: (root.browse.recentItems.length ? root.browse.recentItems : root.browse.recentApps).slice(0, 3)
            LauncherHomeButton {
              id: recentItem
              readonly property string documentGroup: ["image", "video", "audio"].includes((modelData.mime || "").split("/")[0]) ? modelData.mime.split("/")[0] : "documents"
              required property var modelData
              launcher: root.launcher
              text: modelData.name
              Accessible.description: modelData.mime || modelData.description || ""
              Layout.fillWidth: true
              Layout.preferredHeight: root.launcher.metrics.recentHeight
              surface: "transparent"
              padding: root.launcher.metrics.gapXS
              onClicked: {
                if (modelData.uri) {
                  if (Qt.openUrlExternally(modelData.uri)) launcher.close();
                } else launcher.activateEntry(modelData);
              }
              onContextRequested: if (modelData.appId) launcher.showHomeAppActions(modelData)
              contentItem: RowLayout {
                spacing: root.launcher.metrics.gapS
                NIcon { visible: !!recentItem.modelData.uri; Layout.preferredWidth: Math.round(24 * Style.uiScaleRatio); Layout.preferredHeight: Layout.preferredWidth; icon: recentItem.modelData.icon; color: HydraColor.mPrimary }
                LauncherAppIcon { visible: !recentItem.modelData.uri; Layout.preferredWidth: Math.round(24 * Style.uiScaleRatio); Layout.preferredHeight: Layout.preferredWidth; appIcon: recentItem.modelData.icon }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  NText { Layout.fillWidth: true; text: recentItem.text; pointSize: Style.fontSizeS; elide: Text.ElideMiddle }
                  NText { Layout.fillWidth: true; text: recentItem.modelData.uri ? I18n.tr("launcher-home.document-types." + recentItem.documentGroup) : I18n.tr("launcher-home.app"); color: HydraColor.mOnSurfaceVariant; pointSize: Style.fontSizeXS; elide: Text.ElideRight }
                }
                NText { text: Time.formatRelativeTime(new Date(recentItem.modelData.modifiedAt || recentItem.modelData.lastOpenedAt)); color: HydraColor.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
              }
            }
          }
          NText { visible: !root.browse.recentItems.length && !root.browse.recentApps.length; text: I18n.tr("launcher-home.no-recent"); Layout.fillWidth: true; color: HydraColor.mOnSurfaceVariant; pointSize: Style.fontSizeS; wrapMode: Text.Wrap }
        }
      }
    }
  }
}
