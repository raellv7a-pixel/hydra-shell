import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Icon + label + value row wrapping a ReactiveSlider. Used by AudioDetailsCard
// (volume/mic) and SystemControlsCard (brightness).
ColumnLayout {
  id: controlSlider

  required property var panelRoot

  property string iconName: ""
  property string labelText: ""
  property string valueText: ""
  property real value: 0
  property string reactiveEffect: "none"
  property bool reactiveActive: false
  property real reactiveLevel: 0
  property var reactiveValues: []
  property bool reactiveOverflow: false
  signal moved(real value)

  Layout.fillWidth: true
  spacing: Style.marginS
  opacity: enabled ? 1 : 0.45

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NIcon {
      icon: iconName
      pointSize: Style.fontSizeL
      color: Color.mPrimary
    }

    NText {
      Layout.fillWidth: true
      text: labelText
      color: Color.mOnSurface
      font.weight: Style.fontWeightMedium
    }

    NText {
      text: valueText
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
    }
  }

  ReactiveSlider {
    panelRoot: controlSlider.panelRoot
    Layout.fillWidth: true
    from: 0
    to: 1
    stepSize: 0.01
    value: controlSlider.value
    effect: controlSlider.reactiveEffect
    effectActive: controlSlider.reactiveActive
    effectLevel: controlSlider.reactiveLevel
    effectValues: controlSlider.reactiveValues
    overflowEffects: controlSlider.reactiveOverflow
    onMoved: controlSlider.moved(value)
  }
}
