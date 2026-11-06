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
  readonly property var panels: Settings.data.ui.panelBackgroundOpacity <= 0 ? [] : PanelService.backgroundSlotAssignments.filter(panel => panel && panel.screen === root.windowRoot.screen && panel.panelRegion?.visible && panel.panelRegion.panelItem?.width > 0 && panel.panelRegion.panelItem?.height > 0)
  readonly property var panelShapes: root.panels.map((panel, index) => {
    const body = panel.panelRegion.panelItem;
    const r = Style.radiusL;
    const joins = [];
    const attached = panel.contentItem?.allowAttach ?? (Settings.data.ui.panelsAttachedToBar || panel.forceAttachToBar);
    if (attached && root.framed && (body.x <= root.insets.x + 1 || body.y <= root.insets.y + 1 || body.x + body.width >= root.width - root.insets.z - 1 || body.y + body.height >= root.height - root.insets.w - 1))
      joins.push("frame");
    else if (attached && root.barShown && !root.framed && (Math.abs(body.y - (root.bar.y + root.bar.height)) <= 2 || Math.abs(body.x - (root.bar.x + root.bar.width)) <= 2 || Math.abs(body.y + body.height - root.bar.y) <= 2 || Math.abs(body.x + body.width - root.bar.x) <= 2))
      joins.push("bar");
    return {id: "panel-" + index, x: body.x, y: body.y, width: body.width, height: body.height,
      radius: r, joins: joins, fuse: IrisStyle.fuseDeep, paints: false};
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
      IrisLightWash {
        anchors.fill: parent
        radius: Style.radiusL
        light: IrisStyle.accent
      }
      IrisReadingPlate {
        visible: !(modelData.contentItem?.materialReadingCards ?? false)
        anchors.fill: parent
        radius: Style.radiusL
        tint: IrisStyle.glassTint * Settings.data.ui.panelBackgroundOpacity
      }
    }
  }
}
