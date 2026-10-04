.pragma library

// Umbriel events are complete snapshots. IDs are opaque, never workspace indices.
function workspaces(entries) {
  return entries.map(entry => ({
    id: String(entry.id), handle: String(entry.id),
    index: entry.index, idx: entry.index, name: entry.name,
    named: entry.named === true, output: entry.output, layout: entry.layout,
    isActive: entry.active === true, isFocused: entry.focused === true,
    isOccupied: entry.occupied === true, isUrgent: false
  }));
}

function focusedOutput(entries) {
  const focused = entries.find(entry => entry.isFocused);
  return focused ? focused.output : "";
}

function windows(entries, workspaceCache) {
  return entries.map(entry => {
    const workspace = workspaceCache[entry.workspace];
    return {
      id: String(entry.id), handle: String(entry.id), title: entry.title || "",
      appId: entry.app_id || "", workspaceId: entry.workspace || "",
      workspaceHandle: entry.workspace || "", output: workspace ? workspace.output : (entry.output || ""),
      // focused is per-workspace in Umbriel; active is global keyboard focus.
      isFocused: entry.active === true, isActive: entry.active === true,
      x: entry.x, y: entry.y, w: entry.w, h: entry.h,
      width: entry.w, height: entry.h, position: { x: entry.x, y: entry.y },
      floating: entry.floating === true, scratchpad: entry.scratchpad || "",
      tabbed: entry.tabbed === true, tabIndex: entry.tab_index ?? -1,
      tabHidden: entry.tab_hidden === true, mapped: entry.mapped !== false
    };
  });
}

function submap(data) {
  return typeof data === "string" ? data : "";
}

function outputs(entries) {
  return entries.map(entry => {
    const output = {
      name: entry.name, enabled: entry.enabled, position: entry.position,
      scale: entry.scale, transform: entry.transform, modes: entry.modes,
      adaptiveSync: entry.adaptive_sync, description: entry.description,
      configName: entry.config_name
    };
    const mode = (entry.modes || []).find(mode => mode.current);
    if (mode) {
      output.width = mode.width;
      output.height = mode.height;
      output.refresh = mode.refresh_mhz / 1000;
    }
    return output;
  });
}

function keyboardLayout(data) {
  return Array.isArray(data.names) && Number.isInteger(data.current_index)
      ? (data.names[data.current_index] || "") : "";
}

function workspaceSelector(workspace) {
  const selector = workspace.named ? workspace.name : String(workspace.index || workspace.idx);
  return selector + (workspace.output ? "/" + workspace.output : "");
}
