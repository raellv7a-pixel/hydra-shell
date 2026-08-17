pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor

// Draft + commit + live-preview + revert for the Hyprland Settings tab
// (PLANO_INTEGRACAO_HYPRMOD.md §3.5). Replaces the "Pending Changes page"
// idea from an earlier draft of the plan — modeled on ryoku-arch's
// hub.hyprEdit/hyprVal/hyprCommittedVal: every SubTab reads/writes only
// through this store and never touches Settings.data.hyprland, HyprlandLuaWriter
// or HyprlandEvalService directly.
//
// draft starts as a deep copy of Settings.data.hyprland (the committed
// state) when the Hyprland tab is opened (call load() from the Tab's
// Component.onCompleted). edit() mutates the draft only; save() is the only
// function that writes back to Settings.data.hyprland, regenerates the Lua
// files and reloads Hyprland.
Singleton {
  id: root

  property var draft: ({})
  property var committedSnapshot: ({})

  readonly property bool isDirty: JSON.stringify(draft) !== JSON.stringify(committedSnapshot)

  // Only these top-level keys get a live `hyprctl eval` preview on edit();
  // everything else (env vars, autostart, rules, keybinds) only takes effect
  // on save()+reload, matching the conservative list documented in
  // PLANO_INTEGRACAO_HYPRMOD.md §3.4.
  readonly property var _previewableRoots: ({
                                              "appearance": true,
                                              "cursor": true
                                            })

  function _snapshotCommitted() {
    var h = Settings.data.hyprland;
    return {
      "appearance": {
        "gapsIn": h.appearance.gapsIn,
        "gapsOut": h.appearance.gapsOut,
        "borderSize": h.appearance.borderSize,
        "layout": h.appearance.layout,
        "resizeOnBorder": h.appearance.resizeOnBorder,
        "allowTearing": h.appearance.allowTearing,
        "rounding": h.appearance.rounding,
        "roundingPower": h.appearance.roundingPower,
        "activeOpacity": h.appearance.activeOpacity,
        "inactiveOpacity": h.appearance.inactiveOpacity,
        "shadowEnabled": h.appearance.shadowEnabled,
        "shadowRange": h.appearance.shadowRange,
        "shadowRenderPower": h.appearance.shadowRenderPower,
        "blurEnabled": h.appearance.blurEnabled,
        "blurSize": h.appearance.blurSize,
        "blurPasses": h.appearance.blurPasses,
        "blurXray": h.appearance.blurXray,
        "animationsEnabled": h.appearance.animationsEnabled
      },
      "cursor": {
        "theme": h.cursor.theme,
        "size": h.cursor.size
      },
      "envVars": (h.envVars || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "autostart": (h.autostart || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "windowRules": (h.windowRules || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "layerRules": (h.layerRules || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "animCurves": (h.animCurves || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "animItems": (h.animItems || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "keybinds": (h.keybinds || []).map(function (e) {
        return Object.assign({}, e);
      }),
      "rebinds": Object.assign({}, h.rebinds || {})
    };
  }

  // Call when the Hyprland Settings tab becomes visible. Idempotent — safe
  // to call every time the tab opens; discards any unsaved draft from a
  // previous visit (same as leaving any other Settings tab without saving).
  function load() {
    committedSnapshot = _snapshotCommitted();
    draft = JSON.parse(JSON.stringify(committedSnapshot));
  }

  // path: dotted, e.g. "appearance.gapsIn", "envVars" (whole-array replace),
  // "rebinds" (whole-object replace).
  function edit(path, value) {
    var parts = path.split(".");
    var target = draft;
    for (var i = 0; i < parts.length - 1; i++) {
      target = target[parts[i]];
    }
    target[parts[parts.length - 1]] = value;
    draftChanged(); // force isDirty / bindings depending on `draft` to re-evaluate

    var root0 = parts[0];
    if (root._previewableRoots[root0]) {
      _preview();
    }
  }

  function val(path) {
    return _get(draft, path);
  }

  function committedVal(path) {
    return _get(committedSnapshot, path);
  }

  function _get(obj, path) {
    var parts = path.split(".");
    var v = obj;
    for (var i = 0; i < parts.length; i++) {
      if (v === undefined || v === null)
        return undefined;
      v = v[parts[i]];
    }
    return v;
  }

  function _preview() {
    var snippet = HyprlandLuaWriter.buildSettingsLua({
                                                       "appearance": draft.appearance
                                                     });
    // buildSettingsLua's header comment lines are harmless to eval (Lua
    // comments), so the same generator serves both file-writing and preview.
    HyprlandEvalService.evalLua(snippet);
    if (draft.cursor && draft.cursor.theme !== undefined) {
      Logger.d("HyprlandDraftStore", "cursor live-apply is wired in the Cursor SubTab (Fase 3), not here");
    }
  }

  // Commits the draft to Settings.data.hyprland, regenerates and writes the
  // Lua files, and reloads Hyprland to lock in list-shaped changes (rules,
  // env vars, autostart, keybinds) that a live eval preview cannot express.
  function save() {
    var a = draft.appearance;
    var ha = Settings.data.hyprland.appearance;
    ha.gapsIn = a.gapsIn;
    ha.gapsOut = a.gapsOut;
    ha.borderSize = a.borderSize;
    ha.layout = a.layout;
    ha.resizeOnBorder = a.resizeOnBorder;
    ha.allowTearing = a.allowTearing;
    ha.rounding = a.rounding;
    ha.roundingPower = a.roundingPower;
    ha.activeOpacity = a.activeOpacity;
    ha.inactiveOpacity = a.inactiveOpacity;
    ha.shadowEnabled = a.shadowEnabled;
    ha.shadowRange = a.shadowRange;
    ha.shadowRenderPower = a.shadowRenderPower;
    ha.blurEnabled = a.blurEnabled;
    ha.blurSize = a.blurSize;
    ha.blurPasses = a.blurPasses;
    ha.blurXray = a.blurXray;
    ha.animationsEnabled = a.animationsEnabled;

    var hc = Settings.data.hyprland.cursor;
    hc.theme = draft.cursor.theme;
    hc.size = draft.cursor.size;

    Settings.data.hyprland.envVars = draft.envVars;
    Settings.data.hyprland.autostart = draft.autostart;
    Settings.data.hyprland.windowRules = draft.windowRules;
    Settings.data.hyprland.layerRules = draft.layerRules;
    Settings.data.hyprland.animCurves = draft.animCurves;
    Settings.data.hyprland.animItems = draft.animItems;
    Settings.data.hyprland.keybinds = draft.keybinds;
    Settings.data.hyprland.rebinds = draft.rebinds;

    Settings.saveImmediate();

    // Write from `draft` (a plain deep-copied JS object), not
    // Settings.data.hyprland directly — HyprlandLuaGen.js's Object.assign()-
    // based default merging expects plain objects, not QML JsonObjects.
    HyprlandLuaWriter.writeSettings(draft);
    HyprlandLuaWriter.writeRebinds(draft.rebinds);

    committedSnapshot = JSON.parse(JSON.stringify(draft));

    reloadTimer.restart();
  }

  // Small debounce so the two FileView writes above (settings.lua,
  // rebinds.lua) both land before hyprctl reload picks them up.
  Timer {
    id: reloadTimer
    interval: 150
    onTriggered: reloadProcess.running = true
  }

  Process {
    id: reloadProcess
    running: false
    command: ["hyprctl", "reload"]
    onExited: function (exitCode) {
      if (exitCode !== 0)
        Logger.e("HyprlandDraftStore", "hyprctl reload failed, exit code", exitCode);
    }
  }

  function revert() {
    draft = JSON.parse(JSON.stringify(committedSnapshot));
    _preview();
  }
}
