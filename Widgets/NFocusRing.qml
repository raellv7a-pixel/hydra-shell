import QtQuick
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property bool focusVisible: parent ? parent.activeFocus : false
  property bool ringEnabled: true
  property real targetRadius: parent && parent.radius !== undefined ? parent.radius : Style.radiusControl
  property color ringColor: Color.mPrimary
  property real ringOffset: Style.focusRingOffset

  anchors.fill: parent
  anchors.margins: -ringOffset
  z: 100
  radius: targetRadius + ringOffset
  color: "transparent"
  border.width: Style.focusRingWidth
  border.color: ringColor
  opacity: ringEnabled && focusVisible ? 1 : 0
  scale: ringEnabled && focusVisible ? 1 : Style.morphPressedScale
  antialiasing: true

  Behavior on opacity {
    NAnim {
      duration: Style.motionDurationFastEffects
      motionType: NAnim.StandardEffects
    }
  }

  Behavior on scale {
    NAnim {
      motionType: NAnim.EmphasizedSpatial
    }
  }
}
