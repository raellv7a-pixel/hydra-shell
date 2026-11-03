import QtQuick
import QtQuick.Layouts
import "Helpers/LauncherArtwork.js" as LauncherArtwork
import qs.Commons
import qs.Widgets

NBox {
  id: root
  required property var launcher
  color: HydraColor.mSurfaceContainerHigh
  forceOpaque: true
  radius: Style.radiusL
  border.width: 0
  readonly property var provider: launcher.defaultProvider
  readonly property var categoryRows: {
    const pinned = Settings.data.appLauncher.pinnedApps;
    const hidden = Settings.data.appLauncher.hiddenApps;
    return launcher.providerCategories.filter(category => category !== "all").map(category => ({
      category: category,
      count: provider.entries.filter(app => provider.appMatchesCategory(app, category) && (category === "Hidden" || !provider.isAppHidden(app))).length
    }));
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
        launcher: root.launcher
        text: I18n.tr("launcher-home.all-apps")
        Layout.fillWidth: true
        implicitHeight: Math.max(Math.round(72 * Style.uiScaleRatio), contentItem.implicitHeight + topPadding + bottomPadding)
        leftPadding: Style.marginL
        rightPadding: Style.marginM
        surface: HydraColor.mPrimaryContainer
        foreground: HydraColor.mOnPrimaryContainer
        Accessible.selected: true
        onClicked: launcher.openAllApps("all")
        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: Style.marginXXS
          anchors.verticalCenter: parent.verticalCenter
          width: Style.marginXS
          height: parent.height - Style.margin2XL
          radius: width / 2
          color: HydraColor.mPrimary
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
            NText { Layout.fillWidth: true; text: I18n.tr("launcher-home.all-apps"); font.weight: Style.fontWeightSemiBold; color: HydraColor.mOnPrimaryContainer; elide: Text.ElideRight }
            NText {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: I18n.tr("launcher-home.installed-count", {count: root.launcher.browseModel.visibleApps.length})
              pointSize: Style.fontSizeS
              color: HydraColor.mOnPrimaryContainer
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
        model: root.categoryRows
        LauncherHomeButton {
          id: categoryButton
          required property var modelData
          launcher: root.launcher
          Layout.fillWidth: true
          implicitHeight: Math.max(Math.round(48 * Style.uiScaleRatio), contentItem.implicitHeight + topPadding + bottomPadding)
          leftPadding: Style.marginL
          rightPadding: Style.marginM
          readonly property bool selected: root.provider.selectedCategory === modelData.category
          surface: selected ? HydraColor.mSecondaryContainer : "transparent"
          foreground: selected ? HydraColor.mOnSecondaryContainer : HydraColor.mOnSurface
          text: root.provider.getCategoryName(modelData.category)
          Accessible.selected: selected
          onClicked: launcher.openAllApps(modelData.category)
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
              icon: LauncherArtwork.categoryIcon(categoryButton.modelData.category, root.provider, root.provider)
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
            Rectangle {
              Layout.minimumWidth: Style.marginXL + Style.marginS
              Layout.preferredWidth: Math.max(Layout.minimumWidth, categoryCount.implicitWidth + Style.margin2S)
              Layout.preferredHeight: categoryCount.implicitHeight + Style.margin2XXS
              radius: Style.radiusXXS
              color: categoryButton.selected ? HydraColor.mSurfaceContainerHighest : HydraColor.mSurfaceContainer
              NText {
                id: categoryCount
                anchors.centerIn: parent
                text: categoryButton.modelData.count
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightMedium
                color: HydraColor.mOnSurfaceVariant
              }
            }
          }
        }
      }
    }
  }
}
