import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: screenUsageDetailRow

  property var appData: null
  property int maxSeconds: 1

  Layout.preferredHeight: Math.round(66 * panelRoot.panelUnit)
  color: Style.materialFill(HydraColor.mSurfaceContainerHighest)
  radius: Style.radiusS

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "apps"
        pointSize: Style.fontSizeL
        color: HydraColor.mPrimary
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          Layout.fillWidth: true
          text: screenUsageDetailRow.appData?.name || "--"
          color: HydraColor.mOnSurface
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
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
        color: HydraColor.mOnSurface
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightSemiBold
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
        opacity: 0.88
      }
    }
  }
}
