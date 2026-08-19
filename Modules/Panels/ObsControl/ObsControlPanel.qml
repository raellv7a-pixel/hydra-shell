import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(430 * Style.uiScaleRatio)
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.28)

  panelContent: Item {
    id: panelContent

    property bool allowAttach: true
    property real contentPreferredHeight: content.implicitHeight + Style.paddingCard * 2

    ColumnLayout {
      id: content
      anchors.fill: parent
      anchors.margins: Style.radiusPanel // must be >= the panel's own blob corner radius (28px), not paddingCard (16px), or content stops short and the wallpaper shows through the rounded-off corner
      spacing: Style.spaceS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spaceS

        Rectangle {
          Layout.preferredWidth: Style.baseWidgetSize * 0.9
          Layout.preferredHeight: Style.baseWidgetSize * 0.9
          radius: height / 2
          color: ObsControlService.recording ? Color.mErrorContainer : Color.mPrimaryContainer

          NIcon {
            anchors.centerIn: parent
            icon: ObsControlService.recording ? "player-record-filled" : "brand-obs"
            pointSize: Style.fontSizeTitleSmall
            color: ObsControlService.recording ? Color.mOnErrorContainer : Color.mOnPrimaryContainer
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.spaceXXS

          NText {
            Layout.fillWidth: true
            text: I18n.tr("bar.obs-control.title")
            pointSize: Style.fontSizeTitleSmall
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
          }
          NText {
            Layout.fillWidth: true
            text: I18n.tr(`bar.obs-control.state-${ObsControlService.effectiveState}`)
            wrapMode: Text.WordWrap
            color: ObsControlService.connected ? Color.mPrimary : Color.mOnSurfaceVariant
          }
        }

        NIconButton {
          icon: "refresh"
          tooltipText: I18n.tr("bar.obs-control.refresh")
          enabled: !ObsControlService.pollBusy
          onClicked: ObsControlService.refresh()
        }
        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          onClicked: root.close()
        }
      }

      NBox {
        Layout.fillWidth: true
        implicitHeight: statusColumn.implicitHeight + Style.spaceS * 2
        color: Color.mSurfaceContainer
        radius: Style.radiusCard

        ColumnLayout {
          id: statusColumn
          anchors.fill: parent
          anchors.margins: Style.spaceS
          spacing: Style.spaceXS

          NText {
            Layout.fillWidth: true
            text: I18n.tr("bar.obs-control.status")
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spaceXS

            NIcon {
              icon: ObsControlService.connected ? "plug-connected" : "plug-connected-x"
              color: ObsControlService.connected ? Color.mPrimary : Color.mError
            }
            NText {
              Layout.fillWidth: true
              text: ObsControlService.connected ? I18n.tr("bar.obs-control.authenticated") : I18n.tr(`bar.obs-control.state-${ObsControlService.effectiveState}`)
              wrapMode: Text.WordWrap
              color: Color.mOnSurfaceVariant
            }
          }

          NText {
            Layout.fillWidth: true
            visible: ObsControlService.effectiveState === "connection-error" && ObsControlService.lastError !== ""
            text: ObsControlService.lastError
            wrapMode: Text.WordWrap
            color: Color.mError
          }

          NText {
            Layout.fillWidth: true
            visible: ObsControlService.recording
            text: `${I18n.tr("bar.obs-control.recording")}: ${formatDuration(ObsControlService.displayRecordDurationMs)}`
            color: Color.mError
            font.weight: Style.fontWeightSemiBold
          }
          NText {
            Layout.fillWidth: true
            visible: ObsControlService.streaming
            text: `${I18n.tr("bar.obs-control.streaming")}: ${formatDuration(ObsControlService.displayStreamDurationMs)}`
            color: Color.mPrimary
            font.weight: Style.fontWeightSemiBold
          }
          NText {
            Layout.fillWidth: true
            visible: ObsControlService.replayBuffer
            text: I18n.tr("bar.obs-control.replay-active")
            color: Color.mSecondary
            font.weight: Style.fontWeightSemiBold
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.spaceS
        rowSpacing: Style.spaceS

        NButton {
          Layout.fillWidth: true
          icon: "player-record"
          text: ObsControlService.recording ? I18n.tr("bar.obs-control.stop-recording") : I18n.tr("bar.obs-control.start-recording")
          enabled: ObsControlService.connected && !ObsControlService.actionBusy
          backgroundColor: ObsControlService.recording ? Color.mError : Color.mPrimary
          textColor: ObsControlService.recording ? Color.mOnError : Color.mOnPrimary
          onClicked: ObsControlService.toggleRecord()
        }
        NButton {
          Layout.fillWidth: true
          icon: "broadcast"
          text: ObsControlService.streaming ? I18n.tr("bar.obs-control.stop-streaming") : I18n.tr("bar.obs-control.start-streaming")
          enabled: ObsControlService.connected && !ObsControlService.actionBusy
          backgroundColor: ObsControlService.streaming ? Color.mPrimary : Color.mSurfaceVariant
          textColor: ObsControlService.streaming ? Color.mOnPrimary : Color.mOnSurface
          onClicked: ObsControlService.toggleStream()
        }
        NButton {
          Layout.fillWidth: true
          icon: "history"
          text: ObsControlService.replayBuffer ? I18n.tr("bar.obs-control.stop-replay") : I18n.tr("bar.obs-control.start-replay")
          enabled: ObsControlService.connected && !ObsControlService.actionBusy
          backgroundColor: ObsControlService.replayBuffer ? Color.mSecondary : Color.mSurfaceVariant
          textColor: ObsControlService.replayBuffer ? Color.mOnSecondary : Color.mOnSurface
          onClicked: ObsControlService.toggleReplay()
        }
        NButton {
          Layout.fillWidth: true
          icon: "device-floppy"
          text: I18n.tr("bar.obs-control.save-replay")
          enabled: ObsControlService.connected && ObsControlService.replayBuffer && !ObsControlService.actionBusy
          outlined: !ObsControlService.replayBuffer
          onClicked: ObsControlService.saveReplay()
        }
      }

      NText {
        Layout.fillWidth: true
        visible: ObsControlService.configurationMissing
        text: I18n.tr("bar.obs-control.configure-hint")
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
      }
    }

    function formatDuration(milliseconds) {
      const seconds = Math.floor(Math.max(0, milliseconds) / 1000);
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      const remainder = seconds % 60;
      const minuteText = String(minutes).padStart(2, "0");
      const secondText = String(remainder).padStart(2, "0");
      return hours > 0 ? `${hours}:${minuteText}:${secondText}` : `${minuteText}:${secondText}`;
    }
  }
}
