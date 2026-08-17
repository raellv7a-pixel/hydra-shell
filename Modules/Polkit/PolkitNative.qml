import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Commons
import qs.Services.System
import qs.Services.UI

Item {
  id: root

  PolkitAgent {
    id: agent

    onIsActiveChanged: {
      var screen = PanelService.findScreenForPanels();
      var panel = PanelService.getPanel("polkitPanel", screen);
      if (panel) {
        panel.flow = agent.flow;
        if (agent.isActive && (PolkitService.enabled ?? true)) {
          panel.open();
        } else {
          panel.close();
        }
      }
    }
  }
}
