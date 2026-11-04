import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Panels.SystemStats
import qs.Services.System

ShellRoot {
  id: lab
  property bool light: false
  property bool paletteReady: false
  property real viewportWidth: 440
  property real viewportHeight: 780

  Window {
    id: window
    width: 440
    height: 740
    visible: true
    color: HydraColor.mSurface
    title: "Hydra · System monitor"
    Rectangle {
      id: canvas
      width: Math.min(window.width, lab.viewportWidth)
      height: Math.min(window.height, lab.viewportHeight)
      color: HydraColor.mSurface
      StatsDashboard {
        id: dashboard
        anchors.fill: parent
        anchors.margins: Style.marginL
        onCloseRequested: Qt.quit()
      }
    }
  }
  FileView {
    id: palette
    path: Quickshell.shellDir + "/Assets/ColorScheme/Hydra-Glacier/Hydra-Glacier.json"
    onLoaded: {
      lab.paletteReady = true;
      lab.applyPalette();
    }
  }
  function applyPalette() {
    if (!paletteReady)
      return;
    HydraColor.previewDarkMode = !light;
    HydraColor.previewPalette(JSON.parse(palette.text())[light ? "light" : "dark"]);
  }
  IpcHandler {
    target: "statsLab"
    function capture(path: string): void {
      canvas.grabToImage(result => console.log("STATS_CAPTURE", result.saveToFile(path)));
    }
    function page(index: int): void {
      dashboard.currentPage = index;
    }
    function dgpu(value: bool): void {
      Settings.data.systemMonitor.enableDgpuMonitoring = value;
    }
    function active(value: bool): void {
      dashboard.active = value;
    }
    function size(width: int, height: int, scale: real): void {
      lab.viewportWidth = width;
      lab.viewportHeight = height;
      window.width = width;
      window.height = height;
      Settings.data.general.scaleRatio = scale;
    }
    function theme(light: bool): void {
      lab.light = light;
      lab.applyPalette();
    }
    function state(): string {
      return JSON.stringify({
                              ready: I18n.isLoaded && lab.paletteReady,
                              page: dashboard.currentPage,
                              active: dashboard.active,
                              registered: dashboard.registered,
                              polling: SystemStatService.shouldRun,
                              diskReady: SystemStatService.diskSizeGb["/"] > 0,
                              cpuSamples: dashboard.telemetry.cpuSamples,
                              busy: dashboard.telemetry._busy,
                              data: dashboard.telemetry.data,
                              gpuSamples: dashboard.telemetry.gpuUsageHistory
                            });
    }
    function quit(): void {
      Qt.quit();
    }
  }
}
