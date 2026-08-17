pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Backs the SDDM theme store in
// Modules/Panels/Settings/Tabs/LockScreen/LockScreenTab.qml. Fetches the
// Qylock theme catalog, installs themes locally, and applies one system-wide
// via pkexec.
//
// `allThemes` is the single merged source of truth the tab renders from —
// installed and catalog entries for the same slug are combined into one row
// instead of being listed twice (once as "installed", once again in the
// store with a disabled "Installed" button).
//
// A persistent Singleton (like PackageManagerService) so an install/apply
// outlives the Settings panel that started it, and owns its own toasts for
// the same reason.
Singleton {
  id: root

  property var installedThemes: []
  property var catalogThemes: []

  property bool isFetchingCatalog: false
  property bool isRefreshingInstalled: false
  // "" when idle; the theme slug currently being installed/applied
  // otherwise. Per-slug rather than a bool so only the acted-on card shows a
  // spinner while every other card stays visibly interactive.
  property string installingSlug: ""
  property string applyingSlug: ""
  readonly property bool busy: installingSlug !== "" || applyingSlug !== ""

  readonly property string scriptPath: Quickshell.shellDir + "/Scripts/python/src/sddm_store.py"
  readonly property string applyScriptPath: Quickshell.shellDir + "/Scripts/bash/apply-sddm-theme.sh"
  // Plain pkexec aborts without a controlling terminal — a process spawned by
  // the shell never has one. Same wrapper PackageManagerService uses; see
  // Scripts/bash/polkit-elevate.sh for the full explanation.
  readonly property string privilegeElevator: Quickshell.shellDir + "/Scripts/bash/polkit-elevate.sh"

  // Merge by slug: an installed theme's local (file://) preview and
  // description win over the catalog's remote guess, but fall back to the
  // catalog's preview when a local one isn't shipped. Every catalog theme
  // not yet installed still shows up, so the store stays browsable. Each
  // slug appears exactly once.
  readonly property var allThemes: {
    const bySlug = {};
    for (let i = 0; i < catalogThemes.length; i++) {
      const t = catalogThemes[i];
      bySlug[t.slug] = Object.assign({}, t);
    }
    for (let i = 0; i < installedThemes.length; i++) {
      const t = installedThemes[i];
      const existing = bySlug[t.slug] || {};
      bySlug[t.slug] = Object.assign({}, existing, t, {
                                       "installed": true,
                                       "preview_url": t.preview_url || existing.preview_url || ""
                                     });
    }
    return Object.values(bySlug).sort((a, b) => a.name.localeCompare(b.name));
  }

  function refreshInstalled() {
    isRefreshingInstalled = true;
    listProcess.running = true;
  }

  function fetchCatalog() {
    isFetchingCatalog = true;
    catalogProcess.running = true;
  }

  function installTheme(slug) {
    if (busy)
      return;
    installingSlug = slug;
    Logger.i("LockThemeService", "Installing theme:", slug);
    installProcess.exec({
                          "command": ["python", scriptPath, "install", slug]
                        });
  }

  function applyTheme(slug, path) {
    if (busy)
      return;
    applyingSlug = slug;
    if (Settings.data.general) {
      Settings.data.general.sddmTheme = slug;
      Settings.saveImmediate();
    }
    Logger.i("LockThemeService", "Applying SDDM theme globally via pkexec:", slug);
    applyProcess.exec({
                        "command": [privilegeElevator, "bash", applyScriptPath, path]
                      });
  }

  Process {
    id: listProcess
    running: false
    command: ["python", root.scriptPath, "list"]
    stdout: StdioCollector {}

    onExited: exitCode => {
      root.isRefreshingInstalled = false;
      const outText = stdout.text;
      if (exitCode !== 0 || !outText)
        return;
      try {
        const parsed = JSON.parse(outText);
        if (parsed.error) {
          Logger.e("LockThemeService", "Error listing themes:", parsed.error);
        } else {
          root.installedThemes = parsed;
        }
      } catch (e) {
        Logger.e("LockThemeService", "Parse error:", e);
      }
    }
  }

  Process {
    id: catalogProcess
    running: false
    command: ["python", root.scriptPath, "catalog"]
    stdout: StdioCollector {}

    onExited: exitCode => {
      root.isFetchingCatalog = false;
      const outText = stdout.text;
      if (exitCode !== 0 || !outText)
        return;
      try {
        const parsed = JSON.parse(outText);
        if (parsed.error) {
          Logger.e("LockThemeService", "Error fetching catalog:", parsed.error);
        } else {
          root.catalogThemes = parsed;
        }
      } catch (e) {
        Logger.e("LockThemeService", "Parse error:", e);
      }
    }
  }

  Process {
    id: installProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      const slug = root.installingSlug;
      root.installingSlug = "";
      let parsed = null;
      try {
        parsed = stdout.text ? JSON.parse(stdout.text) : null;
      } catch (e) {
        // Handled by the generic failure branch below.
      }
      if (exitCode === 0 && parsed && !parsed.error) {
        Logger.i("LockThemeService", "Theme installed successfully:", slug);
        root.refreshInstalled();
        root.fetchCatalog();
      } else {
        const error = (parsed && parsed.error) || String(stderr.text || "").trim() || "install failed";
        Logger.e("LockThemeService", "Error installing theme:", error);
        ToastService.showError(I18n.tr("panels.lock-screen.sddm-install-failed-title"), error);
      }
    }
  }

  Process {
    id: applyProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: exitCode => {
      const slug = root.applyingSlug;
      root.applyingSlug = "";
      Logger.i("LockThemeService", "SDDM theme apply finished with code:", exitCode);
      if (exitCode === 0) {
        ToastService.showNotice(I18n.tr("panels.lock-screen.sddm-apply-success"));
      } else {
        const error = String(stderr.text || stdout.text || "").trim() || "apply failed";
        // The apply failed system-side; don't leave the in-session preference
        // pointing at a theme that never actually got installed to SDDM.
        Settings.data.general.sddmTheme = "";
        Settings.saveImmediate();
        ToastService.showError(I18n.tr("panels.lock-screen.sddm-apply-failed-title"), error);
      }
    }
  }

  Component.onCompleted: refreshInstalled()
}
