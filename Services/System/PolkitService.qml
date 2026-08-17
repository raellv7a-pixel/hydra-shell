pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property bool enabled: true
  property string position: "center" // "center" or "attached"
  property bool errorShake: true
  property bool autoFocus: true

  readonly property var settings: ({
    "enabled": root.enabled,
    "position": root.position,
    "errorShake": root.errorShake,
    "autoFocus": root.autoFocus
  })

  FileView {
    id: settingsFileView
    path: Settings.directoriesCreated ? (Settings.configDir + "security.json") : undefined
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text());
        if (parsed && typeof parsed === "object") {
          if (parsed.enabled !== undefined) root.enabled = parsed.enabled;
          if (parsed.position !== undefined) root.position = parsed.position;
          if (parsed.errorShake !== undefined) root.errorShake = parsed.errorShake;
          if (parsed.autoFocus !== undefined) root.autoFocus = parsed.autoFocus;
        }
      } catch(e) {}
    }
  }

  function saveSettings() {
    try {
      var file = Settings.configDir + "security.json";
      var dataStr = JSON.stringify({
        "enabled": root.enabled,
        "position": root.position,
        "errorShake": root.errorShake,
        "autoFocus": root.autoFocus
      }, null, 2);
      Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch(e) {
      Logger.e("PolkitService", "Failed to save security settings:", e);
    }
  }

  onEnabledChanged: saveSettings()
  onPositionChanged: saveSettings()
  onErrorShakeChanged: saveSettings()
  onAutoFocusChanged: saveSettings()
}
