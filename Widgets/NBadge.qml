import QtQuick
import qs.Commons

// Small count/status badge with a Material 3 Expressive scale-in entrance:
// pops in with a spring bounce when it becomes visible (e.g. an unread
// count going from 0 to >0) instead of appearing instantly. Falls back to
// an instant appearance when motion is disabled or performance mode is
// active.
Item {
  id: root

  property bool active: false
  property string text: ""
  property color color: Color.mError
  property color textColor: Color.mOnError
  property real dotSize: Math.round(7 * Style.uiScaleRatio)

  readonly property bool hasText: root.text.length > 0

  implicitWidth: hasText ? Math.max(dotSize, label.implicitWidth + Style.spaceXXS * 2) : dotSize
  implicitHeight: hasText ? Math.max(dotSize, label.implicitHeight + Style.marginXXXS * 2) : dotSize

  visible: scale > 0.01
  scale: root.active ? 1.0 : 0.0

  Behavior on scale {
    enabled: Style.motionEnabled
    SpringAnimation {
      spring: 3.6
      damping: 0.32
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusCapsule
    color: root.color
    border.color: Color.mSurface
    border.width: Style.borderS
  }

  NText {
    id: label
    anchors.centerIn: parent
    visible: root.hasText
    text: root.text
    color: root.textColor
    pointSize: Style.fontSizeLabelSmall
    font.weight: Style.fontWeightSemiBold
  }
}
