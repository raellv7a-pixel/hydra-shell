pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// One-time privilege setup for the "Papirus Folders" theming template
// (Services/Theming/TemplateRegistry.qml, id "papirusFolders").
//
// papirus-folders writes into /usr/share/icons/Papirus (root:root, 755), so
// the template's post_hook runs it via a silent, backgrounded
// `sudo -n papirus-folders -C <color> -u` on every palette regeneration —
// fire-and-forget, stderr discarded. Without a passwordless sudo rule that
// `sudo -n` fails invisibly every single time and folder colors never
// change, even though the template shows as "enabled". See
// Scripts/bash/papirus-folders-setup.sh for the actual grant, applied once
// via a polkit prompt so every regeneration after that stays silent.
Singleton {
  id: root

  readonly property string setupScript: Quickshell.shellDir + "/Scripts/bash/papirus-folders-setup.sh"
  // Same pkexec wrapper PackageManagerService uses — plain pkexec aborts
  // without a controlling terminal (see Scripts/bash/polkit-elevate.sh).
  readonly property string privilegeElevator: Quickshell.shellDir + "/Scripts/bash/polkit-elevate.sh"

  property bool busy: false

  // Call when the user enables the papirusFolders template. Idempotent and
  // cheap when already configured: resolves the binary, does a passwordless
  // dry-run probe, and only falls through to the polkit prompt if that probe
  // fails — so re-toggling the setting never re-prompts.
  function ensureConfigured() {
    if (busy)
      return;
    busy = true;
    Logger.d("PapirusFoldersSetup", "ensureConfigured: starting detection");
    detectProcess.running = true;
  }

  // `command -v` doubles as the "is papirus-folders installed" check and
  // resolves its real path (distro package vs. an AUR/local install differ).
  Process {
    id: detectProcess
    running: false
    command: ["sh", "-c", "command -v papirus-folders"]
    stdout: StdioCollector {}

    onExited: exitCode => {
      const binaryPath = stdout.text.trim();
      Logger.d("PapirusFoldersSetup", `detect exited code=${exitCode} path="${binaryPath}"`);
      if (exitCode !== 0 || !binaryPath) {
        root.busy = false;
        ToastService.showError(I18n.tr("panels.color-scheme.papirus-setup-failed-title"), I18n.tr("panels.color-scheme.papirus-setup-missing-binary"));
        return;
      }
      probeProcess.resolvedPath = binaryPath;
      probeProcess.command = ["sudo", "-n", binaryPath, "-V"];
      probeProcess.running = true;
    }
  }

  Process {
    id: probeProcess
    running: false
    property string resolvedPath: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      // Already passwordless — skip the polkit prompt entirely.
      Logger.d("PapirusFoldersSetup", `probe exited code=${exitCode} stderr="${stderr.text.trim()}"`);
      if (exitCode === 0) {
        root.busy = false;
        return;
      }
      const user = HostService.username || Quickshell.env("LOGNAME") || "";
      Logger.d("PapirusFoldersSetup", `launching setup via pkexec for user="${user}" path="${resolvedPath}"`);
      setupProcess.command = [root.privilegeElevator, root.setupScript, user, resolvedPath];
      setupProcess.running = true;
    }
  }

  Process {
    id: setupProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      root.busy = false;
      Logger.d("PapirusFoldersSetup", `setup exited code=${exitCode} stdout="${stdout.text.trim()}" stderr="${stderr.text.trim()}"`);
      if (exitCode === 0) {
        ToastService.showNotice(I18n.tr("panels.color-scheme.papirus-setup-success"));
      } else {
        const detail = String(stderr.text || stdout.text || "").trim();
        ToastService.showError(I18n.tr("panels.color-scheme.papirus-setup-failed-title"), detail || I18n.tr("actions.auth-denied"));
      }
    }
  }
}
