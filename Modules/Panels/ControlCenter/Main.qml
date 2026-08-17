import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  IpcHandler {
    target: "plugin:raell-dashboard"

    function toggle() {
      if (!root.pluginApi) {
        Logger.w("RaellDashboard", "Cannot toggle: pluginApi is null");
        return;
      }

      root.pluginApi.withCurrentScreen(screen => {
        root.pluginApi.togglePanel(screen);
      });
    }
  }
}
