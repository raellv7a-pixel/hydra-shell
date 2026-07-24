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

  FileView {
    id: ptFileView
    path: Quickshell.shellDir + "/Modules/ScreenToolkit/i18n/pt.json"
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text());
        root.translations["pt"] = data;
        Logger.d("ScreenToolkitService", "Loaded PT translations");
      } catch(e) {
        Logger.e("ScreenToolkitService", "Failed to parse PT translations:", e);
      }
    }
  }

  FileView {
    id: enFileView
    path: Quickshell.shellDir + "/Modules/ScreenToolkit/i18n/en.json"
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text());
        root.translations["en"] = data;
        Logger.d("ScreenToolkitService", "Loaded EN translations");
      } catch(e) {
        Logger.e("ScreenToolkitService", "Failed to parse EN translations:", e);
      }
    }
  }

  FileView {
    id: settingsFileView
    path: Settings.directoriesCreated ? (Settings.configDir + "screen-toolkit.json") : undefined
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

  function tr(key, interp) {
    if (!key) return "";
    var lang = (typeof I18n !== "undefined" && I18n.langCode) ? I18n.langCode : "pt";
    var dict = root.translations[lang] || root.translations["pt"] || root.translations["en"] || {};

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
      dict = root.translations["en"] || root.translations["pt"] || {};
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
