import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
RowLayout {
  id: headerRow

  required property var panelRoot

  property string title: ""
  property string subtitle: ""
  property string styleKey: panelRoot.inheritedStyleKey(parent)
  Layout.fillWidth: true
  spacing: Style.marginM

  NText {
    Layout.fillWidth: true
    text: title
    pointSize: Style.fontSizeXL
    font.weight: Style.fontWeightSemiBold
    color: panelRoot.componentText(styleKey, true)
    elide: Text.ElideRight
  }

  NText {
    text: subtitle
    pointSize: Style.fontSizeS
    font.weight: Style.fontWeightMedium
    color: panelRoot.componentText(styleKey, false)
  }
}
