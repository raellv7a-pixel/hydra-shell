pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property var devices: []
  property bool loading: false
  property bool dependenciesChecked: false
  property var missingDependencies: []
  property bool lsblkAvailable: false
  property bool dfAvailable: false
  property bool udevadmAvailable: false
  property bool udisksctlAvailable: false
  property bool actionRunning: false
  property string lastError: ""

  readonly property int mountedCount: {
    var count = 0;
    for (var i = 0; i < devices.length; ++i) {
      if (devices[i].isMounted)
      ++count;
    }
    return count;
  }
  readonly property bool coreDependenciesAvailable: lsblkAvailable && udisksctlAvailable

  property var _knownPaths: ({})
  property bool _enumeratedOnce: false
  property var _actionQueue: []
  property var _currentAction: null
  property string _currentStage: ""
  property int _ejectUnmountIndex: 0
  property var _pendingLaunchCommand: []
  property string _pendingLaunchPrograms: ""

  Component.onCompleted: checkDependencies()

  function checkDependencies() {
    if (dependencyCheck.running)
      return;
    dependenciesChecked = false;
    dependencyCheck.running = true;
  }

  function refreshDevices() {
    if (!dependenciesChecked) {
      checkDependencies();
      return;
    }
    if (!lsblkAvailable) {
      loading = false;
      devices = [];
      lastError = I18n.tr("usb-drive-manager.errors.missing-lsblk");
      return;
    }
    if (deviceQuery.running)
      return;
    loading = true;
    lastError = "";
    deviceQuery.running = true;
  }

  function _parseDevices(blockDevices) {
    var result = [];

    function visit(device, parentPath, parentIsRemovable, parentModel, parentVendor) {
      var path = device.path || (device.name ? "/dev/" + device.name : "");
      var transport = String(device.tran || "").toLowerCase();
      var hotplug = device.hotplug === true || device.hotplug === 1 || device.hotplug === "1";
      var removable = device.rm === true || device.rm === 1 || device.rm === "1";
      var belongsToRemovable = parentIsRemovable || transport === "usb" || hotplug || removable;
      var diskPath = parentPath || path;
      var model = String(device.model || parentModel || "").trim();
      var vendor = String(device.vendor || parentVendor || "").trim();
      var children = device.children || [];

      for (var i = 0; i < children.length; ++i)
        visit(children[i], diskPath, belongsToRemovable, model, vendor);

      var fileSystem = String(device.fstype || "");
      if (!belongsToRemovable || !fileSystem || !path)
        return;

      var mountpoint = String(device.mountpoint || "");
      result.push({
                    "name": String(device.name || ""),
                    "path": path,
                    "parentPath": diskPath,
                    "label": String(device.label || device.name || ""),
                    "size": String(device.size || ""),
                    "fstype": fileSystem,
                    "mountpoint": mountpoint,
                    "isMounted": mountpoint.length > 0,
                    "model": model,
                    "vendor": vendor,
                    "usedPercent": 0,
                    "usedBytes": 0,
                    "freeBytes": 0
                  });
    }

    for (var i = 0; i < blockDevices.length; ++i)
      visit(blockDevices[i], "", false, "", "");
    return result;
  }

  function _requestUsage() {
    if (dfAvailable && !dfQuery.running)
      dfQuery.running = true;
  }

  function _applyUsage(text) {
    var usage = {};
    var lines = String(text).split("\n");
    for (var i = 1; i < lines.length; ++i) {
      var match = lines[i].match(/^(\S+)\s+(\d+)%\s+(\d+)\s+(\d+)\s+(.+)$/);
      if (!match)
        continue;
      var entry = {
        "percent": Number(match[2]) || 0,
        "used": Number(match[3]) || 0,
        "free": Number(match[4]) || 0
      };
      usage[match[1]] = entry;
      usage[match[5]] = entry;
    }

    var updated = [];
    for (var j = 0; j < devices.length; ++j) {
      var device = devices[j];
      var deviceUsage = usage[device.path] || usage[device.mountpoint];
      if (deviceUsage) {
        updated.push(Object.assign({}, device, {
                                     "usedPercent": deviceUsage.percent,
                                     "usedBytes": deviceUsage.used,
                                     "freeBytes": deviceUsage.free
                                   }));
      } else {
        updated.push(device);
      }
    }
    devices = updated;
  }

  function formatBytes(value) {
    var bytes = Number(value) || 0;
    if (bytes <= 0)
      return "";
    var units = ["B", "KiB", "MiB", "GiB", "TiB"];
    var index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
    var amount = bytes / Math.pow(1024, index);
    return (amount >= 10 || index === 0 ? amount.toFixed(0) : amount.toFixed(1)) + " " + units[index];
  }

  function _deviceByPath(path) {
    for (var i = 0; i < devices.length; ++i) {
      if (devices[i].path === path)
        return devices[i];
    }
    return null;
  }

  function mountDevice(path, label) {
    var device = _deviceByPath(path);
    if (!device || device.isMounted)
      return;
    _enqueueAction({
                     "type": "mount",
                     "path": path,
                     "label": label || device.label || path
                   });
  }

  function unmountDevice(path, label) {
    var device = _deviceByPath(path);
    if (!device || !device.isMounted)
      return;
    _enqueueAction({
                     "type": "unmount",
                     "path": path,
                     "label": label || device.label || path
                   });
  }

  function ejectDevice(path, parentPath, label) {
    var target = parentPath || path;
    var mountedPaths = [];
    for (var i = 0; i < devices.length; ++i) {
      var device = devices[i];
      if ((device.parentPath || device.path) === target && device.isMounted)
        mountedPaths.push(device.path);
    }
    _enqueueAction({
                     "type": "eject",
                     "path": path,
                     "parentPath": target,
                     "label": label || path,
                     "unmountPaths": mountedPaths
                   });
  }

  function unmountAll() {
    for (var i = 0; i < devices.length; ++i) {
      if (devices[i].isMounted)
        _enqueueAction({
                         "type": "unmount",
                         "path": devices[i].path,
                         "label": devices[i].label || devices[i].path
                       });
    }
  }

  function ejectAll() {
    var groups = {};
    for (var i = 0; i < devices.length; ++i) {
      var device = devices[i];
      var target = device.parentPath || device.path;
      if (!groups[target]) {
        groups[target] = {
          "type": "eject",
          "path": device.path,
          "parentPath": target,
          "label": device.model || device.label || target,
          "unmountPaths": []
        };
      }
      if (device.isMounted)
        groups[target].unmountPaths.push(device.path);
    }
    for (var parent in groups)
      _enqueueAction(groups[parent]);
  }

  function _enqueueAction(action) {
    if (!udisksctlAvailable) {
      ToastService.showError(I18n.tr("usb-drive-manager.errors.action-unavailable-title"), I18n.tr("usb-drive-manager.errors.missing-udisksctl"));
      return;
    }
    var queue = _actionQueue.slice();
    queue.push(action);
    _actionQueue = queue;
    _startNextAction();
  }

  function _startNextAction() {
    if (actionProcess.running || _currentAction || _actionQueue.length === 0)
      return;
    var queue = _actionQueue.slice();
    _currentAction = queue.shift();
    _actionQueue = queue;
    _ejectUnmountIndex = 0;
    actionRunning = true;
    _runCurrentAction();
  }

  function _runCurrentAction() {
    if (!_currentAction)
      return;
    if (_currentAction.type === "mount") {
      _currentStage = "mount";
      actionProcess.command = ["udisksctl", "mount", "-b", _currentAction.path];
    } else if (_currentAction.type === "unmount") {
      _currentStage = "unmount";
      actionProcess.command = ["udisksctl", "unmount", "-b", _currentAction.path];
    } else if (_ejectUnmountIndex < _currentAction.unmountPaths.length) {
      _currentStage = "eject-unmount";
      actionProcess.command = ["udisksctl", "unmount", "-b", _currentAction.unmountPaths[_ejectUnmountIndex]];
    } else {
      _currentStage = "eject-power-off";
      actionProcess.command = ["udisksctl", "power-off", "-b", _currentAction.parentPath];
    }
    actionProcess.running = true;
  }

  function _finishCurrentAction(succeeded, errorText) {
    var action = _currentAction;
    if (!action)
      return;
    if (succeeded) {
      if (Settings.data.usbDriveManager.showNotifications) {
        var key = action.type === "mount" ? "usb-drive-manager.notifications.mounted" : action.type === "unmount" ? "usb-drive-manager.notifications.unmounted" : "usb-drive-manager.notifications.ejected";
        ToastService.showNotice(I18n.tr(key), action.label);
      }
    } else {
      lastError = errorText;
      var errorKey = action.type === "mount" ? "usb-drive-manager.notifications.mount-failed" : action.type === "unmount" ? "usb-drive-manager.notifications.unmount-failed" : "usb-drive-manager.notifications.eject-failed";
      ToastService.showError(I18n.tr(errorKey), errorText || action.label);
    }
    _currentAction = null;
    _currentStage = "";
    actionRunning = _actionQueue.length > 0;
    refreshDelay.restart();
    Qt.callLater(_startNextAction);
  }

  function openInFileBrowser(mountpoint) {
    if (!mountpoint || launcherCheck.running)
      return;
    var browser = Settings.data.usbDriveManager.fileBrowser || "xdg-open";
    var terminal = Settings.data.usbDriveManager.terminal || "kitty";
    var terminalBrowsers = ["yazi", "ranger", "lf", "nnn"];
    var command = [];
    var programs = [];

    if (terminalBrowsers.indexOf(browser) !== -1) {
      programs = [terminal, browser];
      if (terminal === "wezterm")
        command = [terminal, "start", "--", browser, mountpoint];
      else if (terminal === "gnome-terminal" || terminal === "ptyxis")
        command = [terminal, "--", browser, mountpoint];
      else
        command = [terminal, "-e", browser, mountpoint];
    } else {
      programs = [browser];
      command = [browser, mountpoint];
    }

    _pendingLaunchCommand = command;
    _pendingLaunchPrograms = programs.join(", ");
    launcherCheck.command = ["sh", "-c", "for program in \"$@\"; do command -v -- \"$program\" >/dev/null || exit 1; done", "sh"].concat(programs);
    launcherCheck.running = true;
  }

  Process {
    id: dependencyCheck
    running: false
    command: ["sh", "-c", "for program in lsblk df udevadm udisksctl; do command -v -- \"$program\" >/dev/null || printf '%s\\n' \"$program\"; done"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      var missing = String(stdout.text).trim().split(/\s+/).filter(function (name) {
        return name.length > 0;
      });
      root.missingDependencies = missing;
      root.lsblkAvailable = missing.indexOf("lsblk") === -1;
      root.dfAvailable = missing.indexOf("df") === -1;
      root.udevadmAvailable = missing.indexOf("udevadm") === -1;
      root.udisksctlAvailable = missing.indexOf("udisksctl") === -1;
      root.dependenciesChecked = true;
      if (root.udevadmAvailable)
      deviceWatcher.running = true;
      fallbackRefresh.running = !root.udevadmAvailable;
      root.refreshDevices();
    }
  }

  Process {
    id: deviceWatcher
    running: false
    command: ["udevadm", "monitor", "--subsystem-match=block", "--property"]
    stdout: SplitParser {
      onRead: line => {
        if (line === "ACTION=add" || line === "ACTION=remove" || line === "ACTION=change")
        refreshDelay.restart();
      }
    }
    stderr: SplitParser {
      onRead: line => Logger.w("UsbDriveService", line)
    }
    onExited: exitCode => {
      if (root.udevadmAvailable)
      watcherRestart.restart();
    }
  }

  Process {
    id: deviceQuery
    running: false
    command: ["lsblk", "-J", "-o", "NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,HOTPLUG,TRAN,MODEL,VENDOR,RM,PATH"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      root.loading = false;
      if (exitCode !== 0) {
        root.lastError = String(stderr.text).trim() || I18n.tr("usb-drive-manager.errors.enumeration-failed");
        return;
      }
      try {
        var parsed = JSON.parse(String(stdout.text));
        var nextDevices = root._parseDevices(parsed.blockdevices || []);
        var nextKnown = {};
        var newDevices = [];
        for (var i = 0; i < nextDevices.length; ++i) {
          nextKnown[nextDevices[i].path] = true;
          if (root._enumeratedOnce && !root._knownPaths[nextDevices[i].path] && !nextDevices[i].isMounted)
          newDevices.push(nextDevices[i]);
        }
        root.devices = nextDevices;
        root._knownPaths = nextKnown;
        root._requestUsage();
        if (root._enumeratedOnce && Settings.data.usbDriveManager.autoMount) {
          for (var j = 0; j < newDevices.length; ++j)
          root.mountDevice(newDevices[j].path, newDevices[j].label);
        }
        root._enumeratedOnce = true;
      } catch (error) {
        root.lastError = I18n.tr("usb-drive-manager.errors.invalid-lsblk-data", {
                                   "error": String(error)
                                 });
        Logger.e("UsbDriveService", root.lastError);
      }
    }
  }

  Process {
    id: dfQuery
    running: false
    command: ["df", "-B1", "--output=source,pcent,used,avail,target"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0)
      root._applyUsage(stdout.text);
    }
  }

  Process {
    id: actionProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      var errorText = String(stderr.text).trim();
      if (exitCode !== 0) {
        root._finishCurrentAction(false, errorText);
        return;
      }
      if (root._currentAction && root._currentAction.type === "eject" && root._currentStage === "eject-unmount") {
        ++root._ejectUnmountIndex;
        root._runCurrentAction();
        return;
      }
      root._finishCurrentAction(true, "");
    }
  }

  Process {
    id: launcherCheck
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0)
      Quickshell.execDetached(root._pendingLaunchCommand);
      else
      ToastService.showError(I18n.tr("usb-drive-manager.errors.browser-unavailable-title"), I18n.tr("usb-drive-manager.errors.browser-unavailable", {
                                                                                                      "programs": root._pendingLaunchPrograms
                                                                                                    }));
      root._pendingLaunchCommand = [];
      root._pendingLaunchPrograms = "";
    }
  }

  Timer {
    id: refreshDelay
    interval: 900
    repeat: false
    onTriggered: root.refreshDevices()
  }

  Timer {
    id: watcherRestart
    interval: 3000
    repeat: false
    onTriggered: {
      if (root.udevadmAvailable && !deviceWatcher.running)
      deviceWatcher.running = true;
    }
  }

  Timer {
    id: fallbackRefresh
    interval: 8000
    repeat: true
    running: false
    onTriggered: root.refreshDevices()
  }
}
