pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../../Helpers/HyprlandLuaGen.js" as HyprlandLuaGen

// Writes ~/.config/hypr/hydra-shell/{settings,rebinds}.lua from
// Settings.data.hyprland via the pure generator in Helpers/HyprlandLuaGen.js.
// PLANO_INTEGRACAO_HYPRMOD.md §3.3/§5.
//
// Uses FileView.setText() directly (atomicWrites: true by default — writes a
// temp file and renames over the target, so a failed write never corrupts
// the previous generated file). No JsonAdapter involved: these are plain
// Lua text, not JSON.
Singleton {
  id: root

  readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr"
  readonly property string generatedDir: hyprDir + "/hydra-shell"

  signal settingsSaved
  signal settingsSaveFailed(string error)
  signal rebindsSaved
  signal rebindsSaveFailed(string error)
  signal monitorsSaved
  signal monitorsSaveFailed(string error)

  Component.onCompleted: ensureDirProcess.running = true

  // ~/.config/hypr/hydra-shell is created by Scripts/bash/hyprland-adopt.sh
  // on adoption, but the Settings tab also works in "modo limitado" for a
  // user who declined adoption (PLANO_INTEGRACAO_HYPRMOD.md §7.4) — mkdir -p
  // defensively so the first Save never fails just because that directory
  // was never created.
  Process {
    id: ensureDirProcess
    command: ["mkdir", "-p", root.generatedDir]
    running: false
  }

  FileView {
    id: settingsFile
    path: root.generatedDir + "/settings.lua"
    printErrors: false
    onSaved: root.settingsSaved()
    onSaveFailed: function (error) {
      Logger.e("HyprlandLuaWriter", "Failed to write settings.lua:", error);
      root.settingsSaveFailed(String(error));
    }
  }

  FileView {
    id: rebindsFile
    path: root.generatedDir + "/rebinds.lua"
    printErrors: false
    onSaved: root.rebindsSaved()
    onSaveFailed: function (error) {
      Logger.e("HyprlandLuaWriter", "Failed to write rebinds.lua:", error);
      root.rebindsSaveFailed(String(error));
    }
  }

  // Written by Services/Hardware/MonitorService.qml's saveToHyprlandConfig()
  // — content is already fully-formed Lua (hl.monitor({...}) blocks from
  // HyprlandBackend.js's buildLuaConfigFileContent()), not generated here,
  // so there is no buildX() companion for this one.
  FileView {
    id: monitorsFile
    path: root.generatedDir + "/monitors.lua"
    printErrors: false
    onSaved: root.monitorsSaved()
    onSaveFailed: function (error) {
      Logger.e("HyprlandLuaWriter", "Failed to write monitors.lua:", error);
      root.monitorsSaveFailed(String(error));
    }
  }

  // Pure — safe to call from a live-preview path too if ever needed.
  function buildSettingsLua(hyprlandData) {
    return HyprlandLuaGen.buildSettingsLua(hyprlandData);
  }

  function buildRebindsLua(rebinds) {
    return HyprlandLuaGen.buildRebindsLua(rebinds);
  }

  // Regenerates and writes hydra-shell/settings.lua from the given
  // Settings.data.hyprland-shaped object (draft or committed — caller's
  // choice; HyprlandDraftStore.save() passes the committed data after
  // copying the draft into Settings.data.hyprland).
  function writeSettings(hyprlandData) {
    ensureDirProcess.running = true;
    settingsFile.setText(HyprlandLuaGen.buildSettingsLua(hyprlandData));
  }

  function writeRebinds(rebinds) {
    ensureDirProcess.running = true;
    rebindsFile.setText(HyprlandLuaGen.buildRebindsLua(rebinds));
  }

  // content is pre-built Lua text (see monitorsFile's doc comment above).
  function writeMonitors(content) {
    ensureDirProcess.running = true;
    monitorsFile.setText(content || "-- no outputs configured\n");
  }
}
