import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: screenUsageRangeButton

  property string labelText: ""
  property int days: 1
  readonly property bool selected: panelRoot.screenUsageRangeDays === days

  Layout.preferredHeight: Math.round(32 * panelRoot.panelUnit)
  color: selected ? Color.mPrimary : panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS
  border.color: selected ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.18)

  NText {
    anchors.centerIn: parent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    text: screenUsageRangeButton.labelText
    color: screenUsageRangeButton.selected ? Color.mOnPrimary : Color.mOnSurfaceVariant
    pointSize: Style.fontSizeXS
    font.weight: screenUsageRangeButton.selected ? Style.fontWeightSemiBold : Style.fontWeightMedium
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
  }

  TapHandler {
    onTapped: panelRoot.screenUsageRangeDays = screenUsageRangeButton.days
  }
}
