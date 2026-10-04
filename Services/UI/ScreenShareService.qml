pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Compositor

Singleton {
  id: root
  property string token: ""
  property var request: null
  property var panel: null
  property var selections: []
  property bool responding: false
  readonly property bool active: request !== null

  function open(path, id) {
    if (token || !path.startsWith((Quickshell.env("XDG_RUNTIME_DIR") || "") + "/hydra-share-"))
      return "busy";
    token = id;
    responding = false;
    connection.path = path;
    connection.connected = true;
    connectDeadline.restart();
    return "ok";
  }
  function reset() {
    connectDeadline.stop();
    const oldPanel = panel;
    panel = null;
    request = null;
    selections = [];
    token = "";
    connection.connected = false;
    if (oldPanel?.isPanelOpen) oldPanel.closeImmediately();
  }
  function respond(values) {
    if (!token || responding) return;
    responding = true;
    connection.write(JSON.stringify({token: token, selections: values}) + "\n");
    connection.flush();
    const oldPanel = panel;
    panel = null;
    request = null;
    if (oldPanel?.isPanelOpen) oldPanel.closeImmediately();
    // Keep the connection alive until the helper receives and closes it.
  }
  function cancel() { respond([]); }
  function selected(kind, value) {
    return selections.some(row => row.kind === kind && (row.output || row.identifier) === value);
  }
  function toggle(kind, value) {
    const entry = kind === "monitor" ? {kind: kind, output: value} : {kind: kind, identifier: value};
    if (!request.multiple) selections = [entry];
    else if (selected(kind, value)) selections = selections.filter(row => !(row.kind === kind && (row.output || row.identifier) === value));
    else selections = selections.concat([entry]);
  }
  function receive(line) {
    try {
      const payload = JSON.parse(line);
      if (payload.token !== token || !payload.request || request) { reset(); return; }
      const screen = CompositorService.getFocusedScreen() || PanelService.findScreenForPanels();
      const target = PanelService.getPanel("screenSharePanel", screen);
      if (!target || PanelService.modalOpen) { reset(); return; }
      request = payload.request;
      connectDeadline.stop();
      selections = [];
      panel = target;
      target.open();
    } catch (error) { reset(); }
  }
  Socket {
    id: connection
    parser: SplitParser { onRead: line => root.receive(line) }
    onConnectionStateChanged: { if (!connected && root.token) root.reset(); }
    onError: root.reset()
  }
  Timer { id: connectDeadline; interval: 3000; onTriggered: root.reset() }
  Timer {
    interval: 1000
    repeat: true
    running: connection.connected && root.token !== ""
    onTriggered: {
      connection.write(JSON.stringify({token: root.token, alive: true}) + "\n");
      connection.flush();
    }
  }
}
