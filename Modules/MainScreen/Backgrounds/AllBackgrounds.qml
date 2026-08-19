import Hydra.Visual
import QtQuick
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
* Superfície SDF global para barra, painéis e modais.
*
* Todos os slots ativos compartilham um BlobGroup por camada de opacidade. Isso
* permite fusão contínua entre superfícies e mantém o contrato de slots do
* PanelService: abertura, fechamento e modal coexistem durante as transições.
*/
Item {
  id: root

  required property var bar
  required property var windowRoot
  required property bool fullscreenActive

  readonly property color panelBackgroundColor: Color.mSurfaceContainer
  readonly property real blobSmoothing: Style.radiusPanel
  readonly property bool hasPanelSurface: !!(panelForSlot(0) || panelForSlot(1) || panelForSlot(2))

  function panelForSlot(index) {
    const panel = PanelService.backgroundSlotAssignments[index];
    return panel?.screen === root.windowRoot.screen ? panel : null;
  }

  function blobForPanel(panel) {
    const candidates = Settings.data.bar.useSeparateOpacity ? [separatePanel0, separatePanel1, separatePanel2] : [unifiedPanel0, unifiedPanel1, unifiedPanel2];
    for (let i = 0; i < candidates.length; ++i) {
      if (candidates[i].assignedPanel === panel)
        return candidates[i];
    }
    return null;
  }

  anchors.fill: parent

  Item {
    id: unifiedLayer

    anchors.fill: parent
    visible: !Settings.data.bar.useSeparateOpacity
    opacity: Style.effectivePanelOpacity
    layer.enabled: visible

    BlobGroup {
      id: unifiedGroup

      color: root.panelBackgroundColor
      smoothing: root.blobSmoothing
      cornerFill: true
    }

    BarBackground {
      anchors.fill: parent
      bar: root.bar
      windowRoot: root.windowRoot
      blobGroup: unifiedGroup
      fullscreenActive: root.fullscreenActive
    }

    PanelBackground {
      id: unifiedPanel0

      assignedPanel: root.panelForSlot(0)
      group: unifiedLayer.visible ? unifiedGroup : null
    }

    PanelBackground {
      id: unifiedPanel1

      assignedPanel: root.panelForSlot(1)
      group: unifiedLayer.visible ? unifiedGroup : null
    }

    PanelBackground {
      id: unifiedPanel2

      assignedPanel: root.panelForSlot(2)
      group: unifiedLayer.visible ? unifiedGroup : null
    }
  }

  NDropShadow {
    anchors.fill: unifiedLayer
    source: unifiedLayer
    active: unifiedLayer.visible && (!root.fullscreenActive || root.hasPanelSurface)
  }

  Item {
    id: separatePanelLayer

    anchors.fill: parent
    visible: Settings.data.bar.useSeparateOpacity
    opacity: Style.effectivePanelOpacity
    layer.enabled: visible

    BlobGroup {
      id: separatePanelGroup

      color: root.panelBackgroundColor
      smoothing: root.blobSmoothing
      cornerFill: true
    }

    PanelBackground {
      id: separatePanel0

      assignedPanel: root.panelForSlot(0)
      group: separatePanelLayer.visible ? separatePanelGroup : null
    }

    PanelBackground {
      id: separatePanel1

      assignedPanel: root.panelForSlot(1)
      group: separatePanelLayer.visible ? separatePanelGroup : null
    }

    PanelBackground {
      id: separatePanel2

      assignedPanel: root.panelForSlot(2)
      group: separatePanelLayer.visible ? separatePanelGroup : null
    }
  }

  NDropShadow {
    anchors.fill: separatePanelLayer
    source: separatePanelLayer
    active: separatePanelLayer.visible && root.hasPanelSurface
  }

  Item {
    id: separateBarLayer

    anchors.fill: parent
    visible: Settings.data.bar.useSeparateOpacity
    opacity: Style.effectiveBarOpacity
    layer.enabled: visible

    BlobGroup {
      id: separateBarGroup

      color: root.panelBackgroundColor
      smoothing: root.blobSmoothing
      cornerFill: true
    }

    BarBackground {
      anchors.fill: parent
      bar: root.bar
      windowRoot: root.windowRoot
      blobGroup: separateBarGroup
      fullscreenActive: root.fullscreenActive
    }
  }

  NDropShadow {
    anchors.fill: separateBarLayer
    source: separateBarLayer
    active: separateBarLayer.visible && !root.fullscreenActive
  }
}
