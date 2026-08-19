import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
Item {
  id: timerPage

  required property var panelRoot

  function parseDuration(value) {
    const text = String(value || "").trim().toLowerCase();
    if (text === "")
      return 0;
    if (/^\d+$/.test(text))
      return Math.min(86400, Number(text) * 60);
    if (text.includes(":")) {
      const parts = text.split(":").map(part => Number(part));
      if (parts.some(part => !Number.isFinite(part) || part < 0))
        return 0;
      if (parts.length === 2)
        return Math.min(86400, parts[0] * 60 + parts[1]);
      if (parts.length === 3)
        return Math.min(86400, parts[0] * 3600 + parts[1] * 60 + parts[2]);
      return 0;
    }
    let seconds = 0;
    let matched = false;
    const pattern = /(\d+)\s*(h|m|s)/g;
    let match;
    while ((match = pattern.exec(text)) !== null) {
      matched = true;
      seconds += Number(match[1]) * (match[2] === "h" ? 3600 : match[2] === "m" ? 60 : 1);
    }
    return matched ? Math.min(86400, seconds) : 0;
  }

  function formatDuration(totalSeconds) {
    const total = Math.max(0, Math.floor(totalSeconds));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const seconds = total % 60;
    return hours > 0 ? `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}` : `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }

  function setCountdown(value) {
    const seconds = timerPage.parseDuration(value);
    if (seconds <= 0)
      return;
    Time.timerReset();
    Time.timerStopwatchMode = false;
    Time.timerRemainingSeconds = seconds;
    Time.timerTotalSeconds = seconds;
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    NTabBar {
      id: timerModeTabs
      Layout.fillWidth: true
      tabHeight: Math.round(28 * panelRoot.panelUnit)
      distributeEvenly: true
      enabled: !Time.timerRunning
      currentIndex: Time.timerStopwatchMode ? 1 : 0
      onCurrentIndexChanged: {
        const stopwatch = currentIndex === 1;
        if (Time.timerStopwatchMode === stopwatch)
          return;
        Time.timerReset();
        Time.timerStopwatchMode = stopwatch;
        if (!stopwatch)
          timerPage.setCountdown(durationInput.text);
      }

      NTabButton {
        text: panelRoot.tr("countdown")
        icon: "hourglass"
        pointSize: Style.fontSizeXS
        tabIndex: 0
        checked: timerModeTabs.currentIndex === 0
      }

      NTabButton {
        text: panelRoot.tr("stopwatch")
        icon: "stopwatch"
        pointSize: Style.fontSizeXS
        tabIndex: 1
        checked: timerModeTabs.currentIndex === 1
      }
    }

    NText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
      text: timerPage.formatDuration(Time.timerStopwatchMode ? Time.timerElapsedSeconds : Time.timerRemainingSeconds)
      pointSize: Style.fontSizeXXL * 1.45
      font.family: Settings.data.ui.fontFixed
      font.weight: Style.fontWeightBold
      color: Time.timerSoundPlaying ? Color.mError : Color.mPrimary
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(5 * panelRoot.panelUnit)
      visible: !Time.timerStopwatchMode && Time.timerTotalSeconds > 0

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.mSurfaceVariant
      }

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, Time.timerRemainingSeconds / Math.max(1, Time.timerTotalSeconds)))
        radius: height / 2
        color: Time.timerSoundPlaying ? Color.mError : Color.mPrimary
      }
    }

    RowLayout {
      Layout.fillWidth: true
      visible: !Time.timerStopwatchMode && !Time.timerRunning && !Time.timerSoundPlaying
      spacing: Style.marginS

      NTextInput {
        id: durationInput
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: "25m"
        placeholderText: panelRoot.tr("timerDurationPlaceholder")
        inputIconName: "clock"
        showClearButton: false
        onAccepted: timerPage.setCountdown(text)
        onEditingFinished: timerPage.setCountdown(text)
      }

      Repeater {
        model: [
          {
            "label": "5m",
            "seconds": 300
          },
          {
            "label": "25m",
            "seconds": 1500
          },
          {
            "label": "60m",
            "seconds": 3600
          }
        ]

        NButton {
          required property var modelData
          Layout.preferredHeight: Math.round(34 * panelRoot.panelUnit)
          text: modelData.label
          outlined: true
          fontSize: Style.fontSizeXS
          onClicked: {
            durationInput.text = modelData.label;
            timerPage.setCountdown(modelData.seconds + "s");
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.marginS

      NButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(36 * panelRoot.panelUnit)
        text: Time.timerSoundPlaying ? panelRoot.tr("dismissAlarm") : Time.timerRunning ? panelRoot.tr("pause") : panelRoot.tr("start")
        icon: Time.timerSoundPlaying ? "bell-off" : Time.timerRunning ? "player-pause" : "player-play"
        enabled: Time.timerSoundPlaying || Time.timerStopwatchMode || Time.timerRemainingSeconds > 0
        onClicked: {
          if (Time.timerSoundPlaying)
            Time.timerReset();
          else if (Time.timerRunning)
            Time.timerPause();
          else
            Time.timerStart();
        }
      }

      NButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(36 * panelRoot.panelUnit)
        text: panelRoot.tr("reset")
        icon: "refresh"
        outlined: true
        onClicked: {
          Time.timerReset();
          if (!Time.timerStopwatchMode)
            timerPage.setCountdown(durationInput.text);
        }
      }
    }
  }

  Component.onCompleted: {
    if (!Time.timerStopwatchMode && Time.timerRemainingSeconds <= 0)
      timerPage.setCountdown(durationInput.text);
  }
}
