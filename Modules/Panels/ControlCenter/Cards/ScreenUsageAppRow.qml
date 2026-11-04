import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: screenUsageAppRow

  required property var panelRoot

  property var appData: null
  property int maxSeconds: 1

  implicitHeight: Math.max(Math.round(36 * panelRoot.panelUnit), rowContent.implicitHeight)

  ColumnLayout {
    id: rowContent
    anchors.fill: parent
    spacing: Style.marginXXS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Item {
        Layout.preferredWidth: Math.round(20 * screenUsageAppRow.panelRoot.panelUnit)
        Layout.preferredHeight: Layout.preferredWidth

        Image {
          id: appIconImage
          anchors.fill: parent
          source: screenUsageAppRow.appData?.icon || ThemeIcons.iconForAppId(screenUsageAppRow.appData?.id || "")
          sourceSize: Qt.size(Math.round(24 * panelRoot.panelUnit), Math.round(24 * panelRoot.panelUnit))
          smooth: true
          asynchronous: true
          visible: status === Image.Ready
          fillMode: Image.PreserveAspectFit
        }

        NIcon {
          anchors.centerIn: parent
          icon: "apps"
          pointSize: Style.fontSizeM
          color: HydraColor.mOnSurfaceVariant
          visible: !appIconImage.visible
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: screenUsageAppRow.appData?.name || "--"
        color: HydraColor.mOnSurface
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
        elide: Text.ElideRight
      }

      NText {
        text: screenUsageAppRow.appData?.percent !== undefined ? screenUsageAppRow.appData.percent + "%" : ""
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeXXS
        font.weight: Style.fontWeightRegular
        visible: text !== ""
      }

      NText {
        text: panelRoot.durationText(screenUsageAppRow.appData?.seconds || 0)
        color: HydraColor.mPrimary
        pointSize: Style.fontSizeXS
        font.weight: Style.fontWeightSemiBold
        font.family: Settings.data.ui.fontFixed
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(4, Math.round(5 * panelRoot.panelUnit))
      radius: height / 2
      color: Style.materialFill(HydraColor.mSurfaceContainerLowest)

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0.02, Math.min(1, Number(screenUsageAppRow.appData?.seconds || 0) / Math.max(1, screenUsageAppRow.maxSeconds)))
        radius: parent.radius
        color: HydraColor.mPrimary
        opacity: 0.9

        Behavior on width {
          enabled: !screenUsageAppRow.panelRoot.dashboardPerformanceMode && Style.animationNormal > 0
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
