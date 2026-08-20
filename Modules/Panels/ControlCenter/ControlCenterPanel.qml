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

  // Single source of truth for placement. "close_to_bar_button" deliberately
  // leaves every anchor false: SmartPanel then falls back to its button
  // position / bar-edge attachment path, which requires
  // hasExplicitHorizontalAnchor and hasExplicitVerticalAnchor to stay false.
  readonly property string placement: Settings.data.controlCenter.position

  panelAnchorTop: placement === "top_center" || placement === "top_left" || placement === "top_right"
  panelAnchorBottom: placement === "bottom_center" || placement === "bottom_left" || placement === "bottom_right"
  panelAnchorLeft: placement === "top_left" || placement === "center_left" || placement === "bottom_left"
  panelAnchorRight: placement === "top_right" || placement === "center_right" || placement === "bottom_right"
  panelAnchorHorizontalCenter: placement === "center" || placement === "top_center" || placement === "bottom_center"
  panelAnchorVerticalCenter: placement === "center" || placement === "center_left" || placement === "center_right"

  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.30)

  preferredWidth: Math.round(Settings.data.controlCenter.panelWidth * Style.uiScaleRatio * Settings.data.controlCenter.panelScale)
  preferredHeight: Math.round(Settings.data.controlCenter.panelHeight * Style.uiScaleRatio * Settings.data.controlCenter.panelScale)

  panelContent: Component {
    Panel {
      anchors.fill: parent
    }
  }
}
