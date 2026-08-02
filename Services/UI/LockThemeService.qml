pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property var installedThemes: []
  property var catalogThemes: []
  
  property bool isFetchingCatalog: false
  property bool isInstalling: false
  
  readonly property string scriptPath: Quickshell.shellDir + "/Scripts/python/src/sddm_store.py"
  readonly property string applyScriptPath: Quickshell.shellDir + "/Scripts/bash/apply-sddm-theme.sh"

  function refreshInstalled() {
    var procString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["python", "${scriptPath}", "list"]
        stdout: StdioCollector {}
        onExited: function(exitCode) {
          if (exitCode === 0 && stdout.readAll()) {
            try {
              var parsed = JSON.parse(stdout.readAll());
              if (parsed.error) {
                Logger.e("LockThemeService", "Error listing themes:", parsed.error);
              } else {
                root.installedThemes = parsed;
              }
            } catch (e) {
              Logger.e("LockThemeService", "Parse error:", e);
            }
          }
          this.destroy();
        }
      }
    `;
    var proc = Qt.createQmlObject(procString, root, "LockThemeListProc");
  }

  function fetchCatalog() {
    isFetchingCatalog = true;
    var procString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["python", "${scriptPath}", "catalog"]
        stdout: StdioCollector {}
        onExited: function(exitCode) {
          if (exitCode === 0 && stdout.readAll()) {
            try {
              var parsed = JSON.parse(stdout.readAll());
              if (parsed.error) {
                Logger.e("LockThemeService", "Error fetching catalog:", parsed.error);
              } else {
                root.catalogThemes = parsed;
              }
            } catch (e) {
              Logger.e("LockThemeService", "Parse error:", e);
            }
          }
          root.isFetchingCatalog = false;
          this.destroy();
        }
      }
    `;
    var proc = Qt.createQmlObject(procString, root, "LockThemeCatalogProc");
  }

  function installTheme(slug) {
    isInstalling = true;
    Logger.i("LockThemeService", "Installing theme:", slug);
    var procString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["python", "${scriptPath}", "install", "${slug}"]
        stdout: StdioCollector {}
        onExited: function(exitCode) {
          if (exitCode === 0 && stdout.readAll()) {
            try {
              var parsed = JSON.parse(stdout.readAll());
              if (parsed.error) {
                Logger.e("LockThemeService", "Error installing theme:", parsed.error);
              } else {
                Logger.i("LockThemeService", "Theme installed successfully:", slug);
                root.refreshInstalled();
                root.fetchCatalog();
              }
            } catch (e) {
              Logger.e("LockThemeService", "Parse error:", e);
            }
          }
          root.isInstalling = false;
          this.destroy();
        }
      }
    `;
    var proc = Qt.createQmlObject(procString, root, "LockThemeInstallProc");
  }

  function applyTheme(slug, path) {
    // 1. Update the in-session lock preference
    if (Settings.data.general) {
      Settings.data.general.sddmTheme = slug;
      Settings.saveImmediate();
    }
    
    // 2. Trigger pkexec to apply it to SDDM
    Logger.i("LockThemeService", "Applying SDDM theme globally via pkexec:", slug);
    var procString = `
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["pkexec", "bash", "${applyScriptPath}", "${path}"]
        onExited: function(exitCode) {
          Logger.i("LockThemeService", "SDDM theme apply finished with code:", exitCode);
          this.destroy();
        }
      }
    `;
    var proc = Qt.createQmlObject(procString, root, "LockThemeApplyProc");
  }

  Component.onCompleted: {
    refreshInstalled();
  }
}
