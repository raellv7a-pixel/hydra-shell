import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: weatherInfoTile

  property string iconName: ""
  property string titleText: ""
  property string valueText: ""

  Layout.preferredHeight: Math.round(62 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NIcon {
      icon: weatherInfoTile.iconName
      pointSize: Style.fontSizeL
      color: Color.mPrimary
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      NText {
        Layout.fillWidth: true
        text: weatherInfoTile.titleText
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        elide: Text.ElideRight
      }

      NText {
        Layout.fillWidth: true
        text: weatherInfoTile.valueText
        color: Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }
    }
  }
}
