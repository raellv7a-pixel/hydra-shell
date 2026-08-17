import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root

  property bool hovered: false
  property bool pressed: false
  property bool focused: false
  property bool dragged: false
  property bool selected: false
  property bool rippleEnabled: true
  property color stateColor: Color.mOnSurface
  property real radius: parent && parent.radius !== undefined ? parent.radius : Style.radiusControl
  readonly property alias rippleRunning: ripple.running
  readonly property real stateOpacity: {
    if (!root.enabled)
      return 0;

    let value = root.selected ? Style.stateSelectedOpacity : 0;
    if (root.hovered)
      value = Math.max(value, Style.stateHoverOpacity);
    if (root.focused)
      value = Math.max(value, Style.stateFocusOpacity);
    if (root.pressed)
      value = Math.max(value, Style.statePressedOpacity);
    if (root.dragged)
      value = Math.max(value, Style.stateDraggedOpacity);
    return value;
  }

  function rippleAt(x, y) {
    if (rippleEnabled)
      ripple.triggerAt(x, y);
  }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.stateColor
    opacity: root.stateOpacity

    Behavior on opacity {
      NAnim {
        duration: Style.motionDurationFastEffects
        motionType: NAnim.StandardEffects
      }
    }
  }

  NRipple {
    id: ripple

    anchors.fill: parent
    enabled: root.enabled && root.rippleEnabled
    color: root.stateColor
  }
}
