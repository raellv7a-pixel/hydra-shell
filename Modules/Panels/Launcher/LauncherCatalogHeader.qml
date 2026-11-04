import QtQuick
import QtQuick.Layouts
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
    visible: root.launcher.hasCoverBanner
    imagePath: root.launcher.profileWallpaperPath
    radius: root.radius
    opacity: Style.opacityLight
  }
  RowLayout {
    anchors.fill: parent
    anchors.margins: root.launcher.metrics.padding
    spacing: Style.marginXL
    NColorIcon {
      icon: "grid-dots"
      size: Math.round(56 * Style.uiScaleRatio)
      Layout.minimumWidth: size
      Layout.maximumWidth: size
      Accessible.ignored: true
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS
      NText {
        Layout.fillWidth: true
        text: I18n.tr("launcher-home.all-apps")
        pointSize: Style.fontSizeXXXL
        font.weight: Style.fontWeightBold
        elide: Text.ElideRight
        Accessible.role: Accessible.Heading
      }
      NText {
        Layout.fillWidth: true
        text: I18n.tr("launcher-home.installed-count", {count: root.launcher.browseModel.visibleApps.length})
        pointSize: Style.fontSizeM
        color: HydraColor.mOnSurfaceVariant
        elide: Text.ElideRight
      }
    }
  }
}
