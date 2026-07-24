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

  // Translation dictionaries
  property var translations: ({})

  Component.onCompleted: {
    loadTranslations();
    loadSettings();
  }

  function loadTranslations() {
    var ptUrl = Quickshell.shellDir + "/Modules/Panels/ControlCenter/i18n/pt.json";
    var enUrl = Quickshell.shellDir + "/Modules/Panels/ControlCenter/i18n/en.json";
    
    try {
      var enData = Quickshell.readFile(enUrl.replace("file://", ""));
      if (enData) translations["en"] = JSON.parse(enData);
    } catch(e) {}

    try {
      var ptData = Quickshell.readFile(ptUrl.replace("file://", ""));
      if (ptData) translations["pt"] = JSON.parse(ptData);
    } catch(e) {}
  }

  function tr(key, interp) {
    if (!key) return "";
    var lang = (typeof I18n !== "undefined" && I18n.currentLanguage) ? I18n.currentLanguage : "pt";
    var dict = translations[lang] || translations["pt"] || translations["en"] || {};

    var parts = key.split(".");
    var curr = dict;
    for (var i = 0; i < parts.length; i++) {
      if (curr && typeof curr === "object" && parts[i] in curr) {
        curr = curr[parts[i]];
      } else {
        curr = null;
        break;
      }
    }

    if (typeof curr !== "string") {
      // Fallback to English
      dict = translations["en"] || {};
      curr = dict;
      for (var j = 0; j < parts.length; j++) {
        if (curr && typeof curr === "object" && parts[j] in curr) {
          curr = curr[parts[j]];
        } else {
          curr = key;
          break;
        }
      }
    }

    if (typeof curr !== "string") curr = key;

    if (interp && typeof interp === "object") {
      for (var k in interp) {
        curr = curr.replace("{" + k + "}", interp[k]);
      }
    }

    return curr;
  }

  function loadSettings() {
    try {
      var file = Settings.configDir + "control-center.json";
      var content = Quickshell.readFile(file);
      if (content) {
        var parsed = JSON.parse(content);
        if (parsed && typeof parsed === "object") {
          root.settings = Object.assign({}, root.settings, parsed);
        }
      }
    } catch(e) {
      Logger.d("ControlCenterService", "No saved settings found, using defaults");
    }
  }

  function saveSettings() {
    try {
      var file = Settings.configDir + "control-center.json";
      var dataStr = JSON.stringify(root.settings, null, 2);
      Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch(e) {
      Logger.e("ControlCenterService", "Failed to save settings:", e);
    }
  }

  // Backward-compatibility provider object replacing legacy pluginApi
  readonly property var provider: QtObject {
    property var mainInstance: root.mainInstance
    property var pluginSettings: root.settings
    property var manifest: ({ "name": "Control Center", "id": "control-center", "metadata": { "defaultSettings": root.settings } })
    property var panelOpenScreen: PanelService.findScreenForPanels()

    function tr(key, interp) {
      return root.tr(key, interp);
    }
    function saveSettings() {
      root.saveSettings();
    }
    function closePanel(screen) {
      if (screen) PanelService.closePanel(screen);
    }
    function openPanel(screen) {
      var sc = screen || PanelService.findScreenForPanels();
      if (sc) {
        var p = PanelService.getPanel("controlCenterPanel", sc);
        if (p) p.open();
      }
    }
    function togglePanel(screen) {
      var sc = screen || PanelService.findScreenForPanels();
      if (sc) {
        var p = PanelService.getPanel("controlCenterPanel", sc);
        if (p) p.toggle();
      }
    }
    function withCurrentScreen(cb) {
      var sc = PanelService.findScreenForPanels();
      if (sc && cb) cb(sc);
    }
  }

  // Convenience toggle for IPC and keybindings
  function toggle() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p) p.toggle();
    }
  }

  function open() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p) p.open();
    }
  }

  function close() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("controlCenterPanel", sc);
      if (p) p.close();
    }
  }
}
