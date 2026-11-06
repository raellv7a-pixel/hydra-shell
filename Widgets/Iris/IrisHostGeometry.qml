pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Compositor

// Original iNiR surfaces receive an explicit host windowOffset. Qt Wayland
// toplevel positions are synthetic; adapt that input to Umbriel's existing stream.
Singleton {
  id: root

  function screenFor(window: var): var {
    if (!window) return null;
    return window.screen ?? (window instanceof PopupWindow ? root.screenFor(window.anchor.window ?? window.parentWindow) : null);
  }

  function globalOrigin(window: var): var {
    if (!window) return null;
    void window.windowTransform;
    if (window instanceof PopupWindow) {
      const parent = window.anchor.window ?? window.parentWindow;
      const origin = root.globalOrigin(parent);
      if (!origin || !parent?.contentItem) return null;
      // Qt does know the popup's configured displacement, including flip/slide.
      const popupQt = window.contentItem.mapToGlobal(0, 0);
      const parentQt = parent.contentItem.mapToGlobal(0, 0);
      return Qt.point(origin.x + popupQt.x - parentQt.x, origin.y + popupQt.y - parentQt.y);
    }
    if (window instanceof PanelWindow) {
      const namespace = window.WlrLayershell.namespace;
      const screen = root.screenFor(window);
      const layer = (CompositorService.backend?.layers ?? []).find(entry => entry.mapped && entry.pid === Quickshell.processId && entry.namespace === namespace && entry.output === screen?.name);
      return layer ? Qt.point(layer.x, layer.y) : null;
    }
    // Floating hosts explicitly bind their native identity. An unknown host uses
    // solid material, like the original iNiR floating Settings host, not guessed UVs.
    return window.materialGlobalOrigin ?? null;
  }

  function scenePoint(item: Item, x: real, y: real): var {
    const window = item.QsWindow.window;
    const origin = root.globalOrigin(window);
    const screen = root.screenFor(window);
    if (!origin || !screen) return null;
    const local = item.mapToItem(null, x, y);
    return Qt.point(origin.x + local.x - screen.x, origin.y + local.y - screen.y);
  }
}
