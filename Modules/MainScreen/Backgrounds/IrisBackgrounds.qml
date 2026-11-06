pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services.UI
import qs.Widgets.Iris

// Hydra geometry adapter. All silhouettes, joins, shadows and finishes use the original field.
Item {
  id: root
  required property var bar
  required property var windowRoot
  readonly property bool barShown: BarService.effectivelyVisible && (root.separate ? Settings.data.bar.backgroundOpacity : Settings.data.ui.panelBackgroundOpacity) > 0 && ((Settings.data.bar.monitors || []).length === 0 || Settings.data.bar.monitors.includes(windowRoot.screen?.name))
  readonly property bool framed: barShown && root.barPresence > 0 && Settings.data.bar.barType === "framed"
  readonly property real band: Settings.data.bar.frameThickness ?? 12
  readonly property real frameRadius: Settings.data.bar.frameRadius ?? 20
  readonly property string barPosition: Settings.getBarPositionForScreen(windowRoot.screen?.name)
  readonly property bool separate: Settings.data.bar.useSeparateOpacity
  readonly property real barPresence: barShown && !bar?.isHidden ? 1 : 0
  readonly property vector4d insets: Qt.vector4d(barPosition === "left" ? bar.width : band, barPosition === "top" ? bar.height : band, barPosition === "right" ? bar.width : band, barPosition === "bottom" ? bar.height : band)
  readonly property real barLipClearance: Settings.data.bar.showCapsule
      ? Math.max(1, Math.floor((root.bar.barHeight - Style.getCapsuleHeightForScreen(root.windowRoot.screen?.name)) / 2))
      : IrisStyle.afterglowShape.x
  readonly property vector4d bevelLimits: Qt.vector4d(
      barPosition === "left" ? barLipClearance : IrisStyle.afterglowShape.x,
      barPosition === "top" ? barLipClearance : IrisStyle.afterglowShape.x,
      barPosition === "right" ? barLipClearance : IrisStyle.afterglowShape.x,
      barPosition === "bottom" ? barLipClearance : IrisStyle.afterglowShape.x)
  readonly property var panels: Settings.data.ui.panelBackgroundOpacity <= 0 ? [] : PanelService.backgroundSlotAssignments.filter(panel => panel && panel.screen === root.windowRoot.screen && panel.panelRegion?.visible && panel.panelRegion.panelItem?.width > 0 && panel.panelRegion.panelItem?.height > 0)
  readonly property var panelShapes: root.panels.map((panel, index) => {
    const body = panel.panelRegion.panelItem;
    const r = Style.radiusL;
    const joins = [];
    const attached = panel.contentItem?.allowAttach ?? (Settings.data.ui.panelsAttachedToBar || panel.forceAttachToBar);
    const frameLeft = attached && root.framed && body.x <= root.insets.x + 1;
    const frameTop = attached && root.framed && body.y <= root.insets.y + 1;
    const frameRight = attached && root.framed && body.x + body.width >= root.width - root.insets.z - 1;
    const frameBottom = attached && root.framed && body.y + body.height >= root.height - root.insets.w - 1;
    if (frameLeft || frameTop || frameRight || frameBottom)
      joins.push("frame");
    else if (attached && root.barShown && !root.framed && (Math.abs(body.y - (root.bar.y + root.bar.height)) <= 2 || Math.abs(body.x - (root.bar.x + root.bar.width)) <= 2 || Math.abs(body.y + body.height - root.bar.y) <= 2 || Math.abs(body.x + body.width - root.bar.x) <= 2))
      joins.push("bar");
    // SmartPanel's inverted attachment corners are structural, not material
    // melt. Bury the convex cap inside the frame, then form the shoulder with
    // the original SDF union (its zero contour reaches k/4 from a junction).
    const left = frameLeft ? r : 0;
    const top = frameTop ? r : 0;
    const right = frameRight ? r : 0;
    const bottom = frameBottom ? r : 0;
    // The frame is one SDF: cap the union before it can reach another,
    // deliberately detached edge of this panel.
    const clearance = Math.max(0, Math.min(
      frameLeft ? Infinity : body.x - root.insets.x,
      frameTop ? Infinity : body.y - root.insets.y,
      frameRight ? Infinity : root.width - root.insets.z - body.x - body.width,
      frameBottom ? Infinity : root.height - root.insets.w - body.y - body.height));
    return {id: "panel-" + index, x: body.x - left, y: body.y - top,
      width: body.width + left + right, height: body.height + top + bottom,
      radius: r, joins: joins,
      fuse: joins.includes("frame") ? Math.min(Math.max(IrisStyle.fuseDeep, 4 * r), clearance) : IrisStyle.fuseDeep,
      paints: false};
  })
  readonly property var barShapes: {
    const bodies = [];
    if (root.barShown && !root.framed && root.barPresence > 0 && root.bar.width > 0 && root.bar.height > 0)
      bodies.push({id: "bar", x: root.bar.x, y: root.bar.y, width: root.bar.width, height: root.bar.height,
        radius: Settings.data.bar.barType === "floating" ? Style.radiusL : 0, paints: false});
    const shelf = root.windowRoot.edgeShelfVisual;
    const depth = shelf?.frameBulgeDepth ?? 0;
    if (root.framed && depth > 0) {
      const half = Math.max(1, shelf?.frameBulgeHalfHeight ?? Style.baseWidgetSize * 1.5);
      const centre = Math.max(root.insets.y + root.frameRadius + half, Math.min(root.height - root.insets.w - root.frameRadius - half, shelf?.frameCenterY ?? root.height / 2));
      bodies.push({id: "shelf", x: root.insets.x - half, y: centre - half, width: half + depth, height: 2 * half,
        radius: half, joins: "frame", fuse: IrisStyle.fuseDeep, paints: false});
    }
    return bodies;
  }

  IrisField {
    id: field
    anchors.fill: parent
    framed: root.framed
    band: root.band
    frameInsets: root.insets
    cornerRadius: root.frameRadius
    sceneSize: Qt.size(root.width, root.height)
    lightInScene: true
    lightFrom: root.barPosition
    frameBevelLimits: root.bevelLimits
    glassTint: IrisStyle.glassTint * (root.separate ? Settings.data.bar.backgroundOpacity : Settings.data.ui.panelBackgroundOpacity)
    shapes: root.separate ? root.barShapes : root.barShapes.concat(root.panelShapes)
  }
  Loader {
    anchors.fill: parent
    active: root.separate && root.panelShapes.length > 0
    sourceComponent: IrisField {
      anchors.fill: parent
      framed: root.framed
      band: root.band
      frameInsets: root.insets
      cornerRadius: root.frameRadius
      paintsFrame: false
      unpaintedShape: "bar"
      sceneSize: Qt.size(root.width, root.height)
      lightInScene: true
      lightFrom: root.barPosition
      frameBevelLimits: root.bevelLimits
      glassTint: IrisStyle.glassTint * Settings.data.ui.panelBackgroundOpacity
      shapes: root.barShapes.filter(shape => shape.id === "bar").map(shape => Object.assign({}, shape, {paints: true})).concat(root.panelShapes)
    }
  }
  Repeater {
    model: root.panels
    delegate: Item {
      required property var modelData
      readonly property var body: modelData.panelRegion?.panelItem
      x: body?.x ?? 0
      y: body?.y ?? 0
      width: body?.width ?? 0
      height: body?.height ?? 0
      IrisReadingPlate {
        visible: !(modelData.contentItem?.materialReadingCards ?? false)
        anchors.fill: parent
        radius: Style.radiusL
        tint: IrisStyle.glassTint * Settings.data.ui.panelBackgroundOpacity
      }
    }
  }
}
