pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property bool loaded: false
  property bool busy: false
  property bool enabled: false
  property bool externallyChanged: false
  property string chooser: ""
  property string revision: ""
  property string error: ""
  function refresh() { run("state"); }
  function setEnabled(value) { if (loaded && !externallyChanged) run(value ? "enable" : "disable"); }
  function run(action) {
    if (busy) return;
    error = "";
    busy = true;
    operation.command = ["python3", Quickshell.shellDir + "/Scripts/python/portal_picker_config.py", action, revision];
    operation.running = true;
  }
  Process {
    id: operation
    stdout: StdioCollector { id: result }
    stderr: StdioCollector { id: failure }
    onExited: code => {
      root.busy = false;
      if (code !== 0) { root.error = failure.text.trim(); return; }
      try {
        const state = JSON.parse(result.text);
        root.enabled = state.enabled;
        root.externallyChanged = state.externallyChanged;
        root.chooser = state.chooser;
        root.revision = state.revision;
        root.loaded = true;
      } catch (error) { root.error = "Falha ao ler configuração do portal: " + error; }
    }
  }
}
