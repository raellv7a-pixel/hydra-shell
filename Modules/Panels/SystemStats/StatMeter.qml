pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property string label: ""
  property string valueText: ""
  property real ratio: -1
  property color accent: HydraColor.mSecondary
  spacing: Style.marginS
  implicitHeight: 40 * Style.uiScaleRatio
  RowLayout {
    Layout.fillWidth: true
    NText {
      text: root.label
      pointSize: Style.fontSizeXS
      color: HydraColor.mOnSurfaceVariant
    }
    NText {
      Layout.fillWidth: true
      text: root.valueText
      pointSize: Style.fontSizeXS
      font.family: Settings.data.ui.fontFixed
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }
  }
  Item {
    id: bar
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginM
    readonly property int segments: Math.max(8, Math.min(40, Math.floor(width / (Style.marginXS + Style.marginXXS))))
    Repeater {
      model: bar.segments
      Rectangle {
        required property int index
        x: Math.round(index * bar.width / bar.segments)
        width: Math.max(0, Math.round((index + 1) * bar.width / bar.segments) - x - Style.marginXXS)
        height: bar.height
        radius: Style.iRadiusXXXS
        color: root.ratio >= 0 && index / bar.segments < root.ratio ? root.accent : HydraColor.mSurfaceContainerHighest
      }
    }
  }
}
