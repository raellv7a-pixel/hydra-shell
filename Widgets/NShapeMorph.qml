import QtQuick
import qs.Commons
import qs.Widgets

Item {
  id: root
  visible: false

  property bool hovered: false
  property bool pressed: false
  property bool focused: false
  property bool selected: false
  property real restingRadius: Style.radiusControl
  property real hoverRadius: Style.radiusControlChecked
  property real pressedRadius: Style.radiusControlPressed
  property real selectedRadius: Style.radiusControlChecked
  property real radius: {
    if (!enabled)
      return restingRadius;
    if (pressed)
      return pressedRadius;
    if (selected)
      return selectedRadius;
    if (hovered || focused)
      return hoverRadius;
    return restingRadius;
  }
  property real scale: {
    if (!enabled)
      return 1;
    if (pressed)
      return Style.morphPressedScale;
    if (hovered || focused)
      return Style.morphHoverScale;
    return 1;
  }

  Behavior on radius {
    NAnim {
      motionType: NAnim.ExpressiveFastSpatial
    }
  }

  Behavior on scale {
    NAnim {
      motionType: NAnim.ExpressiveFastSpatial
    }
  }
}
