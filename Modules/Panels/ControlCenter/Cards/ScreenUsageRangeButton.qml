import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NButton {
  id: screenUsageRangeButton

  required property var panelRoot
  property string labelText: ""
  property int days: 1
  readonly property bool selected: panelRoot.screenUsageRangeDays === days

  text: labelText
  fontSize: Style.fontSizeXS
  fontWeight: selected ? Style.fontWeightBold : Style.fontWeightMedium
  buttonRadius: Style.radiusS
  backgroundColor: selected ? HydraColor.mPrimary : Style.materialFill(HydraColor.mSurfaceContainerHigh)
  textColor: selected ? HydraColor.mOnPrimary : HydraColor.mOnSurfaceVariant
  textHoverColor: textColor
  activeFocusOnTab: true
  implicitHeight: Math.max(Math.round(32 * panelRoot.panelUnit), fontSize * 2 + Style.marginS)
  Accessible.role: Accessible.RadioButton
  Accessible.checked: selected
  onClicked: panelRoot.screenUsageRangeDays = days
}
