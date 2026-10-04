pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var catalog: []
  property string error: ""
  property bool requested: false
  function ensureLoaded() {
    if (requested) return;
    requested = true;
    actionsProcess.running = true;
  }
  Process {
    id: actionsProcess
    command: ["python3", Quickshell.shellDir + "/Scripts/python/umbriel_actions.py"]
    stdout: StdioCollector { id: actionOutput }
    stderr: StdioCollector { id: actionError }
    onExited: code => {
      if (code !== 0) {
        root.error = actionError.text.trim() || "Falha ao carregar ações Umbriel";
        return;
      }
      try { root.catalog = JSON.parse(actionOutput.text); }
      catch (e) { root.error = "Catálogo de ações inválido: " + e; }
    }
  }
}
