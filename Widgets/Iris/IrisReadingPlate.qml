pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The original Places plateOver + veil/frost solve, using Hydra's actual output rectangle.
Rectangle {
  id: root
  property real tint: IrisStyle.glassTint
  property string output: IrisHostGeometry.screenFor(root.QsWindow.window)?.name ?? ""
  property var sceneOrigin: {
    void placement.transform;
    return IrisHostGeometry.scenePoint(root, 0, 0);
  }
  color: {
    if (!IrisStyle.glassy) return "transparent";
    void Lume.revision;
    const sample = root.sceneOrigin ? Lume.read(root.output, root.sceneOrigin.x, root.sceneOrigin.y, root.width, root.height) : null;
    const needed = sample ? IrisStyle.legibleVeil("panel", sample.level, sample.spread, 0) : 1;
    return Qt.alpha(IrisStyle.surfaceOpaque, Lume.plateOver(root.tint, needed));
  }
  TransformWatcher {
    id: placement
    a: root.QsWindow.contentItem
    b: root
  }
}
