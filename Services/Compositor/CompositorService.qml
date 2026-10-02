pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Control

Singleton {
  id: root

  readonly property bool isUmbriel: !!Quickshell.env("UMBRIEL_SOCKET") ||
    (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase() === "umbriel" ||
    (Quickshell.env("XDG_SESSION_DESKTOP") || "").toLowerCase() === "umbriel"
  readonly property UmbrielService backend: UmbrielService {}
  readonly property ListModel workspaces: backend.workspaces
  property ListModel windows: ListModel {}
  readonly property int focusedWindowIndex: backend.focusedWindowIndex
  readonly property var displayScales: backend.outputCache
  readonly property bool displayScalesLoaded: backend.outputs.length > 0
  readonly property bool overviewActive: backend.overviewActive
  readonly property string keyboardLayout: backend.keyboardLayout
  readonly property string focusedOutputName: backend.focusedOutputName

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged

  Component.onCompleted: {
    if (isUmbriel)
      backend.initialize();
    else
      Logger.e("CompositorService", "Unsupported session: Hydra requires Umbriel; compositor IPC is disabled");
  }

  Connections {
    target: root.backend
    function onWorkspaceChanged() {
      root.workspacesChanged();
      root.workspaceChanged();
    }
    function onWindowListChanged() {
      root.windows.clear();
      for (const window of root.backend.windows)
        root.windows.append(window);
      root.windowListChanged();
    }
    function onActiveWindowChanged() { root.activeWindowChanged(); }
  }

  function updateDisplayScales() { if (isUmbriel) backend.queryDisplayScales(); }
  function getDisplayInfo(name) { return displayScales[name] || null; }
  function getDisplayScale(name) {
    return displayScales[name]?.scale || (Quickshell.screens || []).find(screen => screen.name === name)?.devicePixelRatio || 1;
  }
  function getFocusedScreen() { return backend.getFocusedScreen(); }
  function getFocusedWindow() { return backend.getActiveWindow(); }
  function getActiveWindow() { return backend.getActiveWindow(); }
  function getWindowList() { return backend.windows; }
  function getFocusedWindowTitle() { return (getFocusedWindow()?.title || "").replace(/[\r\n]/g, ""); }
  function getCleanAppName(appId, fallbackTitle) {
    const name = (appId || "").split(".").pop() || fallbackTitle || "Unknown";
    return name.charAt(0).toUpperCase() + name.slice(1);
  }
  function getWindowsForWorkspace(id) {
    return backend.windows.filter(window => window.workspaceId === id);
  }
  function getCurrentWorkspace() {
    for (let i = 0; i < workspaces.count; i++) {
      if (workspaces.get(i).isFocused)
        return workspaces.get(i);
    }
    return null;
  }
  function getActiveWorkspaces() {
    const active = [];
    for (let i = 0; i < workspaces.count; i++) {
      if (workspaces.get(i).isActive)
        active.push(workspaces.get(i));
    }
    return active;
  }

  function switchToWorkspace(workspace) { backend.switchToWorkspace(workspace); }
  function focusWindow(window) { backend.focusWindow(window); }
  function closeWindow(window) { backend.closeWindow(window); }
  function moveWindowToWorkspace(id, workspace) { if (isUmbriel) backend.moveWindowToWorkspace(id, workspace); }
  function focusWindowByAddress(id) { backend.focusWindowByAddress(id); }
  function closeWindowByAddress(id) { backend.closeWindowByAddress(id); }
  function cycleKeyboardLayout() { backend.cycleKeyboardLayout(); }
  function turnOffMonitors() { backend.turnOffMonitors(); }
  function turnOnMonitors() { backend.turnOnMonitors(); }
  function openOverview() { backend.action("overview-open"); }
  function closeOverview() { backend.action("overview-close"); }
  function toggleOverview() { backend.action("overview-toggle"); }
  function spawn(command) {
    const parts = Array.isArray(command) ? command : (command && typeof command === "object" && command.length !== undefined) ? Array.from(command) : [command];
    backend.spawn(parts);
  }

  // Power actions remain OS-owned, including custom commands and existing hooks.
  function getCustomCommand(action) {
    for (const option of (Settings.data.sessionMenu.powerOptions || [])) {
      if (option.action === action && option.enabled && option.command?.trim())
        return option.command.trim();
    }
    return "";
  }
  function executeSessionAction(action) {
    const command = getCustomCommand(action);
    if (!command)
      return false;
    Quickshell.execDetached(["sh", "-c", command]);
    return true;
  }
  function logout() { if (!executeSessionAction("logout")) backend.logout(); }
  function shutdown() {
    if (!executeSessionAction("shutdown"))
      HooksService.executeSessionHook("shutdown", () => Quickshell.execDetached(["sh", "-c", "systemctl poweroff || loginctl poweroff"]));
  }
  function reboot() {
    if (!executeSessionAction("reboot"))
      HooksService.executeSessionHook("reboot", () => Quickshell.execDetached(["sh", "-c", "systemctl reboot || loginctl reboot"]));
  }
  function userspaceReboot() {
    if (!executeSessionAction("userspaceReboot"))
      HooksService.executeSessionHook("userspaceReboot", () => Quickshell.execDetached(["systemctl", "soft-reboot"]));
  }
  function rebootToUefi() {
    if (!executeSessionAction("rebootToUefi"))
      HooksService.executeSessionHook("rebootToUefi", () => Quickshell.execDetached(["sh", "-c", "systemctl reboot --firmware-setup || loginctl reboot --firmware-setup"]));
  }
  function suspend() {
    if (!executeSessionAction("suspend"))
      Quickshell.execDetached(["sh", "-c", "systemctl suspend || loginctl suspend"]);
  }
  function hibernate() {
    if (!executeSessionAction("hibernate"))
      Quickshell.execDetached(["sh", "-c", "systemctl hibernate || loginctl hibernate"]);
  }
  function lock() {
    if (!executeSessionAction("lock"))
      Quickshell.execDetached(["loginctl", "lock-session"]);
  }
  function lockAndSuspend() {
    if (executeSessionAction("lock"))
      suspend();
    else
      Quickshell.execDetached(["sh", "-c", "loginctl lock-session && (systemctl suspend || loginctl suspend)"]);
  }
}
