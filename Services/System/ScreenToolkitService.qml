pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var mainInstance: null
  readonly property string recordState: mainInstance?.recordState ?? ""
  readonly property string recordFormat: mainInstance?.recordFormat ?? "gif"
  readonly property int recordElapsedSeconds: mainInstance?.recordElapsedSeconds ?? 0
  readonly property string recordPath: mainInstance?.recordPath ?? ""
  readonly property string recordError: mainInstance?.recordError ?? ""
  readonly property bool recordSaved: mainInstance?.recordSaved ?? false
  property string _pendingAction: ""
  property string _pendingArgument: ""
  property var _pendingScreen: null

  Timer {
    id: dashboardLaunchDelay
    interval: 300
    repeat: false
    onTriggered: {
      var action = root._pendingAction;
      var argument = root._pendingArgument;
      var screen = root._pendingScreen;
      root._pendingAction = "";
      root._pendingArgument = "";
      root._pendingScreen = null;
      var toolkit = root.mainInstance;
      if (action === "screenshot") {
        screenshotProc.exec({
                              command: ["bash", Quickshell.shellDir + "/Modules/Panels/ControlCenter/scripts/screenshot.sh", argument || "region", screen?.name ?? ""]
                            });
        return;
      }
      if (!toolkit) {
        ToastService.showError(root.tr("record.failed"));
        return;
      }
      switch (action) {
      case "colorPicker": toolkit.runColorPicker(screen); break;
      case "palette": toolkit.runPalette(screen); break;
      case "ocr": toolkit.runOcr(argument || root.settings.selectedOcrLang || "eng", screen); break;
      case "qr": toolkit.runQr(screen); break;
      case "lens": toolkit.runLens(screen); break;
      case "annotateFullscreen": toolkit.runAnnotateFullscreen(screen); break;
      case "measure": toolkit.runMeasure(); break;
      case "pin": toolkit.runPin(screen); break;
      case "mirror": toolkit.runMirror(screen); break;
      case "record": toolkit.runRecord(argument === "mp4" ? "mp4" : "gif", false, false, false, screen, true); break;
      default: Logger.w("ScreenToolkitService", "Unknown dashboard capture action: " + action);
      }
    }
  }
  Process {
    id: screenshotProc
    onExited: code => {
      if (code !== 0)
        ToastService.showError(root.tr("messages.capture-failed"));
    }
  }

  function launchFromDashboard(action, argument) {
    if (root._pendingAction !== "" || screenshotProc.running || root.mainInstance?.isRunning || !action)
      return;
    if (root.recordState === "selecting" || root.recordState === "recording" || root.recordState === "converting")
      return;
    var dashboard = PanelService.openedPanel;
    var screen = dashboard?.screen ?? PanelService.findScreenForPanels();
    root._pendingScreen = screen;
    root._pendingAction = action;
    root._pendingArgument = argument || "";
    if (dashboard?.objectName?.startsWith("controlCenterPanel") && dashboard.isPanelOpen)
      dashboard.closeImmediately();
    dashboardLaunchDelay.start();
  }

  function stopRecording() {
    root.mainInstance?.runRecordStop();
  }
  function saveRecording() {
    root.mainInstance?.runRecordSave();
  }

  function discardRecording() {
    root.mainInstance?.runRecordDiscard();
  }

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
        var updated = Object.assign({}, root.translations);
        updated["pt"] = data;
        root.translations = updated;
        Logger.d("ScreenToolkitService", "Loaded PT translations");
      } catch (e) {
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
        var updated = Object.assign({}, root.translations);
        updated["en"] = data;
        root.translations = updated;
        Logger.d("ScreenToolkitService", "Loaded EN translations");
      } catch (e) {
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
      } catch (e) {}
    }
  }

  function tr(key, interp) {
    if (!key)
      return "";
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

    if (typeof curr !== "string")
      curr = key;

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
    } catch (e) {
      Logger.e("ScreenToolkitService", "Failed to save settings:", e);
    }
  }

  // Backward-compatibility provider object replacing legacy pluginApi
  readonly property var provider: QtObject {
    property var mainInstance: root.mainInstance
    property var pluginSettings: root.settings
    property var manifest: ({
                              "name": "Screen Toolkit",
                              "id": "screen-toolkit"
                            })

    function tr(key, interp) {
      return root.tr(key, interp);
    }
    function saveSettings() {
      root.saveSettings();
    }
    function closePanel(screen) {
      if (screen)
        PanelService.closePanel(screen);
    }
    function openPanel(screen) {
      var sc = screen || PanelService.findScreenForPanels();
      if (sc) {
        var p = PanelService.getPanel("screenToolkitPanel", sc);
        if (p)
          p.open();
      }
    }
    function togglePanel(screen) {
      var sc = screen || PanelService.findScreenForPanels();
      if (sc) {
        var p = PanelService.getPanel("screenToolkitPanel", sc);
        if (p)
          p.toggle();
      }
    }
    function withCurrentScreen(cb) {
      var sc = PanelService.findScreenForPanels();
      if (sc && cb)
        cb(sc);
    }
  }

  // Service helper actions for IPC and Keybindings
  function toggle() {
    var sc = PanelService.findScreenForPanels();
    if (sc) {
      var p = PanelService.getPanel("screenToolkitPanel", sc);
      if (p)
        p.toggle();
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
