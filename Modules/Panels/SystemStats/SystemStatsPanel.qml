pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI

SmartPanel {
  id: root
  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(780 * Style.uiScaleRatio)
  panelBackgroundColor: HydraColor.mSurface
  panelBorderColor: "transparent"
  forceAttachToBar: isFramed

  panelContent: Item {
    readonly property real contentPreferredHeight: Math.round(780 * Style.uiScaleRatio)
    readonly property string diskPath: {
      const widget = BarService.lookupWidget("SystemMonitor");
      return widget?.diskPath || "/";
    }
    StatsDashboard {
      anchors.fill: parent
      anchors.margins: Style.marginL
      active: root.isPanelOpen
      componentId: "panel-systemstats-" + (root.screen?.name || "default")
      diskPath: parent.diskPath
      onCloseRequested: root.close()
    }
  }
}
