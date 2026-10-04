pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Modules/Panels/Settings/Tabs/Umbriel/Chords.js" as Chords

Singleton {
  id: root

  property var catalog: []
  property var ipc: ({})
  property var committed: ({ "version": 2, "overrides": {}, "custom": [] })
  property var draft: ({ "version": 2, "overrides": {}, "custom": [] })
  property var savingState: null
  property bool loaded: false
  property bool busy: false
  property string error: ""
  property var pendingEdgeApps: null
  property string syncingEdgeApps: ""
  readonly property bool dirty: canonical(draft) !== canonical(committed)
  readonly property var rows: {
    const values = [];
    for (const item of catalog)
      values.push(Object.assign({}, item, draft.overrides[item.id] || {}));
    for (let i = 0; i < draft.custom.length; i++)
    values.push(Object.assign({
                                id: "custom." + i,
                                category: "Personalizados"
                              }, draft.custom[i]));
    return Chords.adoptSwitcherDefaults(values, draft.overrides);
  }
  readonly property var conflicts: Chords.conflicts(rows)
  readonly property bool hasConflicts: Object.keys(conflicts).length > 0

  readonly property string script: Quickshell.shellDir + "/Scripts/python/umbriel_keybinds.py"
  function canonical(state) {
    function sorted(value) {
      if (Array.isArray(value)) return value.map(sorted);
      if (value !== null && typeof value === "object") {
        const object = {};
        for (const key of Object.keys(value).sort()) object[key] = sorted(value[key]);
        return object;
      }
      return value;
    }
    return JSON.stringify(sorted(state));
  }


  function init() {
    if (loaded || busy)
      return;
    busy = true;
    error = "";
    provision.command = ["python3", script, "provision"];
    provision.running = true;
  }

  function refresh() {
    if (busy)
      return;
    busy = true;
    error = "";
    loadProcess.running = true;
  }

  function rebind(id, value) {
    const normalized = Chords.normalize(value);
    if (!normalized) {
      error = "Atalho inválido: " + value;
      return;
    }
    editBind(id, "chord", normalized);
  }

  function editBind(id, field, value) {
    if (id.startsWith("custom.")) {
      editCustom(Number(id.slice(7)), field, value);
      return;
    }
    const original = catalog.find(item => item.id === id);
    if (!original || !["chord", "type", "action", "repeat", "allow_when_locked", "allow_when_inhibited", "cooldown_ms"].includes(field))
      return;
    const updated = JSON.parse(JSON.stringify(draft));
    const override = updated.overrides[id] || {};
    if (value === original[field])
      delete override[field];
    else
      override[field] = value;
    if (Object.keys(override).length)
      updated.overrides[id] = override;
    else
      delete updated.overrides[id];
    draft = updated;
    error = "";
  }

  function restoreBind(id) {
    if (id.startsWith("custom."))
      return;
    const updated = JSON.parse(JSON.stringify(draft));
    delete updated.overrides[id];
    draft = updated;
    error = "";
  }

  function addCustom() {
    const updated = JSON.parse(JSON.stringify(draft));
    updated.custom.push({
                          label: "Novo atalho",
                          chord: "",
                          type: "command",
                          action: "",
                          repeat: false,
                          allow_when_locked: false,
                          allow_when_inhibited: false,
                          cooldown_ms: 0
                        });
    draft = updated;
  }

  function editCustom(index, field, value) {
    const updated = JSON.parse(JSON.stringify(draft));
    if (!updated.custom[index])
      return;
    updated.custom[index][field] = value;
    draft = updated;
    error = "";
  }

  function removeCustom(index) {
    const updated = JSON.parse(JSON.stringify(draft));
    updated.custom.splice(index, 1);
    draft = updated;
  }

  function revert() {
    draft = JSON.parse(JSON.stringify(committed));
    error = "";
  }
  function restoreDefaults() {
    draft = { version: 2, overrides: {}, custom: [] };
    error = "";
  }

  function save() {
    if (!loaded || busy || !dirty || hasConflicts)
      return;
    savingState = JSON.parse(JSON.stringify(draft));
    busy = true;
    error = "";
    saveProcess.command = ["python3", script, "save", JSON.stringify(savingState), JSON.stringify(committed)];
    saveProcess.running = true;
  }

  function syncEdgeScratchpads(pinnedApps) {
    const apps = Array.from(pinnedApps || []);
    if (busy) {
      pendingEdgeApps = apps;
      return;
    }
    const serialized = JSON.stringify(apps);
    if (serialized === syncingEdgeApps && !error)
      return;
    busy = true;
    error = "";
    syncingEdgeApps = serialized;
    syncProcess.command = ["python3", script, "sync", serialized];
    syncProcess.running = true;
  }

  function flushPendingEdgeSync() {
    if (busy || pendingEdgeApps === null)
      return;
    const apps = pendingEdgeApps;
    pendingEdgeApps = null;
    syncEdgeScratchpads(apps);
  }

  Connections {
    target: (typeof Settings !== "undefined" && Settings.data && Settings.data.edgeShelf) ? Settings.data.edgeShelf : null
    function onPinnedAppsChanged() {
      if (typeof CompositorService !== "undefined" && CompositorService.isUmbriel && Settings.isLoaded) {
        root.syncEdgeScratchpads(Settings.data.edgeShelf.pinnedApps);
      }
    }
  }

  Process {
    id: provision
    stderr: StdioCollector {
      id: provisionError
    }
    onExited: code => {
      root.busy = false;
      if (code !== 0)
      root.error = provisionError.text.trim() || "Falha ao instalar atalhos Umbriel";
      else
      root.refresh();
      root.flushPendingEdgeSync();
    }
  }

  Process {
    id: loadProcess
    command: ["python3", root.script, "state"]
    stdout: StdioCollector {
      id: loadOutput
    }
    stderr: StdioCollector {
      id: loadError
    }
    onExited: code => {
      root.busy = false;
      if (code !== 0) {
        root.error = loadError.text.trim() || "Falha ao carregar atalhos";
        root.flushPendingEdgeSync();
        return;
      }
      try {
        const data = JSON.parse(loadOutput.text);
        root.catalog = data.catalog;
        root.ipc = data.ipc;
        root.committed = data.state;
        root.draft = JSON.parse(JSON.stringify(data.state));
        root.loaded = true;
      } catch (e) {
        root.error = "Falha ao ler catálogo: " + e;
      }
      root.flushPendingEdgeSync();
    }
  }

  Process {
    id: saveProcess
    stdout: StdioCollector {
      id: saveOutput
    }
    stderr: StdioCollector {
      id: saveError
    }
    onExited: code => {
      root.busy = false;
      if (code !== 0) {
        root.savingState = null;
        root.error = saveError.text.trim() || "Falha na validação Umbriel";
        root.flushPendingEdgeSync();
        return;
      }
      root.committed = root.savingState;
      root.savingState = null;
      root.error = "";
      root.flushPendingEdgeSync();
    }
  }

  Process {
    id: syncProcess
    stderr: StdioCollector {
      id: syncError
    }
    onExited: code => {
      root.busy = false;
      if (code !== 0) {
        root.error = syncError.text.trim() || "Falha ao sincronizar scratchpads Edge";
      } else {
        root.error = "";
      }
      root.flushPendingEdgeSync();
    }
  }
}
