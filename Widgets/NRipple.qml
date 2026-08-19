import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root

  property color color: Color.mOnSurface
  readonly property alias running: pulse.running

  clip: true

  function triggerAt(x, y) {
    if (!enabled || !Style.motionEnabled)
      return;

    ripple.x = x - ripple.width / 2;
    ripple.y = y - ripple.height / 2;
    pulse.restart();
  }

  Rectangle {
    id: ripple

    width: Math.hypot(root.width, root.height) * 2
    height: width
    radius: width / 2
    color: root.color
    opacity: 0
    scale: 0
  }

  ParallelAnimation {
    id: pulse

    NAnim {
      target: ripple
      property: "scale"
      from: 0
      to: 1
      motionType: NAnim.ExpressiveDefaultSpatial
    }

    SequentialAnimation {
      NAnim {
        target: ripple
        property: "opacity"
        from: Style.statePressedOpacity
        to: Style.stateHoverOpacity
        duration: Style.motionDurationFastEffects
        motionType: NAnim.StandardEffects
      }

      NAnim {
        target: ripple
        property: "opacity"
        to: 0
        duration: Style.motionDurationSlowEffects
        motionType: NAnim.StandardEffects
      }
    }
  }
}
