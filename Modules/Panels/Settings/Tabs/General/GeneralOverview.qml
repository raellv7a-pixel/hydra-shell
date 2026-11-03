import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

NBox {
  id: root

  property ShellScreen screen: null
  readonly property string screenName: screen?.name || ""
  property int wallpaperRevision: 0
  readonly property string wallpaperPath: {
    root.wallpaperRevision;
    return WallpaperService.getWallpaper(root.screenName);
  }
  readonly property bool solidWallpaper: WallpaperService.isSolidColorPath(wallpaperPath)
  signal wallpaperRequested
  signal colorsRequested

  Layout.fillWidth: true
  implicitHeight: overviewRow.implicitHeight + Style.margin2XL
  color: HydraColor.mSurfaceContainerLow
  forceOpaque: true
  border.width: 0
  radius: Style.radiusL

  Connections {
    target: WallpaperService
    function onWallpaperChanged(screenName, path) {
      if (screenName === root.screenName)
        root.wallpaperRevision++;
    }
  }

  RowLayout {
    id: overviewRow
    anchors.fill: parent
    anchors.margins: Style.marginXL
    spacing: Style.marginXL

    NBox {
      Layout.preferredWidth: root.width * 0.36
      Layout.preferredHeight: Layout.preferredWidth * 9 / 16
      visible: root.width >= 680 * Style.uiScaleRatio
      color: root.solidWallpaper ? WallpaperService.getSolidColor(root.wallpaperPath) : HydraColor.mSurfaceContainerHigh
      forceOpaque: true
      border.width: 0
      radius: Style.radiusM

      NImageRounded {
        anchors.fill: parent
        radius: Style.radiusM
        imagePath: root.solidWallpaper ? "" : root.wallpaperPath
        fallbackIcon: root.solidWallpaper ? "" : "settings-wallpaper"
        imageSourceSize: Qt.size(Math.round(width), Math.round(height))
        Accessible.ignored: true
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: Style.marginL

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NImageRounded {
          Layout.preferredWidth: Style.baseWidgetSize * 1.5 * Style.uiScaleRatio
          Layout.preferredHeight: Layout.preferredWidth
          radius: width / 2
          imagePath: Settings.preprocessPath(Settings.data.general.avatarImage)
          fallbackIcon: "person"
          imageSourceSize: Qt.size(Math.round(width), Math.round(height))
          Accessible.ignored: true
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: Style.marginXXS
          NText {
            Layout.fillWidth: true
            text: I18n.tr("system.welcome-back")
            pointSize: Style.fontSizeM
            color: HydraColor.mOnSurfaceVariant
            wrapMode: Text.WordWrap
          }
          NText {
            Layout.fillWidth: true
            text: HostService.displayName
            pointSize: Style.fontSizeXXL
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }
        }
      }

      NText {
        Layout.fillWidth: true
        text: ["Hydra", HostService.osPretty, root.screen ? root.screen.width + " × " + root.screen.height : ""].filter(value => value !== "").join(" · ")
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
      }

      Flow {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: I18n.tr("common.wallpaper")
          icon: "settings-wallpaper"
          backgroundColor: HydraColor.mSecondaryContainer
          textColor: HydraColor.mOnSecondaryContainer
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: text
          Accessible.onPressAction: clicked()
          Keys.onReturnPressed: clicked()
          Keys.onSpacePressed: clicked()
          onClicked: root.wallpaperRequested()
          Rectangle {
            anchors.fill: parent
            radius: Style.iRadiusS
            color: "transparent"
            border.width: parent.activeFocus ? Style.borderM : 0
            border.color: HydraColor.mPrimary
          }
        }

        NButton {
          text: I18n.tr("panels.color-scheme.title")
          icon: "settings-color-scheme"
          backgroundColor: HydraColor.mSurfaceContainerHigh
          textColor: HydraColor.mOnSurface
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: text
          Accessible.onPressAction: clicked()
          Keys.onReturnPressed: clicked()
          Keys.onSpacePressed: clicked()
          onClicked: root.colorsRequested()
          Rectangle {
            anchors.fill: parent
            radius: Style.iRadiusS
            color: "transparent"
            border.width: parent.activeFocus ? Style.borderM : 0
            border.color: HydraColor.mPrimary
          }
        }
      }
    }
  }
}
