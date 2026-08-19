import Hydra.Visual
import QtQuick
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
* Fundo da barra dentro do BlobGroup global.
*
* Barras simples/flutuantes usam BlobRect. A barra emoldurada usa
* BlobInvertedRect para representar a moldura e o recorte central sem manter
* uma segunda implementação baseada em ShapePath.
*/
Item {
  id: root

  required property var bar
  required property var windowRoot
  required property var blobGroup
  required property bool fullscreenActive

  readonly property bool shouldShow: {
    if (!BarService.effectivelyVisible)
      return false;
    const monitors = Settings.data.bar.monitors || [];
    const screenName = windowRoot?.screen?.name || "";
    return monitors.length === 0 || monitors.includes(screenName);
  }
  readonly property bool isFramed: Settings.data.bar.barType === "framed"
  readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
  readonly property real frameRadius: Settings.data.bar.frameRadius ?? Style.radiusPanel
  readonly property point barMappedPos: bar ? Qt.point(bar.x, bar.y) : Qt.point(0, 0)
  readonly property real barWidth: bar && shouldShow ? bar.width : 0
  readonly property real barHeight: bar && shouldShow ? bar.height : 0
  readonly property real screenWidth: windowRoot?.screen?.width || width
  readonly property real screenHeight: windowRoot?.screen?.height || height
  readonly property string barPosition: Settings.getBarPositionForScreen(windowRoot?.screen?.name)
  readonly property bool isRenderable: !!bar && shouldShow && (isFramed ? screenWidth > 0 && screenHeight > 0 : barWidth > 0 && barHeight > 0)
  readonly property real screenEdgeOvershoot: 2
  readonly property real topEdgeOvershoot: !isFramed && bar && bar.topLeftCornerState === -1 && bar.topRightCornerState === -1 && barMappedPos.y <= 0 ? -screenEdgeOvershoot : 0
  readonly property real bottomEdgeOvershoot: !isFramed && bar && bar.bottomLeftCornerState === -1 && bar.bottomRightCornerState === -1 && barMappedPos.y + barHeight >= screenHeight ? screenEdgeOvershoot : 0
  readonly property real leftEdgeOvershoot: !isFramed && bar && bar.topLeftCornerState === -1 && bar.bottomLeftCornerState === -1 && barMappedPos.x <= 0 ? -screenEdgeOvershoot : 0
  readonly property real rightEdgeOvershoot: !isFramed && bar && bar.topRightCornerState === -1 && bar.bottomRightCornerState === -1 && barMappedPos.x + barWidth >= screenWidth ? screenEdgeOvershoot : 0
  readonly property real opacityFactor: bar?.isHidden ? 0 : 1

  function cornerRadius(state) {
    return state === -1 ? 0 : Style.radiusPanel;
  }

  anchors.fill: parent
  opacity: opacityFactor

  Behavior on opacity {
    enabled: !!bar && bar.autoHide
    NAnim {
      duration: Style.motionDurationFastEffects
      motionType: NAnim.StandardEffects
    }
  }

  BlobRect {
    id: barRect

    group: root.isRenderable && !root.isFramed ? root.blobGroup : null
    visible: root.isRenderable && !root.isFramed
    x: root.barMappedPos.x + root.leftEdgeOvershoot
    y: root.barMappedPos.y + root.topEdgeOvershoot
    width: root.barWidth + root.rightEdgeOvershoot - root.leftEdgeOvershoot
    height: root.barHeight + root.bottomEdgeOvershoot - root.topEdgeOvershoot
    radius: Style.radiusPanel
    topLeftRadius: root.bar ? root.cornerRadius(root.bar.topLeftCornerState) : radius
    topRightRadius: root.bar ? root.cornerRadius(root.bar.topRightCornerState) : radius
    bottomLeftRadius: root.bar ? root.cornerRadius(root.bar.bottomLeftCornerState) : radius
    bottomRightRadius: root.bar ? root.cornerRadius(root.bar.bottomRightCornerState) : radius
    stiffness: 240
    damping: 20
    deformScale: Style.motionEnabled ? 0.00025 : 0
  }

  BlobInvertedRect {
    id: frameRect

    anchors.fill: parent
    anchors.margins: -50
    group: root.isRenderable && root.isFramed && !root.fullscreenActive ? root.blobGroup : null
    visible: root.isRenderable && root.isFramed && !root.fullscreenActive
    radius: root.frameRadius
    borderLeft: (root.barPosition === "left" ? root.barWidth : root.frameThickness) - anchors.margins
    borderRight: (root.barPosition === "right" ? root.barWidth : root.frameThickness) - anchors.margins
    borderTop: (root.barPosition === "top" ? root.barHeight : root.frameThickness) - anchors.margins
    borderBottom: (root.barPosition === "bottom" ? root.barHeight : root.frameThickness) - anchors.margins
  }
}
