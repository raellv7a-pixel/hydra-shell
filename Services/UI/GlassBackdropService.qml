pragma Singleton

import QtQuick
import Quickshell

// One wallpaper texture/blur per window, lent to its visible outer surfaces.
Singleton {
  id: root
  property var entries: []

  function find(window) {
    return entries.find(entry => entry.window === window) ?? null;
  }

  function registerSource(window, owner, source) {
    if (!window || !source)
      return;
    const existing = find(window);
    if (existing && (existing.owner !== owner || existing.source === source))
      return;
    entries = entries.filter(entry => entry.owner !== owner).concat([{window: window, owner: owner, source: source}]);
  }

  function unregisterSource(owner) {
    entries = entries.filter(entry => entry.owner !== owner);
  }
}
