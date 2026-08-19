import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  readonly property var activeScreen: screen
  readonly property var cfg: ControlCenterService.settings
  readonly property bool panelDetached: cfg.panelDetached ?? true
  readonly property string panelPosition: cfg.panelPosition ?? "center"
  readonly property bool followBarEdge: cfg.followBarEdge ?? true
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property string resolvedPanelPosition: (!panelDetached && followBarEdge) ? barPosition : panelPosition

  panelAnchorHorizontalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "top" || resolvedPanelPosition === "bottom"
  panelAnchorVerticalCenter: resolvedPanelPosition === "center" || resolvedPanelPosition === "left" || resolvedPanelPosition === "right"
  panelAnchorLeft: resolvedPanelPosition === "left"
  panelAnchorRight: resolvedPanelPosition === "right"
  panelAnchorBottom: resolvedPanelPosition === "bottom"
  panelAnchorTop: resolvedPanelPosition === "top"
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.30)

  preferredWidth: Math.round((cfg.panelWidth || 1120) * Style.uiScaleRatio * (cfg.panelScale || 1))
  preferredHeight: Math.round((cfg.panelHeight || 700) * Style.uiScaleRatio * (cfg.panelScale || 1))

  panelContent: Component {
    Panel {
      anchors.fill: parent
      pluginApi: ControlCenterService.provider
    }
  }
}
