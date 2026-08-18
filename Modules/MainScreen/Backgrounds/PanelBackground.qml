import Hydra.Visual
import QtQuick
import qs.Commons

/**
* BlobRect dinâmico para um slot do PanelService.
*
* A geometria continua pertencendo ao SmartPanel; este item apenas projeta a
* região no BlobGroup compartilhado e expõe a matriz física usada pelo conteúdo.
*/
BlobRect {
  id: root

  property var assignedPanel: null
  property color defaultBackgroundColor: Color.mSurfaceContainer

  readonly property var panelRegion: assignedPanel?.panelRegion ?? null
  readonly property var panelBg: panelRegion?.visible ? panelRegion.panelItem : null
  readonly property real panelX: panelBg?.x ?? 0
  readonly property real panelY: panelBg?.y ?? 0
  readonly property real panelWidth: panelBg?.width ?? 0
  readonly property real panelHeight: panelBg?.height ?? 0
  readonly property bool isRenderable: !!assignedPanel && !!panelBg && panelWidth > 0 && panelHeight > 0
  readonly property bool shouldFlatten: isRenderable && (panelWidth < radius * 2 || panelHeight < radius * 2)
  readonly property real effectiveRadius: shouldFlatten ? Math.max(0, Math.min(panelWidth, panelHeight) / 2) : radius

  function cornerRadius(state) {
    return state === -1 ? 0 : effectiveRadius;
  }

  x: isRenderable ? panelX : -1
  y: isRenderable ? panelY : -1
  width: isRenderable ? panelWidth : 0
  height: isRenderable ? panelHeight : 0
  visible: isRenderable
  opacity: assignedPanel ? Math.max(0, Math.min(1, 1 - assignedPanel.offsetScale)) : 0

  radius: Style.radiusPanel
  topLeftRadius: panelBg ? cornerRadius(panelBg.topLeftCornerState) : radius
  topRightRadius: panelBg ? cornerRadius(panelBg.topRightCornerState) : radius
  bottomLeftRadius: panelBg ? cornerRadius(panelBg.bottomLeftCornerState) : radius
  bottomRightRadius: panelBg ? cornerRadius(panelBg.bottomRightCornerState) : radius

  stiffness: 220
  damping: 18
  deformScale: Style.motionEnabled ? 0.00045 : 0
}
