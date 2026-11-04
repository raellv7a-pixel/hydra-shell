import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
import qs.Services.UI

BarPill {
  id: root

  readonly property string status: ScreenToolkitService.recordState
  readonly property bool vertical: Settings.getBarPositionForScreen(screen?.name) === "left" || Settings.getBarPositionForScreen(screen?.name) === "right"
  readonly property string formatLabel: ScreenToolkitService.recordFormat.toUpperCase()
  readonly property int seconds: ScreenToolkitService.recordElapsedSeconds
  readonly property string elapsedLabel: (seconds / 60 < 10 ? "0" : "") + Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60
  readonly property string statusLabel: {
    switch (status) {
    case "selecting": return ScreenToolkitService.tr("record.selecting");
    case "recording": return ScreenToolkitService.tr("record.recLabel") + " " + elapsedLabel;
    case "converting": return ScreenToolkitService.tr(ScreenToolkitService.recordFormat === "mp4" ? "record.savingMp4" : "record.convertingGif");
    case "done": return ScreenToolkitService.recordSaved ? ScreenToolkitService.tr("record.saved") : ScreenToolkitService.tr(ScreenToolkitService.recordFormat === "mp4" ? "record.mp4Ready" : "record.gifReady");
    case "error": return ScreenToolkitService.tr("record.failed");
    default: return "";
    }
  }

  visible: status !== ""
  icon: status === "recording" ? "square" : "video"
  forceOpen: !vertical
  forceClose: vertical
  oppositeDirection: BarService.getPillDirection(root)
  text: status === "recording" ? ScreenToolkitService.tr("record.recLabel") + " " + elapsedLabel + " " + formatLabel : statusLabel + (status === "done" ? "" : " " + formatLabel)
  tooltipText: status === "error" ? ScreenToolkitService.recordError : status === "recording" ? text + " · " + ScreenToolkitService.tr("record.stop") : statusLabel
  customBackgroundColor: status === "recording" || status === "error" ? HydraColor.mErrorContainer : HydraColor.mSurfaceContainerHigh
  customTextIconColor: status === "recording" || status === "error" ? HydraColor.mOnErrorContainer : HydraColor.mOnSurface
  onClicked: {
    if (status === "recording") {
      ScreenToolkitService.stopRecording();
    } else if (status === "done" || status === "error") {
      const panel = PanelService.getPanel("controlCenterPanel", screen);
      if (panel)
        panel.open();
    }
  }
}
