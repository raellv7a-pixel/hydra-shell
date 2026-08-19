import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
RowLayout {
  id: infoLine

  property string iconName: ""
  property string labelText: ""
  property bool coverMode: false
  spacing: Style.marginS

  NIcon {
    icon: iconName
    pointSize: Style.fontSizeM
    color: coverMode ? Qt.alpha("white", 0.92) : Color.mPrimary
  }

  NText {
    Layout.fillWidth: true
    text: labelText
    color: coverMode ? Qt.alpha("white", 0.82) : Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    elide: Text.ElideRight
  }
}
