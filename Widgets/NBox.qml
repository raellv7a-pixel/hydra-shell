pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets.Iris

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
  TransformWatcher {
    id: placement
    a: root.QsWindow.contentItem
    b: root
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.radiusM
    border.color: Style.boxBorderColor
    border.width: Style.borderS
    color: {
      if (!IrisStyle.glassy || root.color.a <= 0)
        return root.forceOpaque ? root.color : Style.materialFill(HydraColor.smartAlpha(root.color));
      const highest = Style.sameRgb(root.color, HydraColor.mSurfaceContainerHighest) || Qt.colorEqual(root.color, IrisStyle.surfaceHighest);
      const surfaceRole = highest || Qt.colorEqual(root.color, IrisStyle.surfaceHigh)
          || Style.sameRgb(root.color, HydraColor.mSurface) || Style.sameRgb(root.color, HydraColor.mSurfaceContainerLow)
          || Style.sameRgb(root.color, HydraColor.mSurfaceContainer) || Style.sameRgb(root.color, HydraColor.mSurfaceContainerHigh);
      if (surfaceRole) {
        void placement.transform;
        const p = IrisHostGeometry.scenePoint(root, 0, 0);
        if (!p) return IrisStyle.surfaceOpaque;
        return IrisStyle.readingFill(IrisHostGeometry.screenFor(root.QsWindow.window)?.name ?? "", p.x, p.y, root.width, root.height, highest);
      }
      if (root.forceOpaque) return root.color;
      return Style.materialFill(HydraColor.smartAlpha(root.color));
    }
  }
}
