import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
DashboardCard {
  id: mediaCard
  styleKey: "media"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "left"

  color: panelRoot.componentColor("media", "background", panelRoot.musicActive ? panelRoot.m3PrimaryContainer : panelRoot.m3SurfaceContainerLow)
  border.color: borderEffectVisible ? Qt.alpha(panelRoot.componentAccent("media"), 0.42) : "transparent"
  clip: true

  Behavior on color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Behavior on border.color {
    ColorAnimation {
      duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: mediaCard.radius
    color: panelRoot.componentAccent("media")
    opacity: panelRoot.musicActive ? 0.04 : 0
    Behavior on opacity {
      NumberAnimation {
        duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
  }

  MusicVisualizer {
    panelRoot: mediaCard.panelRoot
    anchors.fill: parent
    anchors.margins: Math.round(4 * panelRoot.panelUnit)
    effect: panelRoot.mediaVisualizerEffect
    active: !panelRoot.dashboardPerformanceMode && panelRoot.musicActive
    clipRadius: Math.max(0, mediaCard.radius - Math.round(4 * panelRoot.panelUnit))
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginM

      NImageRounded {
        id: coverArt
        Layout.preferredWidth: Math.round(70 * panelRoot.panelUnit)
        Layout.preferredHeight: Math.round(70 * panelRoot.panelUnit)
        radius: Style.radiusS
        imagePath: MediaService.trackArtUrl
        fallbackIcon: "music"
        fallbackIconSize: Style.fontSizeXXL
        borderColor: Qt.alpha(Color.mOutline, 0.18)
        borderWidth: Style.borderS

        property string _lastTitle: MediaService.trackTitle
        on_LastTitleChanged: coverBounce.restart()

        SequentialAnimation on scale {
          id: coverBounce
          running: false
          NumberAnimation {
            to: 1.04
            duration: 150
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            to: 1.0
            duration: 300
            easing.type: Easing.OutBack
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginXXS

        NText {
          text: panelRoot.tr("media")
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightSemiBold
        }

        NText {
          Layout.fillWidth: true
          text: MediaService.trackTitle || panelRoot.tr("nothingPlaying")
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          elide: Text.ElideRight
        }

        NText {
          Layout.fillWidth: true
          text: MediaService.trackArtist || MediaService.playerIdentity || ""
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          elide: Text.ElideRight
        }
      }

      RowLayout {
        spacing: Style.marginXS
        Layout.alignment: Qt.AlignVCenter

        NIconButton {
          icon: "player-track-prev"
          baseSize: Math.round(30 * panelRoot.panelUnit)
          enabled: MediaService.canGoPrevious
          onClicked: MediaService.previous()
        }

        NIconButton {
          icon: MediaService.isPlaying ? "player-pause" : "player-play"
          baseSize: Math.round(34 * panelRoot.panelUnit)
          enabled: MediaService.currentPlayer !== null
          onClicked: MediaService.playPause()
        }

        NIconButton {
          icon: "player-track-next"
          baseSize: Math.round(30 * panelRoot.panelUnit)
          enabled: MediaService.canGoNext
          onClicked: MediaService.next()
        }

        SubmoduleButton {
          panelRoot: mediaCard.panelRoot
          targetView: "media"
          tooltipText: panelRoot.tr("details")
        }
      }
    }

    Item {
      id: mediaProgressWrapper

      visible: MediaService.currentPlayer !== null && MediaService.trackLength > 0
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? Math.round(28 * panelRoot.panelUnit) : 0

      property real localSeekRatio: -1
      property real lastSentSeekRatio: -1
      property real seekEpsilon: 0.01
      property real progressRatio: {
        if (!MediaService.currentPlayer || MediaService.trackLength <= 0)
          return 0;
        const r = MediaService.currentPosition / MediaService.trackLength;
        if (isNaN(r) || !isFinite(r))
          return 0;
        return Math.max(0, Math.min(1, r));
      }

      Timer {
        id: mediaSeekDebounce
        interval: 75
        repeat: false
        onTriggered: {
          if (MediaService.isSeeking && mediaProgressWrapper.localSeekRatio >= 0) {
            const next = Math.max(0, Math.min(1, mediaProgressWrapper.localSeekRatio));
            if (mediaProgressWrapper.lastSentSeekRatio < 0 || Math.abs(next - mediaProgressWrapper.lastSentSeekRatio) >= mediaProgressWrapper.seekEpsilon) {
              MediaService.seekByRatio(next);
              mediaProgressWrapper.lastSentSeekRatio = next;
            }
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        NSlider {
          id: mediaProgressSlider
          Layout.fillWidth: true
          Layout.preferredHeight: Math.round(16 * panelRoot.panelUnit)
          from: 0
          to: 1
          stepSize: 0
          snapAlways: false
          enabled: MediaService.trackLength > 0 && MediaService.canSeek
          heightRatio: 0.36
          value: (!MediaService.isSeeking) ? mediaProgressWrapper.progressRatio : (mediaProgressWrapper.localSeekRatio >= 0 ? mediaProgressWrapper.localSeekRatio : 0)

          onMoved: {
            mediaProgressWrapper.localSeekRatio = value;
            mediaSeekDebounce.restart();
          }

          onPressedChanged: {
            if (pressed) {
              MediaService.isSeeking = true;
              mediaProgressWrapper.localSeekRatio = value;
              MediaService.seekByRatio(value);
              mediaProgressWrapper.lastSentSeekRatio = value;
            } else {
              mediaSeekDebounce.stop();
              MediaService.seekByRatio(value);
              MediaService.isSeeking = false;
              mediaProgressWrapper.localSeekRatio = -1;
              mediaProgressWrapper.lastSentSeekRatio = -1;
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: MediaService.positionString || "0:00"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
          }

          Item {
            Layout.fillWidth: true
          }

          NText {
            text: MediaService.lengthString || "0:00"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }
  }
}
