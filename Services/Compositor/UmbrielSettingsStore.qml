pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var committed: ({})
  property var draft: ({})
  property var owners: []
  property string revision: ""
  property bool loaded: false
  property bool busy: false
  property string error: ""
  readonly property bool dirty: loaded && JSON.stringify(draft) !== JSON.stringify(committed)
  readonly property bool externallyOwned: owners.length > 0
  readonly property string script: Quickshell.shellDir + "/Scripts/python/umbriel_settings.py"

  function refresh() {
    if (busy) return;
    busy = true;
    error = "";
    readProcess.running = true;
  }
  function updateOverview(field, value) {
    if (!loaded || busy || externallyOwned) return;
    const updated = JSON.parse(JSON.stringify(draft));
    updated.overview[field] = value;
    draft = updated;
  }
  function updateCorner(corner, field, value) {
    if (!loaded || busy || externallyOwned) return;
    const updated = JSON.parse(JSON.stringify(draft));
    updated.hot_corners[corner][field] = value;
    draft = updated;
  }
  function updateSharingConfirmation(confirmed) {
    if (!loaded || busy || externallyOwned) return;
    const updated = JSON.parse(JSON.stringify(draft));
    updated.screencast.disable_dynamic_confirmation = !confirmed;
    draft = updated;
  }
  function revert() {
    if (busy) return;
    draft = JSON.parse(JSON.stringify(committed));
    error = "";
  }
  function save() {
    if (!loaded || busy || !dirty || externallyOwned) return;
    busy = true;
    error = "";
    writeProcess.command = ["python3", script, "save", JSON.stringify(draft), revision];
    writeProcess.running = true;
  }
  function accept(payload) {
    owners = payload.owners || [];
    revision = payload.revision || "";
    committed = payload.state;
    draft = JSON.parse(JSON.stringify(payload.state));
    loaded = true;
  }
  Process {
    id: readProcess
    command: ["python3", root.script, "state"]
    stdout: StdioCollector { id: readOutput }
    stderr: StdioCollector { id: readError }
    onExited: code => {
      root.busy = false;
      if (code !== 0) { root.error = readError.text.trim(); return; }
      try { root.accept(JSON.parse(readOutput.text)); }
      catch (e) { root.error = "Falha ao carregar configuração Umbriel: " + e; }
    }
  }
  Process {
    id: writeProcess
    stdout: StdioCollector { id: writeOutput }
    stderr: StdioCollector { id: writeError }
    onExited: code => {
      root.busy = false;
      if (code !== 0) { root.error = writeError.text.trim() || "Falha ao validar configuração Umbriel"; return; }
      try { root.accept(JSON.parse(writeOutput.text)); }
      catch (e) { root.error = "Configuração salva; falha ao reler: " + e; root.refresh(); }
    }
  }
}
