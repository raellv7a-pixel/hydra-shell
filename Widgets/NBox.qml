import QtQuick
import qs.Commons

// Rounded group container elevated above its parent panel.
// To be used in side panels and settings panes to group fields or buttons.
// Inner fills follow the global material while forceOpaque keeps a solid surface.

Item {
  id: root

  property color color: HydraColor.mSurfaceContainerHigh
  property bool forceOpaque: false
  property alias radius: bg.radius
  property alias border: bg.border
  // Per-corner overrides (-1 keeps the shared `radius`), used to fuse a box with
  // an adjacent one into a single Material 3 connected group.
  property alias topLeftRadius: bg.topLeftRadius
  property alias topRightRadius: bg.topRightRadius
  property alias bottomLeftRadius: bg.bottomLeftRadius
  property alias bottomRightRadius: bg.bottomRightRadius

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.radiusM
    border.color: Style.boxBorderColor
    border.width: Style.borderS
    color: {
      if (forceOpaque) {
        return root.color;
      }

      return Style.materialFill(HydraColor.smartAlpha(root.color));
    }
    gradient: Style.materialEffectsEnabled && Style.materialChromeAmount > 0.1 && bg.color.a > 0 ? chrome : null
    Gradient {
      id: chrome
      GradientStop { position: 0; color: Style.materialRelief(bg.color, Style.materialChromeAmount * 0.08) }
      GradientStop { position: 0.44; color: bg.color }
      GradientStop { position: 0.48; color: Style.materialRelief(bg.color, Style.materialChromeAmount * 0.14) }
      GradientStop { position: 0.55; color: Style.materialRelief(bg.color, -Style.materialChromeAmount * 0.18) }
      GradientStop { position: 1; color: bg.color }
    }
  }
}
