import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: detailMetric

  styleKey: panelRoot.inheritedStyleKey(parent)

  property string titleText: ""
  property string valueText: ""
  property real valuePointSize: Style.fontSizeXL
  property string detailText: ""
  property string iconName: ""
  property color fillColor: panelRoot.componentAccent(styleKey)

  Layout.preferredHeight: Math.round(78 * panelRoot.panelUnit)
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    Rectangle {
      Layout.preferredWidth: Math.round(38 * panelRoot.panelUnit)
      Layout.preferredHeight: Layout.preferredWidth
      radius: width / 2
      color: Qt.alpha(detailMetric.fillColor, 0.16)

      NIcon {
        anchors.centerIn: parent
        icon: detailMetric.iconName
        pointSize: Style.fontSizeL
        color: detailMetric.fillColor
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS

      NText {
        text: detailMetric.titleText
        color: panelRoot.componentText(detailMetric.styleKey, false)
        pointSize: Style.fontSizeS
      }

      NText {
        Layout.fillWidth: true
        text: detailMetric.valueText
        color: panelRoot.componentText(detailMetric.styleKey, true)
        pointSize: detailMetric.valuePointSize
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }

      NText {
        Layout.fillWidth: true
        text: detailMetric.detailText
        color: panelRoot.componentText(detailMetric.styleKey, false)
        pointSize: Style.fontSizeXS
        elide: Text.ElideRight
      }
    }
  }
}
