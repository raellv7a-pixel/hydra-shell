pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Reads raw keyboard events via `evtest` and renders them as a fading pill row
// on Modules/OSD/ShowKeysOsd.qml. Ported from the noctalia-legacy show-keys plugin.
//
// Security note: evtest reads /dev/input/eventN directly, bypassing the
// compositor's usual input isolation. Off by default; the user must opt in
// explicitly (IPC toggle or editing settings.json).
Singleton {
  id: root

  // ── Settings passthrough ─────────────────────────────
  readonly property bool captureEnabled: Settings.data.showKeys.captureEnabled
  readonly property string evtestDevice: Settings.data.showKeys.evtestDevice
  readonly property bool useCustomColors: Settings.data.showKeys.useCustomColors
  readonly property string position: Settings.data.showKeys.position
  readonly property int marginPx: Settings.data.showKeys.marginPx
  readonly property int hideDelaySec: Settings.data.showKeys.hideDelaySec
  readonly property var disabledScreens: Settings.data.showKeys.disabledScreens || []

  readonly property color pillColor: (useCustomColors && Settings.data.showKeys.pillColor) ? Settings.data.showKeys.pillColor : Color.mPrimary
  readonly property color pillBg: (useCustomColors && Settings.data.showKeys.pillBg) ? Settings.data.showKeys.pillBg : Color.mSurface

  // ── evtest binary detection ──────────────────────────
  property bool evtestAvailable: false
  property bool evtestChecked: false
  property bool osdVisible: false

  function init() {
    if (availabilityChecker.running || root.evtestChecked)
      return;
    Logger.i("ShowKeys", "Service started");
    availabilityChecker.running = true;
  }

  Process {
    id: availabilityChecker
    command: ["sh", "-c", "command -v evtest"]
    running: false

    onExited: exitCode => {
      root.evtestAvailable = (exitCode === 0);
      root.evtestChecked = true;
      if (!root.evtestAvailable) {
        Logger.w("ShowKeys", "Binário 'evtest' não encontrado no PATH — captura de teclas desativada. Instale com 'sudo pacman -S evtest'.");
        if (root.captureEnabled) {
          ToastService.showWarning("Show Keys", "Binário 'evtest' não encontrado. Instale com 'sudo pacman -S evtest'.");
        }
      } else {
        root.updateProcessState();
      }
    }
  }

  Component.onCompleted: root.init()

  IpcHandler {
    target: "showKeys"

    function toggle(): void {
      root.toggleCapture();
    }

    function enable(): void {
      root.setCaptureEnabled(true);
    }

    function disable(): void {
      root.setCaptureEnabled(false);
    }
  }

  // ── Toggle (used by IPC + future settings UI) ────────
  function toggleCapture() {
    setCaptureEnabled(!root.captureEnabled);
  }

  function setCaptureEnabled(enabled) {
    if (enabled && root.evtestChecked && !root.evtestAvailable) {
      Logger.w("ShowKeys", "Tentativa de ativar a captura sem o binário 'evtest' instalado.");
      ToastService.showWarning("Show Keys", "Instale 'evtest' (sudo pacman -S evtest) para usar este recurso.");
      return;
    }
    Settings.data.showKeys.captureEnabled = enabled;
    Logger.i("ShowKeys", "Capture " + (enabled ? "enabled" : "disabled"));
  }

  // ── evtest process (auto-restarted while captureEnabled) ──
  property int _restartAttempts: 0

  function updateProcessState() {
    const shouldRun = root.captureEnabled && root.evtestAvailable && root.evtestDevice.length > 0;
    if (shouldRun && !evtestProcess.running) {
      evtestProcess.command = ["evtest", root.evtestDevice];
      evtestProcess.running = true;
    } else if (!shouldRun && evtestProcess.running) {
      evtestProcess.running = false;
    }
  }

  onCaptureEnabledChanged: updateProcessState()
  onEvtestDeviceChanged: {
    if (evtestProcess.running) {
      evtestProcess.running = false;
    }
    restartTimer.restart();
  }

  Timer {
    id: restartTimer
    interval: 150
    onTriggered: root.updateProcessState()
  }

  Process {
    id: evtestProcess
    running: false

    stdout: SplitParser {
      onRead: line => root.handleLine(line)
    }

    onStarted: {
      root._restartAttempts = 0;
    }

    onExited: (exitCode, exitStatus) => {
      if (!root.captureEnabled || !root.evtestAvailable)
      return;

      root._restartAttempts++;
      if (root._restartAttempts > 5) {
        Logger.w("ShowKeys", "evtest falhou repetidamente para '" + root.evtestDevice + "' (exit " + exitCode + ") — verifique o caminho do dispositivo e permissões (grupo 'input' ou regra udev).");
        ToastService.showWarning("Show Keys", "Falha ao ler '" + root.evtestDevice + "'. Verifique o caminho e as permissões (grupo 'input').");
        return;
      }
      restartTimer.restart();
    }
  }

  // ── Key display state ────────────────────────────────
  property var keyList: []
  property bool shiftHeld: false
  property bool ctrlHeld: false
  property bool altHeld: false
  property bool metaHeld: false
  property bool capsLockOn: false
  property bool comboEmitted: false
  readonly property int maxKeys: 12

  readonly property string modPrefix: {
    var p = "";
    if (metaHeld)
    p += "󰴈 +";
    if (ctrlHeld)
    p += "CTRL+";
    if (altHeld)
    p += "ALT+";
    return p;
  }

  function emitDisplay(display) {
    let list = keyList.slice();
    if (list.length >= maxKeys)
      list = [];
    list.push(display);
    keyList = list;

    root.osdVisible = true;
    root.showOsd();
    hideTimer.restart();
  }

  // ── Event parsing (ported from show-keys plugin) ─────
  function handleLine(line) {
    if (line.indexOf("type 1 (EV_KEY)") === -1)
      return;

    var m = line.match(/\(KEY_([^)]+)\).*value (\d+)/);
    if (!m)
      return;

    var keycode = m[1];
    var value = parseInt(m[2]);
    if (value === 2)
      return; // ignore repeat

    var isMod = false;
    var modName = "";
    if (/SHIFT$/.test(keycode)) {
      isMod = true;
      modName = "SHIFT";
    } else if (/CTRL$/.test(keycode)) {
      isMod = true;
      modName = "CTRL";
    } else if (/ALT$/.test(keycode)) {
      isMod = true;
      modName = "ALT";
    } else if (/META$/.test(keycode)) {
      isMod = true;
      modName = "META";
    }

    if (value === 1) { // Press
      if (keycode === "CAPSLOCK")
        capsLockOn = !capsLockOn;

      if (isMod) {
        if (modName === "SHIFT")
          shiftHeld = true;
        if (modName === "CTRL")
          ctrlHeld = true;
        if (modName === "ALT")
          altHeld = true;
        if (modName === "META")
          metaHeld = true;
        comboEmitted = false;
      } else {
        comboEmitted = true;
      }
      return;
    }

    if (value === 0) { // Release
      if (isMod) {
        var emitStandalone = !comboEmitted;

        if (modName === "SHIFT")
          shiftHeld = false;
        if (modName === "CTRL")
          ctrlHeld = false;
        if (modName === "ALT")
          altHeld = false;
        if (modName === "META")
          metaHeld = false;

        if (emitStandalone) {
          var mLabel = "";
          if (modName === "SHIFT")
            mLabel = "SHIFT";
          if (modName === "CTRL")
            mLabel = "CTRL";
          if (modName === "ALT")
            mLabel = "ALT";
          if (modName === "META")
            mLabel = "󰴈";

          var mDisplay = modPrefix + mLabel;
          emitDisplay(mDisplay);
          comboEmitted = true;
        }
        return;
      }

      var label = keyLabel(keycode);
      if (label === "")
        return;

      var p = modPrefix;
      if (shiftHeld && !isShiftConsumed(keycode)) {
        p += "SHIFT+";
      }

      var keyDisplay = p + label;
      emitDisplay(keyDisplay);
    }
  }

  // Helper to determine if SHIFT is naturally consumed by the symbol map
  function isShiftConsumed(k) {
    if (!shiftHeld)
      return false;
    if (/^\d$/.test(k))
      return true;
    if (shiftMap[k] !== undefined)
      return true;
    if (/^[A-Z]$/.test(k))
      return false;
    return false;
  }

  // ── Key label (case-aware via CapsLock & ShiftMap) ───
  readonly property var shiftMap: ({
                                     "1": "!",
                                     "2": "@",
                                     "3": "#",
                                     "4": "$",
                                     "5": "%",
                                     "6": "^",
                                     "7": "&",
                                     "8": "*",
                                     "9": "(",
                                     "0": ")",
                                     "MINUS": "_",
                                     "EQUAL": "+",
                                     "LEFTBRACE": "{",
                                     "RIGHTBRACE": "}",
                                     "SEMICOLON": ":",
                                     "APOSTROPHE": "\"",
                                     "GRAVE": "~",
                                     "BACKSLASH": "|",
                                     "COMMA": "<",
                                     "DOT": ">",
                                     "SLASH": "?"
                                   })
  readonly property var normalMap: ({
                                      "MINUS": "-",
                                      "EQUAL": "=",
                                      "LEFTBRACE": "[",
                                      "RIGHTBRACE": "]",
                                      "SEMICOLON": ";",
                                      "APOSTROPHE": "'",
                                      "GRAVE": "`",
                                      "BACKSLASH": "\\",
                                      "COMMA": ",",
                                      "DOT": ".",
                                      "SLASH": "/"
                                    })

  readonly property var specialMap: ({
                                       "BACKSPACE": "󰁮",
                                       "ENTER": "󰌑",
                                       "ESC": "󱊷",
                                       "SPACE": "󱁐",
                                       "TAB": "󰌒",
                                       "DELETE": "󰆴",
                                       "UP": "↑",
                                       "DOWN": "↓",
                                       "LEFT": "←",
                                       "RIGHT": "→",
                                       "HOME": "Home",
                                       "END": "End",
                                       "PAGEUP": "PgUp",
                                       "PAGEDOWN": "PgDn",
                                       "INSERT": "Ins",
                                       "CAPSLOCK": "Caps",
                                       "NUMLOCK": "Num",
                                       "SCROLLLOCK": "Scr",
                                       "SYSRQ": "PrtSc",
                                       "PAUSE": "Pause"
                                     })

  function keyLabel(k) {
    if (specialMap[k] !== undefined)
      return specialMap[k];
    if (/^F\d+$/.test(k))
      return k;
    if (k.indexOf("KP") === 0)
      return k;

    if (/^[A-Z]$/.test(k)) {
      return root.capsLockOn !== root.shiftHeld ? k : k.toLowerCase();
    }

    if (shiftHeld) {
      if (shiftMap[k] !== undefined)
        return shiftMap[k];
    }

    if (/^\d$/.test(k))
      return k;
    if (normalMap[k] !== undefined)
      return normalMap[k];

    return k;
  }

  // ── OSD trigger signals (consumed by Modules/OSD/ShowKeysOsd.qml) ──
  signal showOsd
  signal hideOsd

  Timer {
    id: hideTimer
    interval: root.hideDelaySec * 1000
    onTriggered: {
      root.osdVisible = false;
      root.hideOsd();
      clearTimer.start();
    }
  }

  Timer {
    id: clearTimer
    interval: 250
    onTriggered: {
      root.keyList = [];
    }
  }
}
