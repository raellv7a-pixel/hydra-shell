pragma Singleton

import QtQuick
import Quickshell
import "WindowSwitcherState.js" as State
import qs.Commons
import qs.Services.Compositor

Singleton {
  id: root
  property bool active: false
  property var entries: []
  property int selectedIndex: -1
  property var mruIds: []
  property var screen: null
  property string workspaceId: ""
  property bool holding: false
  property int heldModifiers: 0
  property int expectedModifiers: Qt.AltModifier
  property int generation: 0
  readonly property var options: Settings.data.umbriel.windowSwitcher
  readonly property var selectedWindow: entries[selectedIndex] || null

  function initialize() {
    refresh();
  }
  function refresh() {
    const windows = CompositorService.getWindowList();
    const focus = CompositorService.getFocusedWindow()?.id || "";
    mruIds = State.history(mruIds, windows, active ? "" : focus);
    if (!active)
      return;
    const selectedId = selectedWindow?.id || "";
    entries = State.candidates(windows, options, screen?.name || "", workspaceId, mruIds);
    selectedIndex = State.reconcile(entries, selectedId, selectedIndex);
    if (!entries.length)
      close();
  }
  function open(hold = false, direction = 1) {
    if (PanelService.lockScreen?.active || !CompositorService.isUmbriel)
      return;
    if (active) {
      cycle(direction);
      return;
    }
    refresh();
    screen = CompositorService.getFocusedScreen();
    if (!screen)
      return;
    workspaceId = CompositorService.getCurrentWorkspace()?.id || "";
    entries = State.candidates(CompositorService.getWindowList(), options, screen.name, workspaceId, mruIds);
    if (!entries.length)
      return;
    const focusedId = CompositorService.getFocusedWindow()?.id || mruIds[0] || "";
    selectedIndex = State.initial(entries, focusedId, direction);
    holding = hold;
    heldModifiers = 0;
    generation++;
    PanelService.closePanel();
    for (const output of Quickshell.screens)
      PanelService.closeContextMenu(output);
    active = true;
  }
  function cycle(direction) {
    if (active)
      selectedIndex = State.cycle(selectedIndex, entries.length, direction);
  }
  function select(index) {
    if (active && index >= 0 && index < entries.length)
      selectedIndex = index;
  }
  function close() {
    active = false;
    holding = false;
    heldModifiers = 0;
    entries = [];
    selectedIndex = -1;
    screen = null;
    generation++;
    refresh();
  }
  function confirm() {
    const id = selectedWindow?.id;
    // Never activate an ID removed while the overlay was open.
    const window = CompositorService.getWindowList().find(entry => entry.id === id);
    close();
    if (window)
      CompositorService.focusWindow(window);
  }
  function modifiersChecked(modifiers, token) {
    if (!active || !holding || token !== generation)
      return;
    const mask = modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier);
    if (!heldModifiers && mask) {
      heldModifiers = mask;
      return;
    }
    if (State.release(heldModifiers, mask, expectedModifiers))
      confirm();
  }
  Connections {
    target: CompositorService
    function onWindowListChanged() {
      root.refresh();
    }
    function onActiveWindowChanged() {
      root.refresh();
    }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.active && !Quickshell.screens.some(output => output.name === root.screen?.name))
        root.close();
    }
  }
}
