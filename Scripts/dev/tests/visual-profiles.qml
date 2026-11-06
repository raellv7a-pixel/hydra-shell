pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Power
import qs.Services.UI
import qs.Widgets
import qs.Widgets.Iris
import qs.Modules.MainScreen.Backgrounds

// Private facade only: renders actual material primitives without host operations.
ShellRoot {
  id: root
  property bool light: false
  property bool paletteReady: false
  property string outputName: ""
  property bool probeMode: false
  property real probeLip: 8
  property real probeOpacity: 1
  property bool nativeFrameProbe: false
  function applyPalette() {
    if (!paletteReady) return;
    HydraColor.previewDarkMode = !light;
    Settings.data.colorSchemes.darkMode = !light;
    HydraColor.previewPalette(JSON.parse(palette.text())[light ? "light" : "dark"]);
  }
  function inspect(item, predicate) {
    let found = predicate(item) ? [item] : [];
    for (const child of item.children || []) found = found.concat(inspect(child, predicate));
    return found;
  }
  FileView {
    id: palette
    path: Quickshell.shellDir + "/Assets/ColorScheme/Hydra-Glacier/Hydra-Glacier.json"
    onLoaded: { root.paletteReady = true; root.applyPalette(); }
  }
  PanelWindow {
    id: window
    screen: Quickshell.screens.find(s => s.name === root.outputName) || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hydra-visual-profiles-lab"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: HydraColor.mSurface
    Rectangle {
      id: canvas
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: HydraColor.mPrimaryContainer }
        GradientStop { position: 0.5; color: HydraColor.mSurface }
        GradientStop { position: 1; color: HydraColor.mTertiaryContainer }
      }
      Rectangle { anchors.fill: parent; visible: root.probeMode; color: "#ffffff" }
      Item {
        id: barGeometry
        readonly property real barHeight: Style.getBarHeightForScreen(window.screen.name)
        readonly property bool isHidden: false
        width: canvas.width
        height: barHeight
      }
      Loader {
        anchors.fill: parent
        active: root.nativeFrameProbe
        sourceComponent: IrisBackgrounds { bar: barGeometry; windowRoot: window }
      }
      Loader {
        anchors.fill: parent
        active: root.probeMode
        sourceComponent: IrisField {
          opacity: root.probeOpacity
          framed: true
          frameInsets: Qt.vector4d(8, 32, 8, 8)
          cornerRadius: 12
          sceneSize: Qt.size(width, height)
          tint: "black"
          light: "red"
          lightInScene: true
          frameBevelLimits: Qt.vector4d(root.probeLip, root.probeLip, root.probeLip, root.probeLip)
          shapes: [{id: "probe", x: 200, y: 16, width: 440, height: 384, radius: 24, fuse: 64, joins: ["frame"], paints: false}]
        }
      }
      ColumnLayout {
        visible: !root.probeMode && !root.nativeFrameProbe
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.margin2XL, 1050 * Style.uiScaleRatio)
        spacing: Style.marginXL
        NText { text: "Hydra · " + I18n.tr("panels.user-interface.visual-variant-" + Style.visualVariant); pointSize: Style.fontSizeXXXL; font.weight: Style.fontWeightBold }
        NText { Layout.fillWidth: true; text: I18n.tr("panels.user-interface.visual-profile-description-" + Style.visualVariant); wrapMode: Text.Wrap }
        NMaterialSurface {
          id: bar
          Layout.fillWidth: true
          Layout.preferredHeight: 48 * Style.uiScaleRatio
          radius: Style.radiusL
          RowLayout {
            anchors.fill: parent; anchors.margins: Style.marginM
            NIcon { icon: "hydra"; color: HydraColor.mPrimary }
            NText { text: "Hydra Shell"; Layout.fillWidth: true }
            NIcon { icon: "wifi" }
            NIcon { icon: "volume" }
            NText { text: "12:34" }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginXL
          NMaterialSurface {
            id: panel
            Layout.fillWidth: true
            Layout.preferredWidth: 640
            Layout.preferredHeight: 330 * Style.uiScaleRatio
            radius: Style.radiusL
            ColumnLayout {
              anchors.fill: parent; anchors.margins: Style.marginXL; spacing: Style.marginL
              NText { text: "Dashboard"; pointSize: Style.fontSizeXL; font.weight: Style.fontWeightSemiBold }
              NText { Layout.fillWidth: true; text: I18n.tr("panels.user-interface.visual-variant-label"); wrapMode: Text.Wrap; color: HydraColor.mOnSurfaceVariant }
              NTextInput { Layout.fillWidth: true; placeholderText: I18n.tr("placeholders.search-launcher"); inputIconName: "search" }
              RowLayout {
                Layout.fillWidth: true
                NButton { text: "Wi-Fi"; icon: "wifi" }
                NButton { text: "Bluetooth"; icon: "bluetooth" }
                Item { Layout.fillWidth: true }
              }
              NValueSlider { Layout.fillWidth: true; label: "Volume"; from: 0; to: 1; value: 0.6 }
              Item { Layout.fillHeight: true }
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 300
            spacing: Style.marginXL
            NMaterialSurface {
              Layout.fillWidth: true
              Layout.preferredHeight: 120 * Style.uiScaleRatio
              radius: Style.radiusL
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.marginL
                NText { text: "Hydra"; font.weight: Style.fontWeightSemiBold }
                NText { text: I18n.tr("settings.content.shared.appearance-preview"); Layout.fillWidth: true; wrapMode: Text.Wrap; color: HydraColor.mOnSurfaceVariant }
              }
            }
            NSettingsAppearancePreview { Layout.fillWidth: true }
          }
        }
      }
    }
  }
  IpcHandler {
    target: "materials"
    function select(id: string, light: bool): void {
      Settings.data.ui.visualVariant = id;
      root.light = light;
      root.applyPalette();
    }
    function output(name: string): void { root.outputName = name; }
    function reduced(enabled: bool): void { PowerProfileService.hydraPerformanceMode = enabled; Settings.data.general.animationDisabled = enabled; }
    function effects(enabled: bool): void { Settings.data.general.enableBlurBehind = enabled; }
    function wallpaper(path: string): void {
      Settings.data.wallpaper.enabled = true;
      ImageCacheService.init();
      WallpaperService.changeWallpaper(path, window.screen.name);
    }
    function adjustments(lighting: real, texture: real): void {
      Settings.data.ui.materialLighting = lighting;
      Settings.data.ui.materialTexture = texture;
    }
    function probe(enabled: bool, lip: real): void { root.probeMode = enabled; root.probeLip = lip; }
    function fade(amount: real): void { root.probeOpacity = amount; }
    function nativeFrame(enabled: bool, capsules: bool): void {
      Settings.data.bar.barType = "framed";
      Settings.data.bar.position = "top";
      Settings.data.bar.density = "default";
      Settings.data.bar.frameThickness = 8;
      Settings.data.bar.frameRadius = 12;
      Settings.data.bar.useSeparateOpacity = false;
      Settings.data.bar.showCapsule = capsules;
      Settings.data.bar.monitors = [];
      Settings.data.ui.panelBackgroundOpacity = 1;
      root.nativeFrameProbe = enabled;
    }
    function save(): void { Settings.saveImmediate(); }
    function snapshot(): string {
      const fields = root.inspect(canvas, item => item.shapes !== undefined && item.backdropSource !== undefined);
      const shaders = root.inspect(canvas, item => item.fragmentShader !== undefined);
      return JSON.stringify({
        ready: root.paletteReady && Settings.isLoaded,
        profile: Style.visualVariant, selected: Settings.data.ui.visualVariant,
        primary: String(HydraColor.mPrimary), sourcePrimary: String(HydraColor.sourcePrimary),
        surface: String(HydraColor.mSurface), sourceSurface: String(HydraColor.sourceSurface),
        effects: Style.materialEffectsEnabled, glass: Style.glassEffectsEnabled,
        radius: panel.radius, animation: Style.animationFast,
        lighting: IrisStyle.lighting, texture: IrisStyle.afterglowSignal,
        fields: fields.length,
        shaders: shaders.map(shader => ({ url: String(shader.fragmentShader), status: shader.status, log: shader.log || "" })),
        sources: IrisGlassBackdrops.providers.length
      });
    }
    function capture(path: string): void { canvas.grabToImage(result => console.log("MATERIAL_CAPTURE", path, result.saveToFile(path))); }
  }
}
