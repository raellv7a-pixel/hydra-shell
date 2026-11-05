import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

LauncherHomeButton {
  id: root
  required property var folder
  required property var homeView
  required property int folderIndex
  readonly property bool selected: launcher.folderExpanded && launcher.activeFolderId === folder.id
  surface: selected ? HydraColor.mSecondaryContainer : HydraColor.mSurfaceContainerHigh
  foreground: selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurface
  pressFeedback: true
  raisedSurface: true
  Accessible.selected: selected
  onSelectedChanged: if (selected) launcher.folderAnchor = root
  Component.onCompleted: if (selected) launcher.folderAnchor = root
  text: folder.name
  Accessible.description: I18n.tr("launcher-home.app-count", { count: folder.entries.length })
  padding: launcher.metrics.padding
  topPadding: padding
  bottomPadding: padding
  implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
  onClicked: selected ? launcher.closeExpandedFolder() : launcher.openFolder(folder.id, root)
  onContextRequested: if (folder.mode === "manual") launcher.editFolder(folder)
  Keys.onPressed: event => {
    if (!homeView.navigateFolder(folderIndex, event))
      launcher.handleHomeItemKey(event, root);
  }
  Rectangle {
    anchors.fill: parent
    radius: root.cornerRadius
    visible: root.selected
    color: "transparent"
    border.width: root.selected ? Style.borderM : 0
    border.color: HydraColor.mPrimary
  }
  contentItem: ColumnLayout {
    spacing: root.launcher.metrics.folderGap
    RowLayout {
      Layout.fillWidth: true
      Layout.minimumHeight: Math.round(40 * Style.uiScaleRatio)
      spacing: root.launcher.metrics.gapS
      LauncherFolderIcon { folder: root.folder; Layout.preferredWidth: implicitWidth; Layout.preferredHeight: implicitHeight }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        NText { Layout.fillWidth: true; text: root.folder.name; color: root.foreground; font.weight: Style.fontWeightSemiBold; pointSize: Style.fontSizeL; elide: Text.ElideRight }
        NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.app-count", { count: root.folder.entries.length }); pointSize: Style.fontSizeS; color: root.selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurfaceVariant }
      }
      NIcon { icon: root.selected ? "chevron-down" : "chevron-right"; color: root.selected ? HydraColor.mPrimary : HydraColor.mOnSurfaceVariant; pointSize: Style.fontSizeS }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: root.launcher.metrics.gapS
      Repeater {
        model: root.folder.entries.slice(0, 4)
        LauncherAppIcon {
          required property var modelData
          Layout.preferredWidth: root.launcher.metrics.folderPreviewSize
          Layout.preferredHeight: Layout.preferredWidth
          appIcon: modelData.icon
          Accessible.ignored: true
        }
      }
      Item { Layout.fillWidth: true }
    }
  }
}
