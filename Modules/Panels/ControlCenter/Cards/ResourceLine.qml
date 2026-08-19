import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
RowLayout {
  id: resourceLine

  property string iconName: ""
  property string labelText: ""
  property string valueText: ""

  Layout.fillWidth: true
  spacing: Style.marginS

  NIcon {
    icon: iconName
    pointSize: Style.fontSizeM
    color: Color.mPrimary
  }

  NText {
    Layout.fillWidth: true
    text: labelText
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    elide: Text.ElideRight
  }

  NText {
    text: valueText
    color: Color.mOnSurface
    pointSize: Style.fontSizeS
    font.family: Settings.data.ui.fontFixed
    horizontalAlignment: Text.AlignRight
  }
}
