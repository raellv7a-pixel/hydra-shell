import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System
DashboardCard {
  id: recordingCard

  styleKey: "recording"
  styleRoot: true
  clip: true
  readonly property string recordState: ScreenToolkitService.recordState
  readonly property bool recordBusy: recordState === "selecting" || recordState === "recording" || recordState === "converting"
  readonly property string recordTime: {
    const seconds = Math.max(0, Math.floor(ScreenToolkitService.recordElapsedSeconds));
    return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0");
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "crosshair"
        pointSize: Style.fontSizeXL
        color: panelRoot.componentAccent("recording")
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          text: panelRoot.tr("screenTools")
          font.weight: Style.fontWeightSemiBold
          color: panelRoot.componentText("recording", true)
        }

        NText {
          text: {
            let label = panelRoot.tr("screenToolsSubtitle");
            if (recordingCard.recordState === "selecting")
              label = I18n.tr("portal.region-select");
            else if (recordingCard.recordState === "recording")
              label = panelRoot.tr("recordingNow");
            else if (recordingCard.recordState === "converting")
              label = panelRoot.tr("recordingConverting");
            else if (recordingCard.recordState === "done")
              label = ScreenToolkitService.recordSaved ? panelRoot.tr("captureSaved") : ScreenToolkitService.tr(ScreenToolkitService.recordFormat === "mp4" ? "record.mp4Ready" : "record.gifReady");
            else if (recordingCard.recordState === "error")
              label = panelRoot.tr("captureFailed");
            if (recordingCard.recordState === "recording")
              return label + " · " + ScreenToolkitService.recordFormat.toUpperCase() + " · " + recordingCard.recordTime;
            if (recordingCard.recordState === "converting")
              return label + " · " + ScreenToolkitService.recordFormat.toUpperCase();
            return label;
          }
          pointSize: Style.fontSizeS
          color: recordingCard.recordState === "recording" || recordingCard.recordState === "error" ? HydraColor.mError : panelRoot.componentText("recording", false)
          elide: Text.ElideRight
        }
        NText {
          Layout.fillWidth: true
          visible: recordingCard.recordState === "error" || (recordingCard.recordState === "done" && ScreenToolkitService.recordSaved)
          text: recordingCard.recordState === "error" ? ScreenToolkitService.recordError : ScreenToolkitService.recordPath
          pointSize: Style.fontSizeS
          color: recordingCard.recordState === "error" ? HydraColor.mError : panelRoot.componentText("recording", false)
          elide: Text.ElideRight
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: 2
      columnSpacing: Style.marginS
      rowSpacing: Style.marginS

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("recordGif")
        iconName: "movie"
        active: true
        enabled: !recordingCard.recordBusy
        onTriggered: ScreenToolkitService.launchFromDashboard("record", "gif")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("recordMp4")
        iconName: "video"
        active: true
        enabled: !recordingCard.recordBusy
        onTriggered: ScreenToolkitService.launchFromDashboard("record", "mp4")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("screenshotArea")
        iconName: "crop"
        onTriggered: ScreenToolkitService.launchFromDashboard("screenshot", "region")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("screenshotScreen")
        iconName: "camera"
        onTriggered: ScreenToolkitService.launchFromDashboard("screenshot", "active-screen")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        Layout.columnSpan: 2
        labelText: panelRoot.tr("stopRecording")
        iconName: "square"
        visible: recordingCard.recordState === "recording"
        destructive: true
        onTriggered: ScreenToolkitService.stopRecording()
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: ScreenToolkitService.tr(ScreenToolkitService.recordFormat === "mp4" ? "record.saveMp4" : "record.saveGif")
        iconName: "device-floppy"
        visible: recordingCard.recordState === "done" && !ScreenToolkitService.recordSaved
        active: true
        onTriggered: ScreenToolkitService.saveRecording()
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: ScreenToolkitService.tr("record.discard")
        iconName: "trash"
        visible: recordingCard.recordState === "done" && !ScreenToolkitService.recordSaved
        destructive: true
        onTriggered: ScreenToolkitService.discardRecording()
      }
    }
  }
}
