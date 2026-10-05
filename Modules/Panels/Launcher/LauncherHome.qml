import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Flickable {
  id: root
  required property var launcher
  readonly property var browse: launcher.browseModel
  readonly property bool wide: width >= 560 * Style.uiScaleRatio
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
    else if (event.key === Qt.Key_Down) allApps.forceActiveFocus();
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
      NIcon { icon: "folder"; pointSize: Style.fontSizeL; color: Color.mOnSurface }
      NText { text: I18n.tr("launcher-home.folders-title"); font.weight: Style.fontWeightSemiBold; pointSize: Style.fontSizeL }
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
    LauncherHomeButton {
      id: allApps
      launcher: root.launcher
      text: I18n.tr("launcher-home.all-apps")
      Accessible.description: I18n.tr("launcher-home.all-apps-description")
      Layout.fillWidth: true
      Layout.preferredHeight: root.launcher.metrics.allAppsHeight
      surface: Color.mPrimaryContainer
      onClicked: launcher.openAllApps("all")
      contentItem: RowLayout {
        spacing: root.launcher.metrics.gapL
        NIcon { icon: "apps"; pointSize: Style.fontSizeXXL; color: Color.mOnPrimaryContainer }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS
          NText { text: allApps.text; pointSize: Style.fontSizeL; font.weight: Style.fontWeightSemiBold; color: Color.mOnPrimaryContainer }
          NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.all-apps-description"); pointSize: Style.fontSizeS; color: Color.mOnPrimaryContainer; elide: Text.ElideRight }
        }
        NIcon { icon: "chevron-right"; color: Color.mOnPrimaryContainer }
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
        readonly property real padding: root.browse.pinned.length ? root.launcher.metrics.padding : root.launcher.metrics.gapS
        Layout.preferredHeight: pinnedBody.implicitHeight + padding * 2
        Layout.alignment: Qt.AlignTop
        forceOpaque: true
        color: Color.mSurfaceContainerHigh
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
            NIcon { icon: "pin"; color: Color.mOnSurface }
            NText { text: I18n.tr("launcher-home.pinned"); pointSize: Style.fontSizeM; font.weight: Style.fontWeightSemiBold }
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
              contentItem: NIcon { icon: "chevron-right"; color: Color.mOnSurfaceVariant }
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
                onClicked: launcher.activateEntry(modelData)
                onContextRequested: {
                  launcher.openPinned(pinnedExpand);
                  launcher.showHomeAppActions(modelData);
                }
                contentItem: ColumnLayout {
                  spacing: root.launcher.metrics.gapS
                  LauncherAppIcon { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: Math.round(40 * Style.uiScaleRatio); Layout.preferredHeight: Layout.preferredWidth; appIcon: pinnedApp.modelData.icon }
                  NText { Layout.fillWidth: true; text: pinnedApp.text; pointSize: Style.fontSizeXS; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                }
              }
            }
          }
          NText { visible: root.browse.pinned.length === 0; Layout.fillWidth: true; text: I18n.tr("launcher-home.no-pinned"); color: Color.mOnSurfaceVariant; wrapMode: Text.Wrap; pointSize: Style.fontSizeS }
        }
      }
      NBox {
        Layout.fillWidth: true
        Layout.preferredWidth: root.width * 0.45
        readonly property real padding: root.browse.recentItems.length || root.browse.recentApps.length ? root.launcher.metrics.padding : root.launcher.metrics.gapS
        Layout.preferredHeight: recentBody.implicitHeight + padding * 2
        Layout.alignment: Qt.AlignTop
        forceOpaque: true
        color: Color.mSurfaceContainerHigh
        border.width: 0
        radius: Style.radiusL
        ColumnLayout {
          id: recentBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: parent.padding
          spacing: root.launcher.metrics.gapXS
          RowLayout {
            Layout.fillWidth: true
            NIcon { icon: "clock"; color: Color.mOnSurface }
            NText { text: I18n.tr("launcher-home.recent"); pointSize: Style.fontSizeM; font.weight: Style.fontWeightSemiBold }
            Item { Layout.fillWidth: true }
            LauncherHomeButton {
              launcher: root.launcher
              visible: root.browse.recentItems.length > 0 || root.browse.recentApps.length > 0
              text: I18n.tr("launcher-home.clear")
              surface: "transparent"
              implicitHeight: Math.round(30 * Style.uiScaleRatio)
              padding: Style.marginXS
              onClicked: root.browse.clearRecents()
            }
          }
          Repeater {
            model: (root.browse.recentItems.length ? root.browse.recentItems : root.browse.recentApps).slice(0, 4)
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
                NIcon { visible: !!recentItem.modelData.uri; Layout.preferredWidth: Math.round(24 * Style.uiScaleRatio); Layout.preferredHeight: Layout.preferredWidth; icon: recentItem.modelData.icon; color: Color.mPrimary }
                LauncherAppIcon { visible: !recentItem.modelData.uri; Layout.preferredWidth: Math.round(24 * Style.uiScaleRatio); Layout.preferredHeight: Layout.preferredWidth; appIcon: recentItem.modelData.icon }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  NText { Layout.fillWidth: true; text: recentItem.text; pointSize: Style.fontSizeS; elide: Text.ElideMiddle }
                  NText { Layout.fillWidth: true; text: recentItem.modelData.uri ? I18n.tr("launcher-home.document-types." + recentItem.documentGroup) : I18n.tr("launcher-home.app"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXXS; elide: Text.ElideRight }
                }
                NText { text: Time.formatRelativeTime(new Date(recentItem.modelData.modifiedAt || recentItem.modelData.lastOpenedAt)); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXXS }
              }
            }
          }
          NText { visible: !root.browse.recentItems.length && !root.browse.recentApps.length; text: I18n.tr("launcher-home.no-recent"); Layout.fillWidth: true; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS; wrapMode: Text.Wrap }
        }
      }
    }
  }
}
