import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor
import qs.Widgets

FloatingWindow {
  id: root

  title: "Hydra"
  // A real toplevel window (FloatingWindow, not layer-shell) — resizing by
  // dragging an edge already works via the compositor, no maximumSize cap
  // and no custom chrome needed for it.
  minimumSize: Qt.size(900 * Style.uiScaleRatio, 600 * Style.uiScaleRatio)
  implicitWidth: Math.round(1280 * Style.uiScaleRatio)
  implicitHeight: Math.round(840 * Style.uiScaleRatio)
  color: "transparent"
  // Wayland deliberately reports synthetic toplevel positions to Qt.
  // Reuse Umbriel's existing reactive window snapshot, retaining its opaque ID.
  property string materialWindowId: ""
  readonly property var materialWindow: {
    const windows = CompositorService.getWindowList();
    return windows.find(w => w.id === root.materialWindowId && w.pid === Quickshell.processId)
        ?? windows.find(w => w.pid === Quickshell.processId && w.title === root.title)
        ?? null;
  }
  readonly property var materialGlobalOrigin: materialWindow ? Qt.point(materialWindow.x, materialWindow.y) : null
  function rememberMaterialWindow(): void {
    if (root.visible && root.materialWindow && root.materialWindowId !== root.materialWindow.id)
      root.materialWindowId = root.materialWindow.id;
  }
  onMaterialWindowChanged: Qt.callLater(root.rememberMaterialWindow)

  visible: false

  // Register with SettingsPanelService
  Component.onCompleted: {
    SettingsPanelService.settingsWindow = root;
  }

  property bool isInitialized: false

  // Navigate to a specific tab and optional subtab.
  // Works whether the window is already visible or just becoming visible.
  function navigateTo(tab, subTab) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = (subTab !== undefined && subTab !== null && subTab >= 0) ? subTab : -1;
    if (isInitialized) {
      settingsContent.navigateToTab(tabId, subTabId);
    } else {
      settingsContent.requestedTab = tabId;
      if (subTabId >= 0)
        settingsContent._pendingSubTab = subTabId;
      settingsContent.initialize();
      isInitialized = true;
      // Legacy tab bars reset to their first subtab. Grouped pages own their
      // expansion state and must not jump past their navigation chips on open.
      if (subTabId < 0 && settingsContent.activeTabContent && !settingsContent.activeTabContent.navigateToSettingsGroup)
        settingsContent.setSubTabIndex(0);
    }
  }

  // Navigate to a search result entry.
  // Works whether the window is already visible or just becoming visible.
  function navigateToEntry(entry) {
    if (isInitialized) {
      Qt.callLater(() => settingsContent.navigateToResult(entry));
    } else {
      settingsContent.requestedTab = entry.tab;
      settingsContent.initialize();
      Qt.callLater(() => settingsContent.navigateToResult(entry));
      isInitialized = true;
    }
  }

  // Sync visibility with service
  onVisibleChanged: {
    if (visible) {
      SettingsPanelService.isWindowOpen = true;
    } else {
      isInitialized = false;
      root.materialWindowId = "";
      SettingsPanelService.isWindowOpen = false;
    }
  }

  // Keyboard shortcuts
  Shortcut {
    sequence: "Escape"
    enabled: !PanelService.isKeybindRecording
    onActivated: SettingsPanelService.closeWindow()
  }

  Shortcut {
    sequence: "Ctrl+Tab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsContent.selectNextTab()
  }

  Shortcut {
    sequence: "Ctrl+Shift+Tab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsContent.selectPreviousTab()
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyUp || []
    Shortcut {
      sequence: modelData
      enabled: !PanelService.isKeybindRecording
      onActivated: {
        if (settingsContent.searchText.trim() !== "")
          settingsContent.searchSelectPrevious();
        else
          settingsContent.scrollUp();
      }
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyDown || []
    Shortcut {
      sequence: modelData
      enabled: !PanelService.isKeybindRecording
      onActivated: {
        if (settingsContent.searchText.trim() !== "")
          settingsContent.searchSelectNext();
        else
          settingsContent.scrollDown();
      }
    }
  }

  // Main content
  NMaterialSurface {
    anchors.fill: parent
    color: HydraColor.mSurfaceContainerLow
    backgroundOpacity: Settings.data.ui.panelBackgroundOpacity
    readingCards: true
    radius: Style.radiusL

    SettingsContent {
      id: settingsContent
      anchors.fill: parent
      screen: root.screen
      onCloseRequested: SettingsPanelService.closeWindow()
    }
  }
}
