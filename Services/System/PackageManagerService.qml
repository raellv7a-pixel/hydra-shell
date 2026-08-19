pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Runs Shelly's privileged operations (update, uninstall) for the launcher.
//
// This lives at shell level rather than inside ApplicationsProvider because a
// SmartPanel unloads its content when it closes (`contentLoader.active:
// isPanelOpen`): running the process from the provider meant the launcher
// closing — which is exactly what used to happen the moment the polkit prompt
// appeared — destroyed the Process mid-transaction and killed the package
// operation. Owning it here lets an update outlive the panel that started it.
Singleton {
  id: root

  property string operationAppId: ""
  property string operationAppName: ""
  property string operationState: "" // "update" | "remove" | ""
  property string lastError: ""

  readonly property bool busy: operationState !== ""

  // Shelly escalates privileges on its own and picks the helper from
  // SHELLY_ELEVATOR. Its default is sudo, which cannot work here: the shell
  // spawns processes without a TTY, so sudo has no way to ask for a password and
  // dies with "a terminal is required to read the password".
  //
  // The helper routes through pkexec so the prompt reaches the session's polkit
  // agent — the shell's own native one, when it is enabled — and the password
  // field shows up on screen. It has to be the wrapper rather than plain pkexec:
  // see Scripts/bash/polkit-elevate.sh for why the bare binary aborts without a
  // controlling terminal. Shelly resolves the invoking user back from PKEXEC_UID,
  // so AUR builds and per-user Flatpaks still run unprivileged.
  readonly property string privilegeElevator: Quickshell.shellDir + "/Scripts/bash/polkit-elevate.sh"
  // Short name for messages — the full path is noise in a toast.
  readonly property string elevatorLabel: "pkexec"

  // appId is the launcher entry's id, echoed back so the caller can re-anchor.
  signal operationFinished(string appId, string operation, bool success)

  function isBusyFor(appId) {
    return busy && appId !== "" && operationAppId === appId;
  }

  function run(operation, appId, appName, command) {
    if (busy || !command || command.length === 0)
      return false;

    operationAppId = String(appId || "");
    operationAppName = String(appName || appId || "");
    operationState = operation;
    lastError = "";

    Logger.d("PackageManager", `Running: ${command.join(" ")} (elevator: ${elevatorLabel})`);
    operationProcess.exec({
                            command: command
                          });
    return true;
  }

  Process {
    id: operationProcess
    running: false
    environment: ({
                    "SHELLY_ELEVATOR": root.privilegeElevator
                  })
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      const operation = root.operationState;
      const appId = root.operationAppId;
      const appName = root.operationAppName;
      const success = exitCode === 0;

      root.lastError = success ? "" : root.describeFailure(String(stdout.text || ""), String(stderr.text || ""));
      root.operationState = "";

      // A package operation easily outlives the launcher, so the outcome has to
      // be reported somewhere that does not depend on the panel still being up.
      if (success) {
        ToastService.showNotice(operation === "update" ? I18n.tr("launcher.app-actions.toast-updated") : I18n.tr("launcher.app-actions.toast-removed"), appName);
      } else {
        ToastService.showError(operation === "update" ? I18n.tr("launcher.app-actions.toast-update-failed") : I18n.tr("launcher.app-actions.toast-remove-failed"), `${appName} — ${root.lastError}`);
      }

      root.operationFinished(appId, operation, success);

      // Bring the launcher back on the app that was acted on, with its inline
      // panel open, so the result lands where the action was started. Uninstall
      // removes the entry, so there is nothing left to anchor to.
      if (!(success && operation === "remove"))
      PanelService.openLauncherWithAppPanel(appId);

      root.operationAppId = "";
      root.operationAppName = "";
    }
  }

  // Turns a failed operation's raw output into something worth showing.
  function describeFailure(stdoutText, stderrText) {
    const lowered = `${stdoutText}\n${stderrText}`.toLowerCase();

    // pkexec: dismissed dialog, wrong password, or no agent to ask with.
    if (lowered.includes("unable to elevate") || lowered.includes("request dismissed") || lowered.includes("authentication failed") || lowered.includes("not authorized") || lowered.includes("authorization required")) {
      if (lowered.includes("filenotfound") || lowered.includes("no such file"))
        return I18n.tr("launcher.app-actions.elevator-missing", {
                         "value": elevatorLabel
                       });
      return I18n.tr("launcher.app-actions.auth-denied");
    }

    const trimmed = String(stderrText || "").trim() || String(stdoutText || "").trim();
    return trimmed || I18n.tr("launcher.app-actions.operation-failed");
  }
}
