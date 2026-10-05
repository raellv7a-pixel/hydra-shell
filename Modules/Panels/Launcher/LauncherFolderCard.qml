import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

LauncherHomeButton {
  id: root
  required property var folder
  required property var homeView
  required property int folderIndex
  surface: Color.mSurfaceContainerHigh
  text: folder.name
  Accessible.description: I18n.tr("launcher-home.app-count", { count: folder.entries.length })
  padding: launcher.metrics.padding
  implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
  onClicked: launcher.openFolder(folder.id, root)
  onContextRequested: if (folder.mode === "manual") launcher.editFolder(folder)
  Keys.onPressed: event => {
    if (!homeView.navigateFolder(folderIndex, event))
      launcher.handleHomeItemKey(event, root);
  }
  contentItem: ColumnLayout {
    spacing: root.launcher.metrics.folderGap
    RowLayout {
      Layout.fillWidth: true
      spacing: root.launcher.metrics.gapS
      LauncherFolderIcon { folder: root.folder; Layout.preferredWidth: implicitWidth; Layout.preferredHeight: implicitHeight }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        NText { Layout.fillWidth: true; text: root.folder.name; font.weight: Style.fontWeightSemiBold; pointSize: Style.fontSizeM; elide: Text.ElideRight }
        NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.app-count", { count: root.folder.entries.length }); pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }
      }
      NIcon { icon: "chevron-right"; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: root.launcher.metrics.gapS
      Repeater {
        model: root.folder.entries.slice(0, 4)
        LauncherAppIcon {
          required property var modelData
          Layout.preferredWidth: Math.round(24 * Style.uiScaleRatio)
          Layout.preferredHeight: Layout.preferredWidth
          appIcon: modelData.icon
          Accessible.ignored: true
        }
      }
      Item { Layout.fillWidth: true }
    }
  }
}
