import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property var workspaceCache: ({})
  property var outputCache: ({})
  property bool initialized: false

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  function initialize() {
    if (initialized)
      return;
    initialized = true;
    subscription.running = true;
    Logger.i("UmbrielService", "Subscribing to workspaces and windows");
  }

  Process {
    id: subscription
    command: ["umbriel", "subscribe", "workspaces,windows"]

    stdout: SplitParser {
      onRead: function (line) {
        root.handleEvent(line);
      }
    }

    stderr: SplitParser {
      onRead: function (line) {
        Logger.w("UmbrielService", "IPC subscription:", line);
      }
    }

    onExited: function (exitCode) {
      Logger.w("UmbrielService", "IPC subscription ended with exit code", exitCode);
    }
  }

  function handleEvent(line) {
    try {
      const event = JSON.parse(line);
      if (!event || !Array.isArray(event.data))
        return;
      if (event.event === "workspaces") {
        updateWorkspaces(event.data);
        workspaceChanged();
      } else if (event.event === "windows") {
        updateWindows(event.data);
        windowListChanged();
        activeWindowChanged();
      }
    } catch (error) {
      Logger.e("UmbrielService", "Failed to parse IPC event:", error);
    }
  }

  function updateWorkspaces(entries) {
    workspaceCache = ({});
    outputCache = ({});
    workspaces.clear();

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i] || {};
      const rawId = entry.id !== undefined ? String(entry.id) : String(entry.index);
      const indexValue = Number(entry.index);
      const index = Number.isFinite(indexValue) && indexValue > 0 ? indexValue : i + 1;
      const output = entry.output || "";
      const ws = {
        id: index,
        idx: index,
        index: index,
        handle: rawId,
        name: entry.name || rawId,
        output: output,
        layout: entry.layout || "",
        isActive: entry.active === true || entry.is_active === true,
        isFocused: entry.focused === true || entry.is_focused === true,
        isUrgent: false,
        isOccupied: entry.occupied === true || entry.is_occupied === true,
        named: entry.named === true
      };
      workspaces.append(ws);
      workspaceCache[rawId] = ws;
      workspaceCache[String(index)] = ws;
      if (output)
        outputCache[output] = {
          name: output,
          scale: 1.0
        };
    }

    refreshWindowOutputs();
    publishOutputs();
  }

  function updateWindows(entries) {
    const next = [];
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i] || {};
      const workspaceHandle = typeof entry.workspace === "string"
        ? entry.workspace
        : (entry.workspace?.id !== undefined ? entry.workspace.id : (entry.workspace?.index !== undefined ? entry.workspace.index : (entry.workspace_id !== undefined ? entry.workspace_id : "")));
      const workspaceInfo = workspaceCache[String(workspaceHandle)];
      const workspaceId = workspaceInfo ? workspaceInfo.id : (Number.isFinite(Number(workspaceHandle)) ? Number(workspaceHandle) : -1);
      const rect = entry.geometry || {};
      const position = rect.position || rect;
      const output = entry.output || (typeof entry.workspace === "object" ? entry.workspace.output : "") || (workspaceInfo ? workspaceInfo.output : "");
      const isFocused = entry.focused === true || entry.is_focused === true;
      const isActive = entry.active === true || entry.is_active === true;
      const x = Number(entry.x !== undefined ? entry.x : (position.x !== undefined ? position.x : 0));
      const y = Number(entry.y !== undefined ? entry.y : (position.y !== undefined ? position.y : 0));
      const w = Number(entry.w !== undefined ? entry.w : (rect.width !== undefined ? rect.width : (entry.width !== undefined ? entry.width : 0)));
      const h = Number(entry.h !== undefined ? entry.h : (rect.height !== undefined ? rect.height : (entry.height !== undefined ? entry.height : 0)));
      next.push({
                  id: String(entry.id !== undefined ? entry.id : ""),
                  title: entry.title || "",
                  appId: entry.app_id || entry.appId || entry.appid || "",
                  workspaceId: workspaceId,
                  workspaceHandle: String(workspaceHandle),
                  isFocused: isFocused,
                  isActive: isActive,
                  output: output || "",
                  x: x,
                  y: y,
                  w: w,
                  h: h,
                  position: {
                    x: x,
                    y: y
                  },
                  width: w,
                  height: h,
                  handle: String(entry.id !== undefined ? entry.id : ""),
                  floating: entry.floating === true,
                  scratchpad: entry.scratchpad || ""
                });
    }
    windows = next;
    updateFocusedWindowIndex();
  }

  function refreshWindowOutputs() {
    if (!windows.length)
      return;
    windows = windows.map(window => {
                            const workspace = workspaceCache[window.workspaceHandle] || workspaceCache[String(window.workspaceId)];
                            return Object.assign({}, window, {
                                                   workspaceId: workspace ? workspace.id : window.workspaceId,
                                                   output: window.output || (workspace ? workspace.output : "")
                                                 });
                          });
  }

  function outputForWorkspace(workspaceId) {
    const ws = workspaceCache[String(workspaceId)];
    return ws ? ws.output : "";
  }

  function updateFocusedWindowIndex() {
    focusedWindowIndex = -1;
    for (let i = 0; i < windows.length; i++) {
      if (windows[i].isFocused) {
        focusedWindowIndex = i;
        return;
      }
    }
    for (let i = 0; i < windows.length; i++) {
      if (windows[i].isActive) {
        focusedWindowIndex = i;
        return;
      }
    }
  }

  function getActiveWindow() {
    for (let i = 0; i < windows.length; i++) {
      if (windows[i].isFocused)
        return windows[i];
    }
    for (let i = 0; i < windows.length; i++) {
      if (windows[i].isActive)
        return windows[i];
    }
    return null;
  }

  function publishOutputs() {
    if (CompositorService && CompositorService.onDisplayScalesUpdated)
      CompositorService.onDisplayScalesUpdated(outputCache);
  }

  function action(name, argument) {
    const args = ["umbriel", "msg", argument === undefined ? name : name + ":" + String(argument)];
    Quickshell.execDetached(args);
  }

  function switchToWorkspace(workspace) {
    if (!workspace)
      return;
    const selector = workspace.named === true ? workspace.name : String(workspace.index || workspace.idx || workspace.id);
    const output = workspace.output ? "/" + workspace.output : "";
    action("workspace-switch", selector + output);
  }

  function focusWindow(window) {
    if (window && window.id !== undefined)
      action("window-focus", window.id);
  }

  function closeWindow(window) {
    if (window && window.id !== undefined)
      action("window-close", window.id);
  }

  function focusWindowByAddress(id) {
    action("window-focus", id);
  }

  function closeWindowByAddress(id) {
    action("window-close", id);
  }

  function moveWindowToWorkspace(id, workspace) {
    const selector = workspace && typeof workspace === "object" ? (workspace.named ? workspace.name : (workspace.index || workspace.idx || workspace.id)) : workspace;
    action("window-move-to-workspace", String(selector));
  }

  function spawn(command) {
    const parts = Array.isArray(command) ? command : [command];
    const escaped = parts.map(part => "'" + String(part).replace(/'/g, "'\\''") + "'").join(" ");
    action("spawn", escaped);
  }

  function turnOffMonitors() {
    action("dpms-off");
  }

  function turnOnMonitors() {
    action("dpms-on");
  }

  function logout() {
    action("session-quit");
  }

  function getFocusedScreen() {
    const focused = focusedWindowIndex >= 0 ? windows[focusedWindowIndex] : null;
    const output = focused ? focused.output : "";
    const screens = Quickshell.screens || [];
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === output)
        return screens[i];
    }
    return screens.length ? screens[0] : null;
  }
}
