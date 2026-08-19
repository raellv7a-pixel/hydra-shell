pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var mainInstance: null

  // Native Settings data store for Raell Dashboard / Control Center
  property var settings: ({
                            "avatarPath": "",
                            "panelDetached": true,
                            "panelPosition": "center",
                            "followBarEdge": true,
                            "panelWidth": 1120,
                            "panelHeight": 700,
                            "panelScale": 1,
                            "mediaVisualizerEffect": "bars",
                            "audioSliderEffect": "wave",
                            "microphoneSliderEffect": "pulse",
                            "avatarMusicEffect": "ring",
                            "followNoctaliaPerformanceMode": true,
                            "powerSaverPerformanceMode": true,
                            "avatarShape": "circle",
                            "profileCardShape": "rounded",
                            "profileDanceGifPath": "",
                            "showProfileDanceGif": true,
                            "showProfileWallpaper": true,
                            "profileCoverMode": "auto",
                            "profileCoverPath": "",
                            "profileCoverFolder": "",
                            "profileCoverOverlayEnabled": true,
                            "profileCoverOverlay": 0.58,
                            "profileCoverBlurEnabled": false,
                            "profileCoverBlur": 0,
                            "profileCoverBorder": true,
                            "profileCoverBorderWidth": 2,
                            "profileCoverBorderEffect": "primary",
                            "profileCoverBorderColorMode": "auto",
                            "profileCoverBorderAnimation": "static",
                            "profileCoverBorderSpeed": 1,
                            "profileCoverBorderColorCount": 3,
                            "profileCoverBorderColor1": "#fff59b",
                            "profileCoverBorderColor2": "#8bd5ff",
                            "profileCoverBorderColor3": "#cba6f7",
                            "profileCoverBorderColor4": "#f38ba8",
                            "profileCoverBorderColor5": "#a6e3a1",
                            "componentStyles": {},
                            "showBarMediaInfo": true,
                            "barMediaShowWhenPaused": false,
                            "barMediaShowAlbumArt": true,
                            "barMediaShowVisualizer": true,
                            "barMediaVisualizerType": "linear",
                            "barMediaShowProgressRing": true,
                            "barMediaShowArtistFirst": true,
                            "barMediaScrollingMode": "hover",
                            "barMediaLayout": "auto",
                            "barMediaMaxWidth": 170,
                            "barMediaUseFixedWidth": false,
                            "barMediaTextColor": "none",
                            "showNotifications": true,
                            "showMedia": true,
                            "showCalendar": true,
                            "showRecordingCard": true,
                            "iconName": "layout-dashboard"
                          })

  FileView {
    id: settingsFileView
    path: Settings.directoriesCreated ? (Settings.configDir + "control-center.json") : undefined
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text());
        if (parsed && typeof parsed === "object") {
          root.settings = Object.assign({}, root.settings, parsed);
        }
      } catch (e) {}
    }
  }

  function saveSettings() {
    try {
      var file = Settings.configDir + "control-center.json";
      var dataStr = JSON.stringify(root.settings, null, 2);
      Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch (e) {
      Logger.e("ControlCenterService", "Failed to save settings:", e);
    }
  }

  // Convenience toggle for IPC and keybindings
  function toggle() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p)
        p.toggle();
    }
  }

  function open() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p)
        p.open();
    }
  }

  function close() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p)
        p.close();
    }
  }
}
