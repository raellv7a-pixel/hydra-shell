import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
DashboardCard {
  id: mediaDetailsCard

  styleKey: "media"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
  clip: true

  Component.onCompleted: MediaService.highFrequencyPositionRequests++
  Component.onDestruction: MediaService.highFrequencyPositionRequests--

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("media")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: MediaService.isPlaying ? panelRoot.tr("playing") : panelRoot.tr("idle")
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: MediaService.isPlaying ? Color.mPrimary : Color.mOnSurfaceVariant
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      SwipeView {
        id: mediaSwipeView
        anchors.fill: parent
        anchors.bottomMargin: Math.round(20 * panelRoot.panelUnit)
        currentIndex: 0
        clip: true

        Item {
          ListView {
            id: lyricsList
            anchors.fill: parent
            clip: true
            spacing: Style.marginM
            model: LyricsService.lyrics
            currentIndex: LyricsService.currentLineIndex
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height * 0.42
            preferredHighlightEnd: height * 0.58
            highlightMoveDuration: Style.animationNormal
            highlightMoveVelocity: -1

            onModelChanged: Qt.callLater(function () {
              if (lyricsList.currentIndex >= 0)
                lyricsList.positionViewAtIndex(lyricsList.currentIndex, ListView.Center);
              else
                lyricsList.positionViewAtBeginning();
            })

            header: Item {
              width: 1
              height: LyricsService.hasSyncedLyrics ? Math.max(0, lyricsList.height * 0.4) : 0
            }

            footer: Item {
              width: 1
              height: LyricsService.hasSyncedLyrics ? Math.max(0, lyricsList.height * 0.4) : 0
            }

            delegate: NText {
              required property string modelData
              readonly property bool activeLine: LyricsService.hasSyncedLyrics && ListView.isCurrentItem

              width: lyricsList.width
              text: modelData || "· · ·"
              color: activeLine ? Color.mPrimary : Color.mOnSurfaceVariant
              pointSize: activeLine ? Style.fontSizeL : Style.fontSizeM
              font.weight: activeLine ? Style.fontWeightBold : Style.fontWeightNormal
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              opacity: LyricsService.isLoading ? 0.5 : (activeLine || !LyricsService.hasSyncedLyrics ? 1.0 : 0.58)
              scale: activeLine ? 1.06 : 1.0
              transformOrigin: Item.Center

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }

              Behavior on scale {
                ScaleAnimator {
                  duration: Style.animationNormal
                  easing.type: Easing.OutCubic
                }
              }
            }
          }
        }

        Item {
          Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: redesignedDetailsLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: redesignedDetailsLayout
              width: parent.width
              spacing: Style.marginL

              DashboardCard {
                panelRoot: mediaDetailsCard.panelRoot
                id: mediaArtworkCard

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(380 * panelRoot.panelUnit)
                color: panelRoot.m3SurfaceContainerHigh
                radius: Style.radiusM
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                  maskEnabled: true
                  maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                      width: mediaArtworkCard.width
                      height: mediaArtworkCard.height
                      radius: mediaArtworkCard.radius
                      color: "black"
                    }
                  }
                }

                Image {
                  id: bgImage
                  anchors.fill: parent
                  source: MediaService.trackArtUrl
                  fillMode: Image.PreserveAspectCrop
                  opacity: 0.3
                  layer.enabled: true
                  layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                      sourceItem: Rectangle {
                        width: bgImage.width
                        height: bgImage.height
                        radius: Style.radiusM
                        color: "black"
                      }
                    }
                  }
                }

                MusicVisualizer {
                  panelRoot: mediaDetailsCard.panelRoot
                  anchors.fill: parent
                  effect: panelRoot.mediaVisualizerEffect
                  active: panelRoot.musicActive
                  opacity: 0.5
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginL
                  spacing: Style.marginM

                  Item {
                    Layout.fillHeight: true
                  }

                  NImageRounded {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round(160 * panelRoot.panelUnit)
                    Layout.preferredHeight: Math.round(160 * panelRoot.panelUnit)
                    radius: Style.radiusM
                    imagePath: MediaService.trackArtUrl
                    fallbackIcon: "music"
                    fallbackIconSize: Style.fontSizeXXXL * 2
                    borderColor: Qt.alpha(Color.mOutline, 0.3)
                    borderWidth: Style.borderS

                    SequentialAnimation on scale {
                      id: page2CoverBounce
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

                    Connections {
                      target: MediaService
                      function onTrackTitleChanged() {
                        page2CoverBounce.restart();
                      }
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXXS

                    NText {
                      Layout.fillWidth: true
                      text: MediaService.trackTitle || panelRoot.tr("nothingPlaying")
                      color: Color.mOnSurface
                      pointSize: Style.fontSizeXXL
                      font.weight: Style.fontWeightBold
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }

                    NText {
                      Layout.fillWidth: true
                      text: MediaService.trackArtist || MediaService.playerIdentity || ""
                      color: Color.mOnSurfaceVariant
                      pointSize: Style.fontSizeL
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }

                  Item {
                    Layout.fillHeight: true
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXXS

                    NSlider {
                      Layout.fillWidth: true
                      from: 0
                      to: 1
                      stepSize: 0
                      snapAlways: false
                      enabled: MediaService.trackLength > 0 && MediaService.canSeek
                      value: panelRoot.mediaProgressRatio()
                      onMoved: MediaService.seekByRatio(value)
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      NText {
                        text: MediaService.positionString || "0:00"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                        font.family: Settings.data.ui.fontFixed
                      }
                      Item {
                        Layout.fillWidth: true
                      }
                      NText {
                        text: MediaService.lengthString || "0:00"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                        font.family: Settings.data.ui.fontFixed
                      }
                    }
                  }

                  RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Style.marginL

                    NIconButton {
                      icon: "player-track-prev"
                      baseSize: Math.round(36 * panelRoot.panelUnit)
                      enabled: MediaService.canGoPrevious
                      onClicked: MediaService.previous()
                      colorBg: Qt.alpha(Color.mPrimary, 0.1)
                    }

                    NIconButton {
                      icon: MediaService.isPlaying ? "player-pause" : "player-play"
                      baseSize: Math.round(52 * panelRoot.panelUnit)
                      enabled: MediaService.currentPlayer !== null
                      onClicked: MediaService.playPause()
                      colorBg: Color.mPrimary
                      colorFg: Color.mOnPrimary
                    }

                    NIconButton {
                      icon: "player-track-next"
                      baseSize: Math.round(36 * panelRoot.panelUnit)
                      enabled: MediaService.canGoNext
                      onClicked: MediaService.next()
                      colorBg: Qt.alpha(Color.mPrimary, 0.1)
                    }
                  }

                  Item {
                    Layout.preferredHeight: Style.marginS
                  }
                }
              }

              EasyEffectsCard {
                panelRoot: mediaDetailsCard.panelRoot
                Layout.fillWidth: true
              }

              DashboardCard {
                panelRoot: mediaDetailsCard.panelRoot
                Layout.fillWidth: true
                Layout.preferredHeight: playersColumn2.implicitHeight + Style.marginM * 2 + Style.marginS + Math.round(20 * panelRoot.panelUnit)
                color: panelRoot.m3SurfaceContainerHigh
                radius: Style.radiusS

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginS

                  NText {
                    text: panelRoot.tr("players")
                    color: Color.mOnSurface
                    font.weight: Style.fontWeightSemiBold
                  }

                  ColumnLayout {
                    id: playersColumn2
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    Repeater {
                      model: MediaService.getAvailablePlayers()

                      PlayerRow {
                        panelRoot: mediaDetailsCard.panelRoot
                        Layout.fillWidth: true
                        playerData: modelData
                        playerIndex: index
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.marginS

        Repeater {
          model: mediaSwipeView.count
          Rectangle {
            width: mediaSwipeView.currentIndex === index ? Math.round(24 * panelRoot.panelUnit) : Math.round(8 * panelRoot.panelUnit)
            height: Math.round(8 * panelRoot.panelUnit)
            radius: height / 2
            color: mediaSwipeView.currentIndex === index ? Color.mPrimary : Color.mSurfaceVariant
            Behavior on width {
              NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.OutBack
              }
            }
            Behavior on color {
              ColorAnimation {
                duration: 300
              }
            }
          }
        }
      }
    }
  }
}
