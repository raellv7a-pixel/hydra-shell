import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Backgrounds" as Backgrounds

import qs.Commons

// All panels
import qs.Modules.Bar
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Audio
import qs.Modules.Panels.Battery
import qs.Modules.Panels.Bluetooth
import qs.Modules.Panels.Brightness
import qs.Modules.Panels.Changelog
import qs.Modules.Panels.Clock
import qs.Modules.Panels.ControlCenter
import qs.Modules.Panels.Dock
import qs.Modules.Panels.Launcher
import qs.Modules.Panels.Media
import qs.Modules.Panels.Network
import qs.Modules.Panels.NotificationHistory
import qs.Modules.Panels.ObsControl
import qs.Modules.Panels.Plugins
import qs.Modules.Panels.SessionMenu
import qs.Modules.Panels.Settings
import qs.Modules.Panels.SetupWizard
import qs.Modules.Panels.SystemStats
import qs.Modules.Panels.Tamagotchi
import qs.Modules.Panels.Tray
import qs.Modules.Panels.UsbDriveManager
import qs.Modules.Panels.Wallpaper
import qs.Modules.Polkit
import qs.Modules.ScreenShare
import qs.Modules.ScreenToolkit
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.UI

/**
* MainScreen - Single PanelWindow per screen that manages all panels and the bar
*/
PanelWindow {
  id: root

  Component.onCompleted: {
    Logger.d("MainScreen", "Initialized for screen:", screen?.name, "- Dimensions:", screen?.width, "x", screen?.height, "- Position:", screen?.x, ",", screen?.y);
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "noctalia-background-" + (screen?.name || "unknown")
  WlrLayershell.exclusionMode: ExclusionMode.Ignore // Don't reserve space - BarExclusionZone handles that
  WlrLayershell.keyboardFocus: {
    // No panel open anywhere: no keyboard focus needed
    if (!root.isAnyPanelOpen) {
      return WlrKeyboardFocus.None;
    }
    // Panel open on THIS screen: use panel's preferred focus mode
    if (root.isPanelOpen) {
      // Hyprland's Exclusive captures ALL input globally (including pointer),
      // preventing click-to-close from working on other monitors.
      // Workaround: briefly use Exclusive when panel opens (for text input focus),
      // then switch to OnDemand (for click-to-close on other screens).
      if (CompositorService.isHyprland) {
        return PanelService.isInitializingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
      }
      return PanelService.activePanel.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand;
    }
    // Panel open on ANOTHER screen: OnDemand allows receiving pointer events for click-to-close
    return WlrKeyboardFocus.OnDemand;
  }

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // Desktop dimming when panels are open
  property real dimmerOpacity: Settings.data.general.dimmerOpacity ?? 0.8
  // A modal (polkit) stacks on top of openedPanel instead of replacing it, so
  // "is something on screen" has to consider both slots — the input mask and the
  // keyboard grab hang off these, and a modal-only state must still be clickable.
  readonly property bool hasOpenPanelHere: (PanelService.openedPanel !== null) && (PanelService.openedPanel.screen === screen)
  readonly property bool hasModalHere: (PanelService.modalPanel !== null) && (PanelService.modalPanel.screen === screen)
  property bool isPanelOpen: hasOpenPanelHere || hasModalHere
  property bool isPanelClosing: (PanelService.activePanel !== null) && PanelService.activePanel.isClosing
  property bool isAnyPanelOpen: (PanelService.openedPanel !== null) || (PanelService.modalPanel !== null)

  color: {
    if (dimmerOpacity > 0 && isPanelOpen && !isPanelClosing) {
      return Qt.alpha(Color.mShadow, dimmerOpacity);
    }
    return "transparent";
  }

  Behavior on color {
    enabled: !PanelService.closedImmediately
    ColorAnimation {
      duration: isPanelClosing ? Style.animationFaster : Style.animationNormal
      easing.type: Easing.OutQuad
    }
  }

  // Reset closedImmediately flag after color change is applied
  onColorChanged: {
    if (PanelService.closedImmediately) {
      PanelService.closedImmediately = false;
    }
  }

  // Check if bar should be visible on this screen
  readonly property bool barShouldShow: {
    // Check global bar visibility (includes overview state)
    if (!BarService.effectivelyVisible)
      return false;

    // Check screen-specific configuration
    var monitors = Settings.data.bar.monitors || [];
    var screenName = screen?.name || "";

    // If no monitors specified, show on all screens
    // If monitors specified, only show if this screen is in the list
    return monitors.length === 0 || monitors.includes(screenName);
  }

  // Make everything click-through except bar
  mask: Region {
    id: clickableMask

    // Cover entire window (everything is masked/click-through)
    x: 0
    y: 0
    width: root.width
    height: root.height
    intersection: Intersection.Xor

    // Only include regions that are actually needed
    // panelRegions is handled by PanelService, bar is local to this screen
    regions: [barMaskRegion, backgroundMaskRegion]

    // Bar region - subtract bar area from mask (only if bar should be shown on this screen)
    Region {
      id: barMaskRegion

      readonly property bool isFramed: Settings.data.bar.barType === "framed"
      readonly property real barThickness: Style.barHeight
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
      readonly property string barPos: Settings.data.bar.position || "top"

      // Bar / Frame Mask
      Region {
        // Mode: Simple or Floating
        x: barPlaceholder.x
        y: barPlaceholder.y
        width: (!barMaskRegion.isFramed && root.barShouldShow) ? barPlaceholder.width : 0
        height: (!barMaskRegion.isFramed && root.barShouldShow) ? barPlaceholder.height : 0
        intersection: Intersection.Subtract
      }

      // Mode: Framed - 4 sides
      Region {
        // Top side
        Region {
          x: 0
          y: 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? root.width : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "top" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          intersection: Intersection.Subtract
        }

        // Bottom side
        Region {
          x: 0
          y: (barMaskRegion.isFramed && root.barShouldShow) ? (root.height - (barMaskRegion.barPos === "bottom" ? barMaskRegion.barThickness : barMaskRegion.frameThickness)) : 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? root.width : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "bottom" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          intersection: Intersection.Subtract
        }

        // Left side
        Region {
          x: 0
          y: 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "left" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? root.height : 0
          intersection: Intersection.Subtract
        }

        // Right side
        Region {
          x: (barMaskRegion.isFramed && root.barShouldShow) ? (root.width - (barMaskRegion.barPos === "right" ? barMaskRegion.barThickness : barMaskRegion.frameThickness)) : 0
          width: (barMaskRegion.isFramed && root.barShouldShow) ? (barMaskRegion.barPos === "right" ? barMaskRegion.barThickness : barMaskRegion.frameThickness) : 0
          height: (barMaskRegion.isFramed && root.barShouldShow) ? root.height : 0
          intersection: Intersection.Subtract
        }
      }
    }

    // Background region for click-to-close - reactive sizing
    // Uses isAnyPanelOpen so clicking on any screen's background closes the panel
    Region {
      id: backgroundMaskRegion
      x: 0
      y: 0
      width: root.isAnyPanelOpen ? root.width : 0
      height: root.isAnyPanelOpen ? root.height : 0
      intersection: Intersection.Subtract
    }
  }

  // Blur behind the bar and open panels — attached to PanelWindow (required by BackgroundEffect API)
  BackgroundEffect.blurRegion: Settings.data.general.enableBlurBehind ? blurRegion : null
  Region {
    id: blurRegion
    // ── Non-framed bar (simple/floating): single rectangle with bar corner states ──
    Region {
      x: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? barPlaceholder.x : 0
      y: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? barPlaceholder.y : 0
      width: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? barPlaceholder.width : 0
      height: (!barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? barPlaceholder.height : 0
      radius: Style.radiusL
      topLeftCorner: barPlaceholder.topLeftCornerState
      topRightCorner: barPlaceholder.topRightCornerState
      bottomLeftCorner: barPlaceholder.bottomLeftCornerState
      bottomRightCorner: barPlaceholder.bottomRightCornerState
    }

    // ── Framed bar: full screen minus rounded hole ──
    Region {
      x: 0
      y: 0
      width: (barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? root.width : 0
      height: (barPlaceholder.isFramed && root.barShouldShow && !barPlaceholder.isHidden) ? root.height : 0

      Region {
        intersection: Intersection.Subtract
        x: backgroundBlur.frameHoleX
        y: backgroundBlur.frameHoleY
        width: backgroundBlur.frameHoleX2 - backgroundBlur.frameHoleX
        height: backgroundBlur.frameHoleY2 - backgroundBlur.frameHoleY
        radius: backgroundBlur.frameR
      }
    }

    // ── Panel blur regions ──
    // Opening panel
    Region {
      x: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.x) : 0
      y: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.y) : 0
      width: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.width) : 0
      height: backgroundBlur.panelBg ? Math.round(backgroundBlur.panelBg.height) : 0
      radius: Style.radiusL
      topLeftCorner: backgroundBlur.panelBg ? backgroundBlur.panelBg.topLeftCornerState : CornerState.Normal
      topRightCorner: backgroundBlur.panelBg ? backgroundBlur.panelBg.topRightCornerState : CornerState.Normal
      bottomLeftCorner: backgroundBlur.panelBg ? backgroundBlur.panelBg.bottomLeftCornerState : CornerState.Normal
      bottomRightCorner: backgroundBlur.panelBg ? backgroundBlur.panelBg.bottomRightCornerState : CornerState.Normal
    }

    // Modal overlay (coexists with the panel it is layered over)
    Region {
      x: backgroundBlur.modalBg ? Math.round(backgroundBlur.modalBg.x) : 0
      y: backgroundBlur.modalBg ? Math.round(backgroundBlur.modalBg.y) : 0
      width: backgroundBlur.modalBg ? Math.round(backgroundBlur.modalBg.width) : 0
      height: backgroundBlur.modalBg ? Math.round(backgroundBlur.modalBg.height) : 0
      radius: Style.radiusL
      topLeftCorner: backgroundBlur.modalBg ? backgroundBlur.modalBg.topLeftCornerState : CornerState.Normal
      topRightCorner: backgroundBlur.modalBg ? backgroundBlur.modalBg.topRightCornerState : CornerState.Normal
      bottomLeftCorner: backgroundBlur.modalBg ? backgroundBlur.modalBg.bottomLeftCornerState : CornerState.Normal
      bottomRightCorner: backgroundBlur.modalBg ? backgroundBlur.modalBg.bottomRightCornerState : CornerState.Normal
    }

    // Closing panel (coexists with opening panel during transition)
    Region {
      x: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.x) : 0
      y: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.y) : 0
      width: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.width) : 0
      height: backgroundBlur.closingPanelBg ? Math.round(backgroundBlur.closingPanelBg.height) : 0
      radius: Style.radiusL
      topLeftCorner: backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.topLeftCornerState : CornerState.Normal
      topRightCorner: backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.topRightCornerState : CornerState.Normal
      bottomLeftCorner: backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.bottomLeftCornerState : CornerState.Normal
      bottomRightCorner: backgroundBlur.closingPanelBg ? backgroundBlur.closingPanelBg.bottomRightCornerState : CornerState.Normal
    }
  }

  // --------------------------------------
  // Container for all UI elements
  Item {
    id: container
    width: root.width
    height: root.height

    // Unified backgrounds container / unified shadow system
    // Renders all bar and panel backgrounds as ShapePaths within a single Shape
    // This allows the shadow effect to apply to all backgrounds in one render pass
    Backgrounds.AllBackgrounds {
      id: unifiedBackgrounds
      anchors.fill: parent
      bar: barPlaceholder.barItem || null
      windowRoot: root
      z: 0 // Behind all content
    }

    // Background MouseArea for closing panels when clicking outside
    // Uses isAnyPanelOpen so clicking on any screen's background closes the panel
    MouseArea {
      anchors.fill: parent
      // A modal blocks click-to-close entirely: dismissing an authentication
      // prompt with a stray click would strand the request that is waiting on it.
      enabled: root.isAnyPanelOpen && !PanelService.modalOpen
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => {
                   if (PanelService.openedPanel) {
                     PanelService.openedPanel.close();
                   }
                 }
      z: 0 // Behind panels and bar
    }

    // ---------------------------------------
    // All panels always exist
    // ---------------------------------------
    AudioPanel {
      id: audioPanel
      objectName: "audioPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    MediaPlayerPanel {
      id: mediaPlayerPanel
      objectName: "mediaPlayerPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BatteryPanel {
      id: batteryPanel
      objectName: "batteryPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BluetoothPanel {
      id: bluetoothPanel
      objectName: "bluetoothPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    BrightnessPanel {
      id: brightnessPanel
      objectName: "brightnessPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ControlCenterPanel {
      id: controlCenterPanel
      objectName: "controlCenterPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ChangelogPanel {
      id: changelogPanel
      objectName: "changelogPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ClockPanel {
      id: clockPanel
      objectName: "clockPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    Launcher {
      id: launcherPanel
      objectName: "launcherPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    NotificationHistoryPanel {
      id: notificationHistoryPanel
      objectName: "notificationHistoryPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SessionMenu {
      id: sessionMenuPanel
      objectName: "sessionMenuPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SettingsPanel {
      id: settingsPanel
      objectName: "settingsPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SetupWizard {
      id: setupWizardPanel
      objectName: "setupWizardPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    TrayDrawerPanel {
      id: trayDrawerPanel
      objectName: "trayDrawerPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }
    PolkitPanel {
      id: polkitPanel
      objectName: "polkitPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
      // Modal: it layers over whatever panel asked for the privileged action,
      // so it has to sit above every other panel declared here.
      z: 50
    }

    ScreenSharePanel {
      id: screenSharePanel
      objectName: "screenSharePanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    WallpaperPanel {
      id: wallpaperPanel
      objectName: "wallpaperPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    NetworkPanel {
      id: networkPanel
      objectName: "networkPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ObsControlPanel {
      id: obsControlPanel
      objectName: "obsControlPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    SystemStatsPanel {
      id: systemStatsPanel
      objectName: "systemStatsPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    TamagotchiPanel {
      id: tamagotchiPanel
      objectName: "tamagotchiPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    UsbDriveManagerPanel {
      id: usbDriveManagerPanel
      objectName: "usbDriveManagerPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    StaticDockPanel {
      id: staticDockPanel
      objectName: "staticDockPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    ScreenToolkitPanel {
      id: screenToolkitPanel
      objectName: "screenToolkitPanel-" + (root.screen?.name || "unknown")
      screen: root.screen
    }

    // ----------------------------------------------
    // Plugin panel slots
    // ----------------------------------------------
    PluginPanelSlot {
      id: pluginPanel1
      objectName: "pluginPanel1-" + (root.screen?.name || "unknown")
      screen: root.screen
      slotNumber: 1
    }

    PluginPanelSlot {
      id: pluginPanel2
      objectName: "pluginPanel2-" + (root.screen?.name || "unknown")
      screen: root.screen
      slotNumber: 2
    }

    // ----------------------------------------------
    // Bar background placeholder - just for background positioning (actual bar content is in BarContentWindow)
    Item {
      id: barPlaceholder

      // Expose self as barItem for AllBackgrounds compatibility
      readonly property var barItem: barPlaceholder

      // Screen reference
      property ShellScreen screen: root.screen

      // Bar background positioning properties (per-screen)
      readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
      readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
      readonly property bool isFramed: Settings.data.bar.barType === "framed"
      readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
      readonly property bool barFloating: Settings.data.bar.barType === "floating"
      readonly property real barMarginH: barFloating ? Math.floor(Settings.data.bar.marginHorizontal) : 0
      readonly property real barMarginV: barFloating ? Math.floor(Settings.data.bar.marginVertical) : 0
      readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)

      // Auto-hide properties (read by AllBackgrounds for background fade)
      readonly property bool autoHide: Settings.getBarDisplayModeForScreen(screen?.name) === "auto_hide"
      property bool isHidden: autoHide

      Connections {
        target: BarService
        function onBarAutoHideStateChanged(screenName, hidden) {
          if (screenName === barPlaceholder.screen?.name) {
            barPlaceholder.isHidden = hidden;
          }
        }
      }

      // Expose bar dimensions directly on this Item for BarBackground
      // Use screen dimensions directly
      x: {
        if (barPosition === "right")
          return (screen?.width ?? 0) - barHeight - barMarginH;
        if (isFramed && !barIsVertical)
          return frameThickness;
        return barMarginH;
      }
      y: {
        if (barPosition === "bottom")
          return (screen?.height ?? 0) - barHeight - barMarginV;
        if (isFramed && barIsVertical)
          return frameThickness;
        return barMarginV;
      }
      width: {
        if (barIsVertical) {
          return barHeight;
        }
        if (isFramed)
          return (screen?.width ?? 0) - frameThickness * 2;
        return (screen?.width ?? 0) - barMarginH * 2;
      }
      height: {
        if (!barIsVertical) {
          return barHeight;
        }
        if (isFramed)
          return (screen?.height ?? 0) - frameThickness * 2;
        return (screen?.height ?? 0) - barMarginV * 2;
      }

      // Corner states (same as Bar.qml)
      readonly property int topLeftCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "top")
          return -1;
        if (barPosition === "left")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "right")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int topRightCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "top")
          return -1;
        if (barPosition === "right")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "left")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int bottomLeftCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "bottom")
          return -1;
        if (barPosition === "left")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "right")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }

      readonly property int bottomRightCornerState: {
        if (barFloating)
          return 0;
        if (barPosition === "bottom")
          return -1;
        if (barPosition === "right")
          return -1;
        if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "left")) {
          return barIsVertical ? 1 : 2;
        }
        return -1;
      }
    }

    // Screen Corners
    ScreenCorners {}

    // Blur behind the bar and open panels
    // Helper object holding computed properties for blur regions
    QtObject {
      id: backgroundBlur

      // Panel background geometry (from the currently open panel on this screen)
      readonly property var panelBg: {
        var op = PanelService.openedPanel;
        if (!op || op.screen !== root.screen || op.blurEnabled === false)
          return null;
        var region = op.panelRegion;
        return (region && region.visible) ? region.panelItem : null;
      }

      // Modal overlay geometry (coexists with panelBg — it stacks over it)
      readonly property var modalBg: {
        var mp = PanelService.modalPanel;
        if (!mp || mp.screen !== root.screen || mp.blurEnabled === false)
          return null;
        var region = mp.panelRegion;
        return (region && region.visible) ? region.panelItem : null;
      }

      // Panel background geometry for the closing panel (may coexist with panelBg)
      readonly property var closingPanelBg: {
        var cp = PanelService.closingPanel;
        if (!cp || cp.screen !== root.screen || cp.blurEnabled === false)
          return null;
        var region = cp.panelRegion;
        return (region && region.visible) ? region.panelItem : null;
      }

      // Framed bar: inner hole boundary (where the hole begins on each axis)
      // These are the x/y coordinates of the 4 inner hole corners
      readonly property real frameHoleX: barPlaceholder.barPosition === "left" ? barPlaceholder.barHeight : barPlaceholder.frameThickness
      readonly property real frameHoleY: barPlaceholder.barPosition === "top" ? barPlaceholder.barHeight : barPlaceholder.frameThickness
      readonly property real frameHoleX2: root.width - (barPlaceholder.barPosition === "right" ? barPlaceholder.barHeight : barPlaceholder.frameThickness)
      readonly property real frameHoleY2: root.height - (barPlaceholder.barPosition === "bottom" ? barPlaceholder.barHeight : barPlaceholder.frameThickness)
      readonly property real frameR: Settings.data.bar.frameRadius ?? 20
    }

    // Native idle inhibitor — one per active MainScreen window.
    // Multiple inhibitors bound to the same enabled state are harmless;
    // having one per screen is more robust than picking a "primary" screen.
    IdleInhibitor {
      window: root
      enabled: IdleInhibitorService.isInhibited

      Component.onCompleted: {
        IdleInhibitorService.nativeInhibitorAvailable = true;
        Logger.d("IdleInhibitor", "Native IdleInhibitor active on screen:", root.screen?.name);
      }
    }
  }

  // Centralized Keyboard Shortcuts

  // These shortcuts delegate to the active panel's handler functions — a modal
  // (polkit) takes precedence over the panel underneath it, so Escape cancels the
  // authentication rather than the panel that requested it.
  // Panels can implement: onEscapePressed, onTabPressed, onBackTabPressed,
  // onUpPressed, onDownPressed, onReturnPressed, etc...
  readonly property var shortcutPanel: PanelService.activePanel

  Instantiator {
    model: Settings.data.general.keybinds.keyEscape || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onEscapePressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onEscapePressed?.()
    }
  }

  Shortcut {
    sequence: "Tab"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onTabPressed !== undefined)
    onActivated: root.shortcutPanel?.onTabPressed?.()
  }

  Shortcut {
    sequence: "Backtab"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onBackTabPressed !== undefined)
    onActivated: root.shortcutPanel?.onBackTabPressed?.()
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyUp || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onUpPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onUpPressed?.()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyDown || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onDownPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onDownPressed?.()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyEnter || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onEnterPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onEnterPressed?.()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyLeft || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onLeftPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onLeftPressed?.()
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyRight || []
    Shortcut {
      sequence: modelData
      enabled: root.isPanelOpen && (root.shortcutPanel?.onRightPressed !== undefined) && !PanelService.isKeybindRecording
      onActivated: root.shortcutPanel?.onRightPressed?.()
    }
  }

  Shortcut {
    sequence: "Home"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onHomePressed !== undefined)
    onActivated: root.shortcutPanel?.onHomePressed?.()
  }

  Shortcut {
    sequence: "End"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onEndPressed !== undefined)
    onActivated: root.shortcutPanel?.onEndPressed?.()
  }

  Shortcut {
    sequence: "PgUp"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onPageUpPressed !== undefined)
    onActivated: root.shortcutPanel?.onPageUpPressed?.()
  }

  Shortcut {
    sequence: "PgDown"
    enabled: root.isPanelOpen && (root.shortcutPanel?.onPageDownPressed !== undefined)
    onActivated: root.shortcutPanel?.onPageDownPressed?.()
  }
}
