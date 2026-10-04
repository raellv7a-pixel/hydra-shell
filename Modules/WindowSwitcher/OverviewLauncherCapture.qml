pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Scope {
  id: root
  property bool handingOff: false
  // The installed Umbriel routes badges only when no layer owns the keyboard.
  // Preserve native shortcut ownership instead of silently swallowing them.
  readonly property bool available: UmbrielSettingsStore.loaded && !UmbrielSettingsStore.busy && !UmbrielSettingsStore.dirty && !UmbrielSettingsStore.error && !UmbrielSettingsStore.externallyOwned && !(UmbrielSettingsStore.committed.overview?.shortcuts ?? true)
  readonly property bool capturing: Settings.isLoaded && Settings.data.umbriel.typeToLaunch && available && CompositorService.overviewActive && !PanelService.activePanel && !PanelService.closingPanel && !PanelService.overlayLauncherOpen && !WindowSwitcherService.active && !PanelService.lockScreen?.active
  Component.onCompleted: UmbrielSettingsStore.refresh()
  Connections {
    target: CompositorService
    function onOverviewActiveChanged() {
      if (CompositorService.overviewActive && !UmbrielSettingsStore.dirty)
        UmbrielSettingsStore.refresh();
      else
        root.handingOff = false;
    }
  }
  Variants {
    model: Quickshell.screens
    delegate: Loader {
      id: capture
      required property ShellScreen modelData
      active: root.capturing || (root.handingOff && Settings.data.umbriel.typeToLaunch && CompositorService.overviewActive && PanelService.launcherOpenedFromOverview)
      sourceComponent: PanelWindow {
        screen: capture.modelData
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        anchors {
          top: true
          left: true
        }
        mask: Region {}
        WlrLayershell.namespace: "hydra-overview-input-" + capture.modelData.name
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        Item {
          id: keyboard
          focus: true
          Keys.onPressed: event => {
                            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                            return;
                            if (event.key === Qt.Key_Left)
                            CompositorService.navigateOverview("left");
                            else if (event.key === Qt.Key_Right)
                            CompositorService.navigateOverview("right");
                            else if (event.key === Qt.Key_Up)
                            CompositorService.navigateOverview("up");
                            else if (event.key === Qt.Key_Down)
                            CompositorService.navigateOverview("down");
                            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            CompositorService.closeOverview();
                            else if (event.text && !/[\x00-\x1f\x7f]/.test(event.text)) {
                              if (root.handingOff) {
                                const screen = PanelService.overviewLauncherScreen;
                                if (PanelService.pendingLauncherSearch !== null)
                                PanelService.pendingLauncherSearch += event.text;
                                else
                                PanelService.setLauncherSearchText(screen, PanelService.getLauncherSearchText(screen) + event.text);
                              } else {
                                root.handingOff = true;
                                PanelService.openLauncherFromOverview(CompositorService.getFocusedScreen() || capture.modelData, event.text);
                              }
                            } else
                            return;
                            event.accepted = true;
                          }
        }
        Connections {
          target: keyboard.Window.window
          function onActiveChanged() {
            // Keep the old capture alive until the new window actually owns
            // input, buffering characters during the Wayland focus handoff.
            if (!keyboard.Window.window.active && root.handingOff)
              root.handingOff = false;
          }
        }
      }
    }
  }
}
