import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: trafficTile

  property string iconName: ""
  property string titleText: ""
  property string valueText: ""

  Layout.preferredHeight: Math.round(64 * panelRoot.panelUnit)
  color: Qt.alpha(HydraColor.mPrimary, 0.09)
  radius: Style.radiusS

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NIcon {
      icon: iconName
      pointSize: Style.fontSizeM
      color: HydraColor.mPrimary
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS

      NText {
        text: titleText
        color: HydraColor.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        text: valueText
        color: HydraColor.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }
    }
  }
}
