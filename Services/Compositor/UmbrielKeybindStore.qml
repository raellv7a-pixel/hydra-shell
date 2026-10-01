pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Modules/Panels/Settings/Tabs/Umbriel/Chords.js" as Chords

Singleton {
  id: root

  property var catalog: []
  property var ipc: ({})
  property var committed: ({
                             "version": 1,
                             "rebinds": {},
                             "custom": []
                           })
  property var draft: ({
                         "version": 1,
                         "rebinds": {},
                         "custom": []
                       })
  property bool loaded: false
  property bool busy: false
  property string error: ""
  property var pendingEdgeApps: null
  property string syncingEdgeApps: ""
  readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(committed)
  readonly property var rows: {
    const values = [];
    for (const item of catalog)
    values.push(Object.assign({}, item, {
                                chord: draft.rebinds[item.id] || item.chord
                              }));
    for (let i = 0; i < draft.custom.length; i++)
    values.push(Object.assign({
                                id: "custom." + i,
                                category: "Personalizados"
                              }, draft.custom[i]));
    return values;
  }
  readonly property var conflicts: Chords.conflicts(rows)
  readonly property bool hasConflicts: Object.keys(conflicts).length > 0

  readonly property string script: Quickshell.shellDir + "/Scripts/python/umbriel_keybinds.py"

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
    const updated = JSON.parse(JSON.stringify(draft));
    const row = catalog.find(item => item.id === id);
    if (!row)
      return;
    const chord = Chords.normalize(value);
    if (!chord) {
      error = "Atalho inválido: " + value;
      return;
    }
    if (chord === Chords.normalize(row.chord))
      delete updated.rebinds[id];
    else
      updated.rebinds[id] = chord;
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
    draft = {
      version: 1,
      rebinds: {},
      custom: []
    };
    error = "";
  }

  function save() {
    if (!loaded || busy || !dirty || hasConflicts)
      return;
    busy = true;
    error = "";
    saveProcess.command = ["python3", script, "save", JSON.stringify(draft)];
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
        root.error = saveError.text.trim() || "Falha na validação Umbriel";
        root.flushPendingEdgeSync();
        return;
      }
      root.committed = JSON.parse(JSON.stringify(root.draft));
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
