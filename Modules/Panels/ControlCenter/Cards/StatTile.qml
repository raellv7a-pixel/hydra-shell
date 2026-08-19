import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: statTile

  styleKey: panelRoot.inheritedStyleKey(parent)

  property string labelText: ""
  property string valueText: ""
  property string detailText: ""
  property string iconName: ""
  property real ratio: 0
  property color fillColor: Color.mPrimary

  Layout.preferredHeight: Math.round(104 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    NCircleStat {
      ratio: statTile.ratio
      icon: statTile.iconName
      fillColor: statTile.fillColor
      contentScale: 0.78 * panelRoot.localScale
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS

      NText {
        text: labelText
        color: panelRoot.componentText(statTile.styleKey, false)
        pointSize: Style.fontSizeS
      }

      NText {
        text: valueText
        pointSize: Style.fontSizeXXL
        color: panelRoot.componentText(statTile.styleKey, true)
        font.weight: Style.fontWeightSemiBold
      }

      NText {
        Layout.fillWidth: true
        text: detailText
        color: panelRoot.componentText(statTile.styleKey, false)
        pointSize: Style.fontSizeS
        elide: Text.ElideRight
      }
    }
  }
}
