import QtQuick
import QtQuick.Layouts
import "Helpers/LauncherArtwork.js" as LauncherArtwork
import qs.Commons
import qs.Widgets

Item {
  id: root
  required property var launcher
  readonly property var provider: launcher.defaultProvider
  NDropShadow {
    anchors.fill: surface
    source: surface
    autoPaddingEnabled: true
    shadowColor: HydraColor.mShadow
    shadowOpacity: Style.shadowOpacity * Style.opacityLight
    shadowHorizontalOffset: 0
    shadowVerticalOffset: Style.marginXXS
  }
  NBox {
    id: surface
    anchors.fill: parent
    color: Style.materialFill(HydraColor.mSurfaceContainerHigh)
    forceOpaque: true
    radius: Style.radiusL
    border.width: 0
  }
  Flickable {
    anchors.fill: parent
    anchors.margins: root.launcher.metrics.gapM
    contentWidth: width
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    interactive: !Settings.data.appLauncher.ignoreMouseInput && contentHeight > height
    ColumnLayout {
      id: body
      width: parent.width
      spacing: root.launcher.metrics.gapS
      LauncherHomeButton {
        launcher: root.launcher
        text: I18n.tr("launcher-home.home")
        Layout.fillWidth: true
        implicitHeight: Math.max(Math.round(68 * Style.uiScaleRatio), contentItem.implicitHeight + topPadding + bottomPadding)
        leftPadding: Style.marginL
        rightPadding: Style.marginM
        surface: "transparent"
        onClicked: launcher.goHome()
        contentItem: RowLayout {
          spacing: Style.marginM
          NColorIcon {
            icon: "home"
            size: Math.round(28 * Style.uiScaleRatio)
            Layout.minimumWidth: size
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.home"); elide: Text.ElideRight }
            NText {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: I18n.tr("launcher-home.home-description")
              pointSize: Style.fontSizeS
              color: HydraColor.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
            }
          }
        }
      }
      LauncherHomeButton {
        id: allAppsButton
        readonly property bool selected: root.provider.selectedCategory === "all"
        launcher: root.launcher
        text: I18n.tr("launcher-home.all-apps")
        Layout.fillWidth: true
        implicitHeight: Math.max(Math.round(72 * Style.uiScaleRatio), contentItem.implicitHeight + topPadding + bottomPadding)
        leftPadding: Style.marginL
        rightPadding: Style.marginM
        surface: selected ? HydraColor.mPrimaryContainer : "transparent"
        foreground: selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurface
        raisedSurface: selected
        Accessible.selected: selected
        onClicked: launcher.openAllApps("all")
        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: Style.marginXXS
          anchors.verticalCenter: parent.verticalCenter
          width: Style.marginXS
          height: parent.height - Style.margin2XL
          radius: width / 2
          color: HydraColor.mPrimary
          visible: allAppsButton.selected
          Accessible.ignored: true
        }
        contentItem: RowLayout {
          spacing: Style.marginM
          NColorIcon {
            icon: "grid-dots"
            size: Math.round(28 * Style.uiScaleRatio)
            Layout.minimumWidth: size
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS
            NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.all-apps"); font.weight: Style.fontWeightSemiBold; color: allAppsButton.foreground; elide: Text.ElideRight }
            NText {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: I18n.tr("launcher-home.installed-count", {count: root.launcher.browseModel.visibleApps.length})
              pointSize: Style.fontSizeS
              color: allAppsButton.selected ? HydraColor.mOnPrimaryContainer : HydraColor.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
            }
          }
        }
      }
      NText {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL
        Layout.bottomMargin: Style.marginS
        Layout.leftMargin: Style.marginM
        text: I18n.tr("launcher.app-properties.categories")
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
        color: HydraColor.mOnSurfaceVariant
        Accessible.role: Accessible.Heading
      }
      Repeater {
        model: root.launcher.providerCategories.filter(category => category !== "all")
        LauncherHomeButton {
          id: categoryButton
          required property string modelData
          launcher: root.launcher
          Layout.fillWidth: true
          implicitHeight: Math.max(Math.round(48 * Style.uiScaleRatio), contentItem.implicitHeight + topPadding + bottomPadding)
          leftPadding: Style.marginL
          rightPadding: Style.marginM
          readonly property bool selected: root.provider.selectedCategory === modelData
          raisedSurface: selected
          surface: selected ? HydraColor.mSecondaryContainer : "transparent"
          foreground: selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurface
          text: root.provider.getCategoryName(modelData)
          Accessible.selected: selected
          onClicked: launcher.openAllApps(modelData)
          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Style.marginXXS
            anchors.verticalCenter: parent.verticalCenter
            width: Style.marginXS
            height: Style.marginXL
            radius: width / 2
            color: HydraColor.mOnSecondaryContainer
            visible: categoryButton.selected
            Accessible.ignored: true
          }
          contentItem: RowLayout {
            spacing: Style.marginS
            NColorIcon {
              icon: LauncherArtwork.categoryIcon(categoryButton.modelData, root.provider, root.provider)
              size: Math.round(26 * Style.uiScaleRatio)
              Layout.minimumWidth: size
            }
            NText {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: categoryButton.text
              pointSize: Style.fontSizeS
              font.weight: categoryButton.selected ? Style.fontWeightSemiBold : Style.fontWeightMedium
              color: categoryButton.foreground
              wrapMode: Text.WordWrap
              elide: Text.ElideNone
            }
          }
        }
      }
    }
  }
}
