import QtQuick
import qs.Commons
import qs.Widgets

NBox {
  id: root
  required property var launcher
  color: Style.materialFill(HydraColor.mSurfaceContainerLow)
  forceOpaque: true
  border.width: 0
  radius: Style.radiusL
  NImageRounded {
    anchors.fill: parent
    visible: root.launcher.hasCoverBanner && root.launcher.profileWallpaperPath !== ""
    imagePath: root.launcher.profileWallpaperPath
    imageSourceSize: Qt.size(Math.ceil(width), -1)
    radius: root.radius
    Accessible.ignored: true
  }
}
