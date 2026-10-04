import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "UmbrielSnapshots.js" as Snapshots
import "ScreencastState.js" as Screencast

Item {
  id: root

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property var workspaceCache: ({})
  property var outputs: []
  property var outputCache: ({})
  property string focusedOutputName: ""
  property bool overviewActive: false
  property string keyboardLayout: ""
  property string activeSubmap: ""
  property bool initialized: false
  property bool windowsReceived: false
  property bool outputsRefreshPending: false
  property string appliedVisualConfig: ""
  property var screencastCommand: Screencast.empty()
  property bool screencastEventsAvailable: false

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  function initialize() {
    if (initialized)
      return;
    initialized = true;
    subscription.running = true;
    queryDisplayScales();
    Qt.callLater(applyVisualConfig);
  }

  Process {
    id: subscription
    command: ["umbriel", "subscribe", "workspaces,windows,overview,keyboard_layout,submap,screencast"]
    stdout: SplitParser { onRead: line => root.handleEvent(line) }
    stderr: SplitParser { onRead: line => Logger.w("UmbrielService", "IPC subscription:", line) }
    onExited: exitCode => {
      root.screencastEventsAvailable = false;
      root.screencastCommand = Screencast.empty();
      Logger.w("UmbrielService", "IPC subscription ended:", exitCode);
      reconnect.restart();
    }
  }

  Timer { id: reconnect; interval: 1500; onTriggered: subscription.running = root.initialized }

  function handleEvent(line) {
    try {
      const event = JSON.parse(line);
      switch (event.event) {
      case "screencast":
        screencastCommand = Screencast.reduce(screencastCommand, event.data);
        screencastEventsAvailable = screencastCommand.serial >= 0;
        break;
      case "workspaces":
        if (Array.isArray(event.data))
          updateWorkspaces(event.data);
        break;
      case "windows":
        if (Array.isArray(event.data)) {
          windows = Snapshots.windows(event.data, workspaceCache);
          windowsReceived = true;
          updateFocusedWindowIndex();
          windowListChanged();
          activeWindowChanged();
        }
        break;
      case "overview":
        if (typeof event.data?.open === "boolean")
          overviewActive = event.data.open;
        break;
      case "submap":
        activeSubmap = Snapshots.submap(event.data);
        break;
      case "keyboard_layout":
        if (event.data)
          keyboardLayout = Snapshots.keyboardLayout(event.data);
        break;
      }
    } catch (error) {
      Logger.e("UmbrielService", "Failed to parse IPC event:", error);
    }
  }

  function updateWorkspaces(entries) {
    const next = Snapshots.workspaces(entries);
    const cache = {};
    workspaces.clear();
    for (const ws of next) {
      workspaces.append(ws);
      cache[ws.id] = ws;
    }
    workspaceCache = cache;
    focusedOutputName = Snapshots.focusedOutput(next);
    // Subscription snapshots may arrive in either order; resolve window outputs again.
    windows = windows.map(window => Object.assign({}, window, {
      output: cache[window.workspaceId]?.output || ""
    }));
    workspaceChanged();
    windowListChanged();
    if (next.some(ws => ws.output && !outputCache[ws.output]))
      queryDisplayScales();
  }

  function queryDisplayScales() {
    if (outputsQuery.running) {
      outputsRefreshPending = true;
      return;
    }
    outputsQuery.running = true;
  }

  Process {
    id: outputsQuery
    command: ["umbriel", "outputs", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.outputs = Snapshots.outputs(JSON.parse(text));
          const cache = {};
          for (const output of root.outputs)
            cache[output.name] = output;
          root.outputCache = cache;
          root.displayScalesChanged();
        } catch (error) {
          Logger.e("UmbrielService", "Failed to parse outputs:", error);
        }
      }
    }
    stderr: SplitParser { onRead: line => Logger.w("UmbrielService", "Outputs:", line) }
    onExited: {
      if (root.outputsRefreshPending) {
        root.outputsRefreshPending = false;
        Qt.callLater(root.queryDisplayScales);
      }
    }
  }

  function outputForWorkspace(workspaceId) {
    return workspaceCache[String(workspaceId)]?.output || "";
  }

  function updateFocusedWindowIndex() {
    focusedWindowIndex = windows.findIndex(window => window.isActive);
  }

  function getActiveWindow() {
    return focusedWindowIndex >= 0 ? windows[focusedWindowIndex] : null;
  }

  function action(name, argument) {
    if (!initialized) {
      Logger.w("UmbrielService", "Compositor action unavailable outside Umbriel:", name);
      return;
    }
    Quickshell.execDetached(["umbriel", "msg", argument === undefined ? name : name + ":" + String(argument)]);
  }

  function switchToWorkspace(workspace) {
    if (workspace)
      action("workspace-switch", Snapshots.workspaceSelector(workspace));
  }

  function focusWindow(window) {
    if (window?.id)
      action("window-focus", window.id);
  }

  function closeWindow(window) {
    if (window?.id)
      action("window-close", window.id);
  }

  function focusWindowByAddress(id) { action("window-focus", id); }
  function closeWindowByAddress(id) { action("window-close", id); }

  function moveWindowToWorkspace(id, workspace) {
    // Native action moves the currently focused window, so select the requested ID first.
    const selector = typeof workspace === "object" ? Snapshots.workspaceSelector(workspace) : String(workspace);
    Quickshell.execDetached(["sh", "-c", 'umbriel msg "window-focus:$1" && umbriel msg "window-move-to-workspace:$2"', "hydra", String(id), selector]);
  }

  function spawn(command) {
    const parts = Array.isArray(command) ? command : [command];
    action("spawn", parts.map(part => "'" + String(part).replace(/'/g, "'\\''") + "'").join(" "));
  }

  function turnOffMonitors() { action("dpms-off"); }
  function turnOnMonitors() { action("dpms-on"); }
  function logout() { action("session-quit", "skip-confirmation"); }
  function cycleKeyboardLayout() { action("keyboard-layout-next"); }

  function getFocusedScreen() {
    const screens = Quickshell.screens || [];
    return screens.find(screen => screen.name === focusedOutputName) || screens[0] || null;
  }

  function applyVisualConfig() {
    if (!initialized || !Settings.isLoaded || visualConfig.running)
      return;
    const value = JSON.stringify({
      enabled: Settings.data.general.enableBlurBehind,
      outputs: (Quickshell.screens || []).map(screen => screen.name)
    });
    if (value === appliedVisualConfig)
      return;
    visualConfig.request = value;
    visualConfig.command = ["python3", Quickshell.shellDir + "/Scripts/python/umbriel_config.py", "visual", value];
    visualConfig.running = true;
  }

  Connections {
    target: Settings
    function onSettingsLoaded() { Qt.callLater(root.applyVisualConfig); }
  }
  Connections {
    target: Settings.data.general
    function onEnableBlurBehindChanged() { Qt.callLater(root.applyVisualConfig); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { Qt.callLater(root.applyVisualConfig); }
  }

  Process {
    id: visualConfig
    property string request: ""
    stderr: StdioCollector {}
    onExited: code => {
      if (code === 0) {
        root.appliedVisualConfig = request;
        Qt.callLater(root.applyVisualConfig);
      } else {
        Logger.e("UmbrielService", "Visual configuration rejected:", visualConfig.stderr.text);
      }
    }
  }
}
