pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Package reads and writes outlive Launcher delegates. A single scanner/cache is
// shared by every screen; a mutation cancels/reaps the scanner before starting.
Singleton {
  id: root

  readonly property string privilegeElevator: Quickshell.shellDir + "/Scripts/bash/polkit-elevate.sh"
  readonly property string metadataHelper: Quickshell.shellDir + "/Scripts/python/launcher_packages.py"
  readonly property string cacheFile: Settings.cacheDir + "shelly-updates.json"
  readonly property int cacheTtlMs: 30 * 60 * 1000
  readonly property bool scanRunning: metadataProcess.running
  property bool metadataReady: false
  property bool available: false
  property var updateRecords: []
  property var installedPackages: ({
                                     "native": {},
                                     "flatpak": {},
                                     "appimages": []
                                   })
  property real lastScanTimestamp: 0
  property int metadataRevision: 0
  property string scanError: ""
  property bool scanCancelled: false
  property bool refreshRequested: false

  property bool busy: false
  property string operationAppId: ""
  property string operationState: "idle" // idle | waiting | update | remove
  property string operationName: ""
  property string lastError: ""
  property var pendingOperation: null

  signal operationFinished(string appId, string operation, bool success)

  Component.onCompleted: {
    metadataProcess.command = ["python3", metadataHelper, "bootstrap", cacheFile];
    metadataProcess.running = true;
  }

  function refresh(force) {
    if (!metadataReady || busy || metadataProcess.running) {
      refreshRequested = refreshRequested || !!force;
      return;
    }
    if (!force && Date.now() - lastScanTimestamp < cacheTtlMs)
      return;
    refreshRequested = false;
    scanError = "";
    metadataProcess.command = ["python3", metadataHelper, "scan", cacheFile];
    metadataProcess.running = true;
    metadataRevision++;
  }

  Timer {
    id: refreshTimer
    interval: root.cacheTtlMs
    repeat: false
    onTriggered: root.refresh(true)
  }

  Process {
    id: metadataProcess
    stdout: StdioCollector {
      id: metadataOut
    }
    stderr: StdioCollector {
      id: metadataErr
    }
    onExited: code => {
      root.metadataReady = true;
      if (root.scanCancelled) {
        root.scanCancelled = false;
        root.beginOperation();
        return;
      }
      if (code === 0) {
        try {
          const data = JSON.parse(metadataOut.text);
          root.available = data.available;
          root.updateRecords = data.updates;
          root.installedPackages = data.installed;
          root.lastScanTimestamp = data.timestamp * 1000;
          root.scanError = "";
        } catch (error) {
          root.scanError = String(error);
        }
      } else {
        root.scanError = String(metadataErr.text || I18n.tr("launcher.app-actions.operation-failed")).trim();
      }
      root.metadataRevision++;
      // Bootstrap may publish an expired cache immediately, then refresh once.
      if (code === 0 && (root.refreshRequested || Date.now() - root.lastScanTimestamp >= root.cacheTtlMs))
      Qt.callLater(() => root.refresh(root.refreshRequested));
      // A warm cache may be close to expiry at startup; schedule the remaining
      // lifetime, not another complete TTL. Failures retain the normal retry.
      refreshTimer.interval = code === 0 ? Math.max(1, Math.ceil(root.cacheTtlMs - (Date.now() - root.lastScanTimestamp))) : root.cacheTtlMs;
      refreshTimer.restart();
    }
  }

  function reject(message) {
    lastError = message;
    metadataRevision++;
    return false;
  }

  function describeFailure(stdoutText, stderrText) {
    const lowered = `${stdoutText}\n${stderrText}`.toLowerCase();
    if (lowered.includes("unable to elevate") || lowered.includes("request dismissed") || lowered.includes("authentication failed") || lowered.includes("not authorized") || lowered.includes("authorization required")) {
      if (lowered.includes("filenotfound") || lowered.includes("no such file"))
        return I18n.tr("launcher.app-actions.elevator-missing", {
                         "value": "pkexec"
                       });
      return I18n.tr("launcher.app-actions.auth-denied");
    }
    return String(stderrText || "").trim() || String(stdoutText || "").trim() || I18n.tr("launcher.app-actions.operation-failed");
  }

  function run(operation, appId, name, command) {
    if (busy)
      return reject(I18n.tr("launcher.app-actions.operation-in-progress"));
    if (!available || !command || command.length === 0)
      return reject(I18n.tr("launcher.app-actions.unavailable"));
    operationAppId = appId;
    operationName = name;
    lastError = "";
    busy = true;
    pendingOperation = {
      "operation": operation,
      "command": command
    };
    if (metadataProcess.running) {
      operationState = "waiting";
      scanCancelled = true;
      metadataProcess.signal(15);
    } else {
      beginOperation();
    }
    metadataRevision++;
    return true;
  }

  function beginOperation() {
    if (!pendingOperation)
      return;
    operationState = pendingOperation.operation;
    operationProcess.command = pendingOperation.command;
    pendingOperation = null;
    operationProcess.running = true;
    metadataRevision++;
  }

  Process {
    id: operationProcess
    environment: ({
                    "SHELLY_ELEVATOR": root.privilegeElevator
                  })
    stdout: StdioCollector {
      id: operationOut
    }
    stderr: StdioCollector {
      id: operationErr
    }
    onExited: code => {
      const appId = root.operationAppId;
      const operation = root.operationState;
      const name = root.operationName;
      const success = code === 0;
      root.busy = false;
      root.operationState = "idle";
      root.lastError = success ? "" : root.describeFailure(operationOut.text, operationErr.text);
      root.metadataRevision++;

      if (success) {
        // DesktopEntries watches its applications model; this build has no
        // reload() API. Its valuesChanged signal handles real desktop changes.
        ToastService.showNotice(I18n.tr(operation === "update" ? "launcher.app-actions.toast-updated" : "launcher.app-actions.toast-removed"), name, operation === "update" ? "refresh" : "trash");
      } else {
        ToastService.showError(I18n.tr(operation === "update" ? "launcher.app-actions.toast-update-failed" : "launcher.app-actions.toast-remove-failed"), root.lastError);
      }
      if (!(success && operation === "remove"))
      PanelService.openLauncherWithAppPanel(appId);
      root.operationFinished(appId, operation, success);
      root.refresh(true);
    }
  }
}
