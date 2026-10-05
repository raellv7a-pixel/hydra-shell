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

  // Framed placement is canonical; saved positioning remains available outside it.
  readonly property string placement: isFramed ? "top_center" : Settings.data.controlCenter.position
  forceAttachToBar: isFramed
  allowButtonPosition: !isFramed

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

  property string requestedQuickAction: "main"
  property string requestedDetail: ""

  function showView(view, anchor) {
    requestedQuickAction = view === "network" || view === "bluetooth" ? view : "main";
    requestedDetail = view === "audio" ? "audio" : "";
    if (isPanelOpen) {
      if (contentItem) {
        contentItem.quickActionsPage = requestedQuickAction;
        contentItem.activeDetailView = requestedDetail;
      }
    } else {
      open(anchor);
    }
  }

  onClosed: {
    requestedQuickAction = "main";
    requestedDetail = "";
  }

  panelContent: Component {
    Panel {
      anchors.fill: parent
      frameAttached: root.isFramed
      quickActionsPage: root.requestedQuickAction
      activeDetailView: root.requestedDetail
    }
  }
}
