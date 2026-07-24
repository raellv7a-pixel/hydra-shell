pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var mainInstance: null

  // Native Settings data store for ScreenToolkit
  property var settings: ({
                            "screenshotPath": "",
                            "videoPath": "",
                            "filenameFormat": "",
                            "x02ApiKey": "",
                            "x02Expiry": "7d",
                            "shareSkipPopover": false,
                            "recordSkipConfirmation": false,
                            "recordCopyToClipboard": false,
                            "gifMaxSeconds": 30,
                            "searchEngineUrl": "",
                            "selectedOcrLang": "eng",
                            "installedLangs": ["eng"],
                            "transAvailable": false,
                            "detectedRecorder": "",
                            "resultHex": "",
                            "resultRgb": "",
                            "resultHsv": "",
                            "resultHsl": "",
                            "colorCapturePath": "",
                            "colorCacheBust": 0,
                            "colorHistory": [],
                            "ocrResult": "",
                            "ocrCapturePath": "",
                            "translateResult": "",
                            "qrResult": "",
                            "qrCapturePath": "",
                            "paletteColors": []
                          })

  // Translation dictionaries
  property var translations: ({})

  Component.onCompleted: {
    loadTranslations();
    loadSettings();
  }

  function loadTranslations() {
    var ptUrl = Quickshell.shellDir + "/Modules/ScreenToolkit/i18n/pt.json";
    var enUrl = Quickshell.shellDir + "/Modules/ScreenToolkit/i18n/en.json";
    
    // Load en fallback first, then pt if available
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
      var file = Settings.configDir + "screen-toolkit.json";
      var content = Quickshell.readFile(file);
      if (content) {
        var parsed = JSON.parse(content);
        if (parsed && typeof parsed === "object") {
          root.settings = Object.assign({}, root.settings, parsed);
        }
      }
    } catch(e) {
      Logger.d("ScreenToolkitService", "No saved settings found, using defaults");
    }
  }

  function saveSettings() {
    try {
      var file = Settings.configDir + "screen-toolkit.json";
      var dataStr = JSON.stringify(root.settings, null, 2);
      Quickshell.execDetached(["bash", "-c", "cat << 'EOF' > " + file + "\n" + dataStr + "\nEOF"]);
    } catch(e) {
      Logger.e("ScreenToolkitService", "Failed to save settings:", e);
    }
  }

  // Backward-compatibility provider object replacing legacy pluginApi
  readonly property var provider: QtObject {
    property var mainInstance: root.mainInstance
    property var pluginSettings: root.settings
    property var manifest: ({ "name": "Screen Toolkit", "id": "screen-toolkit" })

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
        var p = PanelService.getPanel("screenToolkitPanel", sc);
        if (p) p.open();
      }
    }
    function togglePanel(screen) {
      var sc = screen || PanelService.findScreenForPanels();
      if (sc) {
        var p = PanelService.getPanel("screenToolkitPanel", sc);
        if (p) p.toggle();
      }
    }
    function withCurrentScreen(cb) {
      var sc = PanelService.findScreenForPanels();
      if (sc && cb) cb(sc);
    }
  }

  // Service helper actions for IPC and Keybindings
  function toggle() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("screenToolkitPanel", sc);
      if (p) p.toggle();
    }
  }

  function colorPicker() {
    if (mainInstance && typeof mainInstance.runColorPicker === "function") {
      mainInstance.runColorPicker();
    }
  }

  function ocr(lang) {
    if (mainInstance && typeof mainInstance.runOcr === "function") {
      mainInstance.runOcr(lang || root.settings.selectedOcrLang || "eng");
    }
  }

  function qr() {
    if (mainInstance && typeof mainInstance.runQr === "function") {
      mainInstance.runQr();
    }
  }

  function palette() {
    if (mainInstance && typeof mainInstance.runPalette === "function") {
      mainInstance.runPalette();
    }
  }

  function lens() {
    if (mainInstance && typeof mainInstance.runLens === "function") {
      mainInstance.runLens();
    }
  }

  function annotate() {
    if (mainInstance && typeof mainInstance.runAnnotate === "function") {
      mainInstance.runAnnotate();
    }
  }

  function annotateFullscreen() {
    if (mainInstance && typeof mainInstance.runAnnotateFullscreen === "function") {
      mainInstance.runAnnotateFullscreen();
    }
  }

  function annotateWindow() {
    if (mainInstance && typeof mainInstance.runAnnotateActiveWindow === "function") {
      mainInstance.runAnnotateActiveWindow();
    }
  }

  function pin() {
    if (mainInstance && typeof mainInstance.runPin === "function") {
      mainInstance.runPin();
    }
  }

  function pinImage() {
    if (mainInstance && typeof mainInstance.runPinFromFile === "function") {
      mainInstance.runPinFromFile();
    }
  }

  function measure() {
    if (mainInstance && typeof mainInstance.runMeasure === "function") {
      mainInstance.runMeasure();
    }
  }

  function record(format) {
    if (mainInstance && typeof mainInstance.runRecord === "function") {
      mainInstance.runRecord(format || "gif");
    }
  }

  function recordMp4() {
    record("mp4");
  }

  function recordFullscreen(format) {
    if (mainInstance && typeof mainInstance.runRecordFullscreen === "function") {
      mainInstance.runRecordFullscreen(format || "gif");
    }
  }

  function recordFullscreenMp4() {
    recordFullscreen("mp4");
  }

  function recordStop() {
    if (mainInstance && typeof mainInstance.runRecordStop === "function") {
      mainInstance.runRecordStop();
    }
  }

  function mirror() {
    if (mainInstance && typeof mainInstance.runMirror === "function") {
      mainInstance.runMirror();
    }
  }
}
