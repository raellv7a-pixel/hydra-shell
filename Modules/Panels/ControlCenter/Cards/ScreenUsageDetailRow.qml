import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

DashboardCard {
  id: screenUsageDetailRow

  property var appData: null
  property int maxSeconds: 1

  implicitHeight: Math.max(Math.round(68 * panelRoot.panelUnit), rowContent.implicitHeight + Style.marginM * 2)
  color: Style.materialFill(HydraColor.mSurfaceContainerHighest)
  radius: Style.radiusS

  ColumnLayout {
    id: rowContent
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      Item {
        Layout.preferredWidth: Math.round(30 * screenUsageDetailRow.panelRoot.panelUnit)
        Layout.preferredHeight: Layout.preferredWidth

        Rectangle {
          anchors.fill: parent
          radius: Style.radiusXS
          color: Style.materialFill(HydraColor.mSurfaceContainerLow)
        }

        Image {
          id: appIconImage
          anchors.fill: parent
          anchors.margins: Style.marginXXS
          source: screenUsageDetailRow.appData?.icon || ThemeIcons.iconForAppId(screenUsageDetailRow.appData?.id || "")
          sourceSize: Qt.size(Math.round(32 * panelRoot.panelUnit), Math.round(32 * panelRoot.panelUnit))
          smooth: true
          asynchronous: true
          visible: status === Image.Ready
          fillMode: Image.PreserveAspectFit
        }

        NIcon {
          anchors.centerIn: parent
          icon: "apps"
          pointSize: Style.fontSizeL
          color: HydraColor.mPrimary
          visible: !appIconImage.visible
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: Style.marginXXXS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: screenUsageDetailRow.appData?.name || "--"
            color: HydraColor.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            elide: Text.ElideRight
          }

          NText {
            text: screenUsageDetailRow.appData?.percent !== undefined ? screenUsageDetailRow.appData.percent + "%" : ""
            color: HydraColor.mOnSurfaceVariant
            pointSize: Style.fontSizeXXS
            font.weight: Style.fontWeightMedium
            visible: text !== ""
          }
        }

        NText {
          Layout.fillWidth: true
          text: screenUsageDetailRow.appData?.title || screenUsageDetailRow.appData?.id || ""
          visible: text !== ""
          color: HydraColor.mOnSurfaceVariant
          pointSize: Style.fontSizeXXS
          elide: Text.ElideRight
        }
      }

      NText {
        text: panelRoot.durationText(screenUsageDetailRow.appData?.seconds || 0)
        color: HydraColor.mPrimary
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightBold
        font.family: Settings.data.ui.fontFixed
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(5, Math.round(6 * panelRoot.panelUnit))
      radius: height / 2
      color: Style.materialFill(HydraColor.mSurfaceContainerLow)

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0.025, Math.min(1, Number(screenUsageDetailRow.appData?.seconds || 0) / Math.max(1, screenUsageDetailRow.maxSeconds)))
        radius: parent.radius
        color: HydraColor.mPrimary
        opacity: 0.9

        Behavior on width {
          enabled: !screenUsageDetailRow.panelRoot.dashboardPerformanceMode && Style.animationNormal > 0
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
