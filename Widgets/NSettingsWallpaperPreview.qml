pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI

// Read-only: getWallpaper() can inherit/write a monitor entry, so use slot lookup.
ColumnLayout {
  id: root
  property var screen: null
  property int wallpaperRevision: 0
  readonly property string screenName: screen?.name || ""
  readonly property real screenAspect: screen && screen.height > 0 ? screen.width / screen.height : 16 / 9
  readonly property string wallpaperPath: {
    // Track in-place cache updates notified by wallpaperChanged.
    root.wallpaperRevision;
    return WallpaperService.getWallpaperPathForSlot(screenName, Settings.data.colorSchemes.darkMode ? "dark" : "light") || WallpaperService.defaultWallpaper;
  }
  readonly property bool solidWallpaper: WallpaperService.isSolidColorPath(wallpaperPath)
  readonly property int imageFillMode: {
    switch (Settings.data.wallpaper.fillMode) {
    case "center":
      return Image.Pad;
    case "fit":
      return Image.PreserveAspectFit;
    case "stretch":
      return Image.Stretch;
    case "repeat":
      return Image.Tile;
    default:
      return Image.PreserveAspectCrop;
    }
  }

  Layout.fillWidth: true
  spacing: Style.marginS
  Connections {
    target: WallpaperService
    function onWallpaperChanged(screenName, path) {
      if (screenName === root.screenName)
        root.wallpaperRevision++;
    }
  }

  NText {
    Layout.fillWidth: true
    text: I18n.tr("settings.content.shared.wallpaper-preview") + (root.screenName !== "" ? " · " + root.screenName : "")
    pointSize: Style.fontSizeS
    color: HydraColor.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }
  Loader {
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(180 * Style.uiScaleRatio, width / root.screenAspect)
    active: root.visible
    sourceComponent: Item {
      Rectangle {
        id: viewport
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * root.screenAspect)
        height: parent.height
        color: root.solidWallpaper ? WallpaperService.getSolidColor(root.wallpaperPath) : Settings.data.wallpaper.fillColor
        clip: true
        Accessible.ignored: true
        Image {
          id: wallpaperImage
          anchors.fill: parent
          source: root.solidWallpaper ? "" : root.wallpaperPath
          sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
          fillMode: root.imageFillMode
          asynchronous: true
          smooth: true
          mipmap: true
        }
        NIcon {
          anchors.centerIn: parent
          icon: "photo-off"
          visible: wallpaperImage.status === Image.Error
          color: HydraColor.mOnSurfaceVariant
          Accessible.name: I18n.tr("settings.content.preview-unavailable")
        }
      }
    }
  }
  NText {
    Layout.fillWidth: true
    text: I18n.tr("settings.content.shared.wallpaper-preview-description")
    pointSize: Style.fontSizeXS
    color: HydraColor.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }
}
