pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property var settings: ({
                            "enabled": true,
                            "position": "center", // "center" or "attached"
                            "errorShake": true,
                            "autoFocus": true
                          })

  FileView {
    id: settingsFileView
    path: Settings.directoriesCreated ? (Settings.configDir + "security.json") : undefined
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text());
        if (parsed && typeof parsed === "object") {
          root.settings = Object.assign({}, root.settings, parsed);
        }
      } catch(e) {}
    }
  }

  function saveSettings() {
    try {
      var file = Settings.configDir + "security.json";
      var dataStr = JSON.stringify(root.settings, null, 2);
      Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch(e) {
      Logger.e("PolkitService", "Failed to save security settings:", e);
    }
  }
}
