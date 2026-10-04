.pragma library

function history(previous, windows, focusedId) {
  const live = new Set(windows.map(window => window.id));
  const seen = new Set();
  const next = [];
  if (focusedId && live.has(focusedId)) {
    next.push(focusedId);
    seen.add(focusedId);
  }
  for (const id of previous) {
    if (live.has(id) && !seen.has(id)) {
      next.push(id);
      seen.add(id);
    }
  }
  return next;
}

function candidates(windows, options, output, workspace, mru) {
  const eligible = windows.filter(window => window.id && !window.scratchpad && !window.tabHidden
      && (window.mapped !== false)
      && (options.showAllOutputs || window.output === output)
      && (!options.currentWorkspaceOnly || window.workspaceId === workspace));
  if (options.mru) {
    const ranks = new Map(mru.map((id, index) => [id, index]));
    eligible.sort((a, b) => (ranks.get(a.id) ?? mru.length) - (ranks.get(b.id) ?? mru.length));
  }
  return eligible;
}

function cycle(index, count, direction) {
  return count ? ((index + direction) % count + count) % count : -1;
}

function initial(windows, focusedId, direction) {
  if (!windows.length) return -1;
  const index = windows.findIndex(window => window.id === focusedId);
  return index < 0 ? (direction < 0 ? windows.length - 1 : 0) : cycle(index, windows.length, direction);
}

function reconcile(windows, selectedId, previousIndex) {
  const index = windows.findIndex(window => window.id === selectedId);
  return index >= 0 ? index : (windows.length ? Math.min(Math.max(0, previousIndex), windows.length - 1) : -1);
}

// Shift chooses direction, never owns the lifetime of a held shortcut.
function release(held, current, expected) {
  const mask = held || expected;
  return mask !== 0 && (current & mask) !== mask;
}
