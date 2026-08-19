import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
DashboardCard {
  id: recordingCard

  styleKey: "recording"
  styleRoot: true
  clip: true

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
          text: panelRoot.toolkitRecordState === "recording" ? panelRoot.tr("recordingNow") : (panelRoot.toolkitRecordState === "converting" ? panelRoot.tr("recordingConverting") : panelRoot.tr("screenToolsSubtitle"))
          pointSize: Style.fontSizeS
          color: panelRoot.toolkitRecording ? Color.mError : panelRoot.componentText("recording", false)
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
        onTriggered: panelRoot.startDashboardRecording("gif")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("recordMp4")
        iconName: "video"
        active: true
        onTriggered: panelRoot.startDashboardRecording("mp4")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("screenshotArea")
        iconName: "crop"
        onTriggered: panelRoot.takeDashboardScreenshot("region")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        labelText: panelRoot.tr("screenshotScreen")
        iconName: "camera"
        onTriggered: panelRoot.takeDashboardScreenshot("active-screen")
      }

      ToolkitButton {
        panelRoot: recordingCard.panelRoot
        Layout.columnSpan: 2
        labelText: panelRoot.tr("stopRecording")
        iconName: "square"
        visible: panelRoot.toolkitRecording
        destructive: true
        onTriggered: panelRoot.stopDashboardRecording()
      }
    }
  }
}
