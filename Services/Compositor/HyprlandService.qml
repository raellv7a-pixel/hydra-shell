import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Services.Keyboard

Item {
  id: root

  // Properties that match the facade interface
  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1

  // Signals that match the facade interface
  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  // Hyprland-specific properties
  property bool initialized: false
  property var workspaceCache: ({})
  property var windowCache: ({})
  property bool screenshareActive: false
  property int screenshareCount: 0
  property var urgentAddresses: ({})
  property var recentWorkspaces: []
  property string currentLayout: "dwindle"
  // Dispatch compatibility state
  property bool dispatchModeChecked: false
  property bool useLuaDispatch: false

  // Debounce timer for window updates
  Timer {
    id: updateTimer
    interval: 50
    repeat: false
    onTriggered: safeUpdate()
  }

  // Deferred via Qt.callLater to coalesce workspace updates: onRawEvent calls
  // refreshWorkspaces() which triggers onValuesChanged synchronously in the
  // same call stack — without deferral the ListModel gets cleared+repopulated
  // twice per event. Qt.callLater deduplicates by function identity.
  function _deferredWorkspaceUpdate() {
    safeUpdateWorkspaces();
    workspaceChanged();
  }

  // Initialization
  function initialize() {
    if (initialized)
      return;
    try {
      Hyprland.refreshWorkspaces();
      Hyprland.refreshToplevels();
      Qt.callLater(() => {
                     safeUpdateWorkspaces();
                     safeUpdateWindows();
                     queryDisplayScales();
                     queryKeyboardLayout();
                     // Detect Hyprland dispatch syntax once during startup
                     detectDispatchMode();
                     reapplyWorkspacePrivacy();
                     if (Settings.data.workspaceManager.gameMode)
                     applyGameMode(true);
                   });
      initialized = true;
      Logger.i("HyprlandService", "Service started");
    } catch (e) {
      Logger.e("HyprlandService", "Failed to initialize:", e);
    }
  }

  // Query display scales
  function queryDisplayScales() {
    hyprlandMonitorsProcess.running = true;
  }

  // Hyprland monitors process for display scale detection
  Process {
    id: hyprlandMonitorsProcess
    running: false
    command: ["hyprctl", "monitors", "-j"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        // Accumulate lines instead of parsing each one
        hyprlandMonitorsProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandService", "Failed to query monitors, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const monitorsData = JSON.parse(accumulatedOutput);
        const scales = {};

        for (const monitor of monitorsData) {
          if (monitor.name) {
            scales[monitor.name] = {
              "name": monitor.name,
              "scale": monitor.scale || 1.0,
              "width": monitor.width || 0,
              "height": monitor.height || 0,
              "refresh_rate": monitor.refreshRate || 0,
              "x": monitor.x || 0,
              "y": monitor.y || 0,
              "active_workspace": monitor.activeWorkspace ? monitor.activeWorkspace.id : -1,
              "vrr": monitor.vrr || false,
              "focused": monitor.focused || false
            };
          }
        }

        // Notify CompositorService (it will emit displayScalesChanged)
        if (CompositorService && CompositorService.onDisplayScalesUpdated) {
          CompositorService.onDisplayScalesUpdated(scales);
        }
      } catch (e) {
        Logger.e("HyprlandService", "Failed to parse monitors:", e);
      } finally {
        // Clear accumulated output for next query
        accumulatedOutput = "";
      }
    }
  }

  // ------------------------------------------------------------
  // Dispatch mode probe
  // This Process detects whether hyprland is using legacy
  // hyprlang dispatch or the new Lua-based dispatch system
  // (Hyprland v0.55+)
  //
  // This runs a harmless dispatcher shown in the docs:
  // hl.dsp.no_op()
  // If it returns "ok", Lua dispatch is supported.
  // ------------------------------------------------------------
  Process {
    id: dispatchProbeProcess

    running: false
    command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]

    // Accumulate stdout/stderr because SplitParser delivers line-by-line
    property string accumulatedOutput: ""
    property string accumulatedError: ""

    stdout: SplitParser {
      onRead: function (line) {
        dispatchProbeProcess.accumulatedOutput += line;
      }
    }

    stderr: SplitParser {
      onRead: function (line) {
        dispatchProbeProcess.accumulatedError += line;
      }
    }

    onExited: function (exitCode) {
      const stdout = String(accumulatedOutput || "").trim();
      const stderr = String(accumulatedError || "").trim();

      // If Lua dispatch is supported, Hyprland returns "ok"
      const lowerErr = stderr.toLowerCase();
      useLuaDispatch = stdout.indexOf("ok") !== -1 && lowerErr.indexOf("error") === -1;

      dispatchModeChecked = true;

      Logger.i("HyprlandService", useLuaDispatch ? "Detected Lua hyprctl dispatch syntax" : "Using legacy hyprctl dispatch syntax");

      // Debug output as per guidelines / troubleshooting
      if (stdout.length > 0) {
        Logger.d("HyprlandService", "Dispatch probe stdout:", stdout);
      }

      if (stderr.length > 0) {
        Logger.d("HyprlandService", "Dispatch probe stderr:", stderr);
      }

      // Reset buffers for future runs
      accumulatedOutput = "";
      accumulatedError = "";
    }
  }

  function queryKeyboardLayout() {
    hyprlandDevicesProcess.running = true;
  }
  // Hyprland devices process for keyboard layout detection
  Process {
    id: hyprlandDevicesProcess
    running: false
    command: ["hyprctl", "devices", "-j"]

    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function (line) {
        // Accumulate lines instead of parsing each one
        hyprlandDevicesProcess.accumulatedOutput += line;
      }
    }

    onExited: function (exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandService", "Failed to query devices, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        const devicesData = JSON.parse(accumulatedOutput);
        for (const keyboard of devicesData.keyboards) {
          if (keyboard.main) {
            const layoutName = keyboard.active_keymap;
            KeyboardLayoutService.setCurrentLayout(layoutName);
            Logger.d("HyprlandService", "Keyboard layout switched:", layoutName);
          }
        }
      } catch (e) {
        Logger.e("HyprlandService", "Failed to parse devices:", e);
      } finally {
        // Clear accumulated output for next query
        accumulatedOutput = "";
      }
    }
  }

  // Safe update wrapper
  function safeUpdate() {
    safeUpdateWindows();
    safeUpdateWorkspaces();
    workspaceChanged();
    windowListChanged();
  }

  // Safe workspace update
  function safeUpdateWorkspaces() {
    try {
      workspaces.clear();
      workspaceCache = {};

      if (!Hyprland.workspaces || !Hyprland.workspaces.values) {
        return;
      }

      const hlWorkspaces = Hyprland.workspaces.values;
      const occupiedIds = getOccupiedWorkspaceIds();

      for (var i = 0; i < hlWorkspaces.length; i++) {
        const ws = hlWorkspaces[i];
        if (ws.name && ws.name.startsWith("special:"))
          continue;

        const wsData = {
          "id": ws.id,
          "idx": ws.id,
          "name": ws.name || "",
          "output": (ws.monitor && ws.monitor.name) ? ws.monitor.name : "",
          "isActive": ws.active === true,
          "isFocused": ws.focused === true,
          "isUrgent": ws.urgent === true,
          "isOccupied": occupiedIds[ws.id] === true
        };

        workspaceCache[ws.id] = wsData;
        workspaces.append(wsData);
      }
    } catch (e) {
      Logger.e("HyprlandService", "Error updating workspaces:", e);
    }
  }

  // Get occupied workspace IDs safely
  function getOccupiedWorkspaceIds() {
    const occupiedIds = {};

    try {
      if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
        return occupiedIds;
      }

      const hlToplevels = Hyprland.toplevels.values;
      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i];
        if (!toplevel)
          continue;
        try {
          const wsId = toplevel.workspace ? toplevel.workspace.id : null;
          if (wsId !== null && wsId !== undefined) {
            occupiedIds[wsId] = true;
          }
        } catch (e)

          // Ignore individual toplevel errors
        {}
      }
    } catch (e)

      // Return empty if we can't determine occupancy
    {}

    return occupiedIds;
  }

  // Safe window update
  function safeUpdateWindows() {
    try {
      const windowsList = [];
      windowCache = {};

      if (!Hyprland.toplevels || !Hyprland.toplevels.values) {
        windows = [];
        focusedWindowIndex = -1;
        return;
      }

      const hlToplevels = Hyprland.toplevels.values;
      let focusedWindowId = null;

      // Get active workspaces to filter focus
      const activeWorkspaceIds = {};
      if (Hyprland.workspaces && Hyprland.workspaces.values) {
        const hlWorkspaces = Hyprland.workspaces.values;
        for (var j = 0; j < hlWorkspaces.length; j++) {
          if (hlWorkspaces[j].active) {
            activeWorkspaceIds[hlWorkspaces[j].id] = true;
          }
        }
      }

      for (var i = 0; i < hlToplevels.length; i++) {
        const toplevel = hlToplevels[i];
        if (!toplevel)
          continue;
        const windowData = extractWindowData(toplevel);
        if (windowData) {
          // If the window claims to be focused, verify it's on an active workspace
          if (windowData.isFocused) {
            if (!activeWorkspaceIds[windowData.workspaceId]) {
              windowData.isFocused = false;
            }
          }

          // Normalize to a plain, backend-independent window object
          const normalized = {
            "id": windowData.id ? String(windowData.id) : "",
            "title": windowData.title ? String(windowData.title) : "",
            "appId": windowData.appId ? String(windowData.appId) : "",
            "workspaceId": (typeof windowData.workspaceId === "number" && !isNaN(windowData.workspaceId)) ? windowData.workspaceId : -1,
            "isFocused": windowData.isFocused === true,
            "output": windowData.output ? String(windowData.output) : "",
            "x": (typeof windowData.x === "number" && !isNaN(windowData.x)) ? windowData.x : 0,
            "y": (typeof windowData.y === "number" && !isNaN(windowData.y)) ? windowData.y : 0
          };

          windowsList.push(normalized);
          windowCache[normalized.id] = normalized;

          if (normalized.isFocused) {
            focusedWindowId = normalized.id;
          }
        }
      }

      windows = toSortedWindowList(windowsList);

      // Resolve focused index from sorted list (order changes after sort)
      let newFocusedIndex = -1;
      if (focusedWindowId) {
        for (let k = 0; k < windows.length; k++) {
          if (windows[k].id === focusedWindowId) {
            newFocusedIndex = k;
            break;
          }
        }
      }

      if (newFocusedIndex !== focusedWindowIndex) {
        focusedWindowIndex = newFocusedIndex;
        activeWindowChanged();
      }
    } catch (e) {
      Logger.e("HyprlandService", "Error updating windows:", e);
    }
  }

  // Extract window data safely from a toplevel
  function extractWindowData(toplevel) {
    if (!toplevel)
      return null;

    try {
      // Safely extract properties
      const windowId = safeGetProperty(toplevel, "address", "");
      if (!windowId)
        return null;

      const appId = getAppId(toplevel);
      const title = getAppTitle(toplevel);
      const wsId = toplevel.workspace ? toplevel.workspace.id : null;
      const focused = toplevel.activated === true;
      const output = toplevel.monitor?.name || "";

      // Extract position
      let x = 0;
      let y = 0;
      try {
        const ipcData = toplevel.lastIpcObject;
        if (ipcData && ipcData.at) {
          x = ipcData.at[0];
          y = ipcData.at[1];
        } else if (typeof toplevel.x !== 'undefined') {
          x = toplevel.x;
          y = toplevel.y;
        }
      } catch (e) {}

      // Normalize coordinates to safe numeric values
      const safeX = (typeof x === "number" && !isNaN(x)) ? x : 0;
      const safeY = (typeof y === "number" && !isNaN(y)) ? y : 0;

      return {
        "id": windowId,
        "title": title,
        "appId": appId,
        "workspaceId": wsId || -1,
        "isFocused": focused,
        "output": output,
        "x": safeX,
        "y": safeY
      };
    } catch (e) {
      return null;
    }
  }

  function toSortedWindowList(windowList) {
    return windowList.sort((a, b) => {
                             // Sort by workspace first (just in case they are mixed)
                             if (a.workspaceId !== b.workspaceId) {
                               return a.workspaceId - b.workspaceId;
                             }
                             // Then sort by X position (left to right)
                             if (a.x !== b.x) {
                               return a.x - b.x;
                             }
                             // Then sort by Y position (top to bottom)
                             if (a.y !== b.y) {
                               return a.y - b.y;
                             }
                             // Fallback to Window ID mapping
                             return a.id.localeCompare(b.id);
                           });
  }

  function getAppTitle(toplevel) {
    try {
      var title = toplevel.wayland.title;
      if (title)
        return title;
    } catch (e) {}

    return safeGetProperty(toplevel, "title", "");
  }

  function getAppId(toplevel) {
    if (!toplevel)
      return "";

    var appId = "";

    // Try the wayland object first!
    // From my (Lemmy) testing it works fine so we could probably get rid of all the other attempts below.
    // Leaving them in for now, just in case...
    try {
      appId = toplevel.wayland.appId;
      if (appId)
        return appId;
    } catch (e) {}

    // Try direct properties
    appId = safeGetProperty(toplevel, "class", "");
    if (appId)
      return appId;

    appId = safeGetProperty(toplevel, "initialClass", "");
    if (appId)
      return appId;

    appId = safeGetProperty(toplevel, "appId", "");
    if (appId)
      return appId;

    // Try lastIpcObject
    try {
      const ipcData = toplevel.lastIpcObject;
      if (ipcData) {
        return String(ipcData.class || ipcData.initialClass || ipcData.appId || ipcData.wm_class || "");
      }
    } catch (e) {}

    return "";
  }

  // Safe property getter
  function safeGetProperty(obj, prop, defaultValue) {
    try {
      const value = obj[prop];
      if (value !== undefined && value !== null) {
        return String(value);
      }
    } catch (e)

      // Property access failed
    {}
    return defaultValue;
  }

  function handleActiveLayoutEvent(ev) {
    try {
      let beforeParenthesis;
      const parenthesisPos = ev.lastIndexOf('(');

      if (parenthesisPos === -1) {
        beforeParenthesis = ev;
      } else {
        beforeParenthesis = ev.substring(0, parenthesisPos);
      }

      const layoutNameStart = beforeParenthesis.lastIndexOf(',') + 1;
      const layoutName = ev.substring(layoutNameStart);

      // Ignore bogus "error" layout reported by virtual keyboards (e.g. wtype)
      if (layoutName.toLowerCase() === "error") {
        Logger.d("HyprlandService", "Ignoring bogus 'error' layout from activelayout event");
        return;
      }

      KeyboardLayoutService.setCurrentLayout(layoutName);
      Logger.d("HyprlandService", "Keyboard layout switched:", layoutName);
    } catch (e) {
      Logger.e("HyprlandService", "Error handling activelayout:", e);
    }
  }

  // Connections to Hyprland
  Connections {
    target: Hyprland.workspaces
    enabled: initialized
    function onValuesChanged() {
      Qt.callLater(_deferredWorkspaceUpdate);
    }
  }

  Connections {
    target: Hyprland.toplevels
    enabled: initialized
    function onValuesChanged() {
      updateTimer.restart();
    }
  }

  Connections {
    target: Hyprland
    enabled: initialized
    function onRawEvent(event) {
      Hyprland.refreshWorkspaces();
      Hyprland.refreshToplevels();
      // Workspace and window updates are deferred — refreshWorkspaces()/
      // refreshToplevels() trigger onValuesChanged which also calls
      // Qt.callLater, so the deduplication coalesces into one update.
      Qt.callLater(_deferredWorkspaceUpdate);
      updateTimer.restart();

      const monitorsEvents = ["configreloaded", "monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"];

      if (monitorsEvents.includes(event.name)) {
        Qt.callLater(queryDisplayScales);
      }

      if (event.name === "configreloaded") {
        Qt.callLater(reapplyWorkspacePrivacy);
        if (Settings.data.workspaceManager.gameMode)
          Qt.callLater(() => applyGameMode(true));
      }

      if (event.name === "activelayout") {
        handleActiveLayoutEvent(event.data);
      }

      if (event.name === "screencastv2") {
        const parts = String(event.data || "").split(",");
        const state = parts.length > 0 ? parts[0].trim() : "0";
        screenshareCount = Math.max(0, screenshareCount + (state === "1" ? 1 : -1));
        screenshareActive = screenshareCount > 0;
      }

      if (event.name === "urgent") {
        const addr = normalizeWindowAddress(event.data);
        if (addr) {
          const map = Object.assign({}, urgentAddresses);
          map[addr] = true;
          urgentAddresses = map;
        }
      }

      if (event.name === "activewindowv2" || event.name === "closewindow") {
        const addr = normalizeWindowAddress(event.data);
        if (addr && urgentAddresses[addr]) {
          const map = Object.assign({}, urgentAddresses);
          delete map[addr];
          urgentAddresses = map;
        }
      }

      if (event.name === "workspacev2" || event.name === "activespecialv2") {
        const parts = String(event.data || "").split(",");
        const wsKey = parts.length > 1 ? parts[1].trim() : "";
        if (wsKey)
          recordRecentWorkspace(wsKey);
      }
    }
  }

  // Dispatch helpers
  function luaQuote(str) {
    return String(str).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r");
  }

  function normalizeWindowAddress(address) {
    const raw = String(address || "").trim();
    if (!raw)
      return "";
    return raw.startsWith("0x") ? raw : `0x${raw}`;
  }

  // ------------------------------------------------------------
  // Triggers dispatch mode detection (once per session)
  //
  // Starts probe process if it hasn't already run
  // ------------------------------------------------------------
  function detectDispatchMode() {
    // Avoid duplicate probes
    if (dispatchModeChecked || dispatchProbeProcess.running) {
      return;
    }

    Logger.i("HyprlandService", "Checking hyprctl dispatch syntax");
    dispatchProbeProcess.running = true;
  }

  function dispatchCommand(legacyDispatcher, legacyArgs, luaCommand) {
    try {
      // Ensure dispatch mode is known before sending commands.
      if (!dispatchModeChecked) {
        Logger.w("HyprlandService", "Dispatch mode not detected yet, using legacy syntax");
      }
      const legacyFull = legacyArgs ? `${legacyDispatcher} ${legacyArgs}` : legacyDispatcher;

      if (useLuaDispatch) {
        Logger.d("HyprlandService", "Dispatch (Lua):", luaCommand);

        Quickshell.execDetached(["hyprctl", "dispatch", luaCommand]);
      } else {
        Logger.d("HyprlandService", "Dispatch (Legacy):", legacyFull);

        Hyprland.dispatch(legacyFull);
      }
    } catch (e) {
      Logger.e("HyprlandService", "Dispatch failed:", legacyDispatcher, legacyArgs, e);
    }
  }

  // Public functions
  function switchToWorkspace(workspace) {
    try {
      if (workspace.name) {
        dispatchCommand("workspace", workspace.name, `hl.dsp.focus({ workspace = "${luaQuote(workspace.name)}" })`);
        return;
      }

      dispatchCommand("workspace", workspace.idx, `hl.dsp.focus({ workspace = ${workspace.idx} })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to switch workspace:", e);
    }
  }

  function focusWindow(window) {
    try {
      if (!window || !window.id) {
        Logger.w("HyprlandService", "Invalid window object for focus");
        return;
      }

      const windowId = window.id.toString();
      const addr = `address:0x${windowId}`;

      dispatchCommand("focuswindow", addr, `hl.dsp.focus({ window = "${luaQuote(addr)}" })`);

      dispatchCommand("alterzorder", `top,${addr}`, `hl.dsp.window.alter_zorder({ mode = "top", window = "${luaQuote(addr)}" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to switch window:", e);
    }
  }

  function focusWindowByAddress(address) {
    const normalizedAddress = normalizeWindowAddress(address);
    if (!normalizedAddress)
      return;
    const selector = `address:${normalizedAddress}`;
    dispatchCommand("focuswindow", selector, `hl.dsp.focus({ window = "${luaQuote(selector)}" })`);
  }

  function closeWindow(window) {
    try {
      const addr = `address:0x${window.id}`;

      dispatchCommand("killwindow", addr, `hl.dsp.window.close("${luaQuote(addr)}")`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to close window:", e);
    }
  }

  function moveWindowToWorkspace(address, workspace) {
    try {
      if (!address || !workspace) {
        Logger.w("HyprlandService", "Invalid window or workspace for move");
        return;
      }

      const normalizedAddress = normalizeWindowAddress(address);
      const addressSelector = `address:${normalizedAddress}`;
      const workspaceName = workspace.name ? String(workspace.name) : "";
      const workspaceTarget = workspaceName ? (workspaceName.startsWith("special:") ? workspaceName : `name:${workspaceName}`) : String(workspace.idx);
      const luaWorkspace = workspaceName ? `"${luaQuote(workspaceTarget)}"` : String(workspace.idx);

      dispatchCommand("movetoworkspacesilent", `${workspaceTarget},${addressSelector}`, `hl.dsp.window.move({ workspace = ${luaWorkspace}, window = "${luaQuote(addressSelector)}" })`);
      Hyprland.refreshToplevels();
      Hyprland.refreshWorkspaces();
    } catch (e) {
      Logger.e("HyprlandService", "Failed to move window:", e);
    }
  }

  function closeWindowByAddress(address) {
    try {
      if (!address)
        return;
      const normalizedAddress = normalizeWindowAddress(address);
      const addressSelector = `address:${normalizedAddress}`;
      dispatchCommand("killwindow", addressSelector, `hl.dsp.window.close({ window = "${luaQuote(addressSelector)}" })`);
      Hyprland.refreshToplevels();
      Hyprland.refreshWorkspaces();
    } catch (e) {
      Logger.e("HyprlandService", "Failed to close window by address:", e);
    }
  }

  function workspacePrivacyKey(workspace) {
    if (!workspace)
      return "";
    if (workspace.name !== undefined && workspace.name !== "")
      return String(workspace.name);
    if (workspace.idx !== undefined)
      return String(workspace.idx);
    if (workspace.id !== undefined)
      return String(workspace.id);
    return "";
  }

  function workspacePrivacySelector(workspaceKey) {
    const key = String(workspaceKey);
    if (key.startsWith("special:") || /^\d+$/.test(key) || key.startsWith("name:"))
      return key;
    return `name:${key}`;
  }

  function workspacePrivacyRuleId(workspaceKey) {
    let encoded = "";
    const key = String(workspaceKey);
    for (let index = 0; index < key.length; index++)
      encoded += key.charCodeAt(index).toString(16) + "_";
    return `workspace_${encoded}`;
  }

  function isWorkspacePrivate(workspace) {
    const key = workspacePrivacyKey(workspace);
    const privateWorkspaces = Settings.data.workspaceManager.privateWorkspaces || [];
    return key !== "" && privateWorkspaces.includes(key);
  }

  function applyWorkspacePrivacyRule(workspaceKey, enabled) {
    if (!workspaceKey)
      return;

    const ruleId = workspacePrivacyRuleId(workspaceKey);
    const selector = workspacePrivacySelector(workspaceKey);
    let lua = "hydra_shell_private_workspace_rules = hydra_shell_private_workspace_rules or {}; ";
    lua += `local current = hydra_shell_private_workspace_rules["${luaQuote(ruleId)}"]; `;
    lua += "if current then current:set_enabled(false) end; ";
    if (enabled) {
      lua += `hydra_shell_private_workspace_rules["${luaQuote(ruleId)}"] = hl.window_rule({ `;
      lua += `name = "hydra-shell-private-${luaQuote(ruleId)}", `;
      lua += `match = { workspace = "${luaQuote(selector)}" }, no_screen_share = true });`;
    } else {
      lua += `hydra_shell_private_workspace_rules["${luaQuote(ruleId)}"] = nil;`;
    }
    Quickshell.execDetached(["hyprctl", "repl", lua]);

    const toplevels = Hyprland.toplevels.values || [];
    for (let index = 0; index < toplevels.length; index++) {
      const ipc = toplevels[index]?.lastIpcObject;
      if (!ipc?.address || ipc.workspace?.name !== workspaceKey)
        continue;
      const address = String(ipc.address).startsWith("0x") ? String(ipc.address) : `0x${ipc.address}`;
      Quickshell.execDetached(["hyprctl", "setprop", `address:${address}`, "no_screen_share", enabled ? "1" : "unset"]);
    }
  }

  function setWorkspacePrivate(workspace, enabled) {
    const key = workspacePrivacyKey(workspace);
    if (!key)
      return false;

    const current = Array.from(Settings.data.workspaceManager.privateWorkspaces || []);
    const next = current.filter(item => item !== key);
    if (enabled)
      next.push(key);
    Settings.data.workspaceManager.privateWorkspaces = next;
    applyWorkspacePrivacyRule(key, enabled);
    return true;
  }

  function reapplyWorkspacePrivacy() {
    const privateWorkspaces = Array.from(Settings.data.workspaceManager.privateWorkspaces || []);
    let lua = "if hydra_shell_private_workspace_rules then ";
    lua += "for _, rule in pairs(hydra_shell_private_workspace_rules) do rule:set_enabled(false) end end; ";
    lua += "hydra_shell_private_workspace_rules = {}; ";
    for (let index = 0; index < privateWorkspaces.length; index++) {
      const key = privateWorkspaces[index];
      const ruleId = workspacePrivacyRuleId(key);
      const selector = workspacePrivacySelector(key);
      lua += `hydra_shell_private_workspace_rules["${luaQuote(ruleId)}"] = hl.window_rule({ `;
      lua += `name = "hydra-shell-private-${luaQuote(ruleId)}", `;
      lua += `match = { workspace = "${luaQuote(selector)}" }, no_screen_share = true }); `;
    }
    Quickshell.execDetached(["hyprctl", "repl", lua]);
  }

  Connections {
    target: Settings
    function onSettingsLoaded() {
      Qt.callLater(root.reapplyWorkspacePrivacy);
    }
    function onSettingsReloaded() {
      Qt.callLater(root.reapplyWorkspacePrivacy);
    }
  }

  function turnOffMonitors() {
    try {
      dispatchCommand("dpms", "off", `hl.dsp.dpms({ action = "off" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to turn off monitors:", e);
    }
  }

  function turnOnMonitors() {
    try {
      dispatchCommand("dpms", "on", `hl.dsp.dpms({ action = "on" })`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to turn on monitors:", e);
    }
  }

  function logout() {
    try {
      dispatchCommand("exit", "", "hl.dsp.exit()");
    } catch (e) {
      Logger.e("HyprlandService", "Failed to logout:", e);
    }
  }

  function cycleKeyboardLayout() {
    try {
      Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to cycle keyboard layout:", e);
    }
  }

  function recordRecentWorkspace(wsKey) {
    if (!wsKey)
      return;
    const list = Array.from(recentWorkspaces || []);
    const idx = list.indexOf(wsKey);
    if (idx !== -1)
      list.splice(idx, 1);
    list.unshift(wsKey);
    if (list.length > 8)
      list.pop();
    recentWorkspaces = list;
  }

  function focusRecentWorkspace() {
    const list = Array.from(recentWorkspaces || []);
    if (list.length > 1) {
      const target = list[1];
      if (/^\d+$/.test(target))
        switchToWorkspace({
                            "idx": parseInt(target)
                          });
      else
        switchToWorkspace({
                            "name": target
                          });
    }
  }

  function cycleWorkspaceLayout(workspaceKey) {
    const layouts = ["dwindle", "master", "scrolling"];
    const key = String(workspaceKey || "");
    const workspace = (Hyprland.workspaces.values || []).find(ws => String(ws.name) === key || String(ws.id) === key);
    const current = workspace?.lastIpcObject?.tiledLayout || workspace?.tiledLayout || "dwindle";
    const nextIdx = (layouts.indexOf(current) + 1) % layouts.length;
    const nextLayout = layouts[nextIdx];
    currentLayout = nextLayout;
    const selector = key.startsWith("special:") || /^\d+$/.test(key) ? key : `name:${key}`;
    const ruleId = workspacePrivacyRuleId(`layout_${key}`);
    let lua = "hydra_shell_workspace_layout_rules = hydra_shell_workspace_layout_rules or {}; ";
    lua += `local current = hydra_shell_workspace_layout_rules["${luaQuote(ruleId)}"]; `;
    lua += "if current then current:set_enabled(false) end; ";
    lua += `hydra_shell_workspace_layout_rules["${luaQuote(ruleId)}"] = hl.workspace_rule({ `;
    lua += `workspace = "${luaQuote(selector)}", layout = "${luaQuote(nextLayout)}" });`;
    Quickshell.execDetached(["hyprctl", "repl", lua]);
    refreshWorkspaceTimer.restart();
  }

  // hyprctl keyword is rejected outright when Hyprland runs its Lua config
  // ("keyword can't work with non-legacy parsers. Use eval.", confirmed live
  // against Hyprland 0.56.2) — this silently no-op'd on any Lua-config
  // install; hyprctl eval + hl.config(...) is the only live-apply path that
  // works in both modes. See PLANO_INTEGRACAO_HYPRMOD.md for the same class
  // of fix applied to MonitorService/HyprlandBackend.js.
  function applyGameMode(enabled) {
    if (enabled) {
      Quickshell.execDetached(["hyprctl", "eval", " hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0 } })"]);
    } else {
      Quickshell.execDetached(["hyprctl", "reload"]);
    }
  }

  Timer {
    id: refreshWorkspaceTimer
    interval: 100
    onTriggered: Hyprland.refreshWorkspaces()
  }

  function createSpecialWorkspace(name, isPrivate, launchCmd) {
    const cleanName = String(name || "").trim().replace(/^special:/, "");
    if (!cleanName)
      return;
    const wsName = "special:" + cleanName;
    const workspace = {
      "name": wsName
    };
    if (isPrivate)
      setWorkspacePrivate(workspace, true);
    if (launchCmd && launchCmd.trim()) {
      const ruleId = workspacePrivacyRuleId(`autolaunch_${wsName}`);
      let lua = "hydra_shell_workspace_launch_rules = hydra_shell_workspace_launch_rules or {}; ";
      lua += `local current = hydra_shell_workspace_launch_rules["${luaQuote(ruleId)}"]; `;
      lua += "if current then current:set_enabled(false) end; ";
      lua += `hydra_shell_workspace_launch_rules["${luaQuote(ruleId)}"] = hl.workspace_rule({ `;
      lua += `workspace = "${luaQuote(wsName)}", on_created_empty = "${luaQuote(launchCmd.trim())}" });`;
      Quickshell.execDetached(["hyprctl", "repl", lua]);
    }
    switchToWorkspace(workspace);
  }
  function getFocusedScreen() {
    const hyprMon = Hyprland.focusedMonitor;
    if (hyprMon) {
      const monitorName = hyprMon.name;
      for (let i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === monitorName) {
          return Quickshell.screens[i];
        }
      }
    }
    return null;
  }

  function spawn(command) {
    try {
      const cmd = command instanceof Array ? command.join(" ") : String(command);

      dispatchCommand("exec", cmd, `hl.dsp.exec_cmd("${luaQuote(cmd)}")`);
    } catch (e) {
      Logger.e("HyprlandService", "Failed to spawn command:", e);
    }
  }
}
