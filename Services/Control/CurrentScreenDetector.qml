import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor

Item {
  function findScreenWithBar() {
    const monitors = Settings.data.bar.monitors || [];
    const screens = Quickshell.screens || [];
    const candidates = screens.filter(screen => monitors.length === 0 || monitors.includes(screen.name));
    return candidates.find(screen => screen.x === 0 && screen.y === 0) || candidates[0] || screens[0] || null;
  }

  // Umbriel workspace focus is authoritative even on an empty workspace.
  function withCurrentScreen(callback, skipBarCheck) {
    let screen = CompositorService.getFocusedScreen() || findScreenWithBar();
    if (!skipBarCheck && !Settings.data.general.allowPanelsOnScreenWithoutBar) {
      const monitors = Settings.data.bar.monitors || [];
      if (screen && monitors.length && !monitors.includes(screen.name))
        screen = findScreenWithBar();
    }
    callback(screen);
  }
}
