import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

SmartPanel {
  id: root

  preferredWidth: Math.round((root.isSideBySide ? 480 : 360) * Style.uiScaleRatio)
  // Fallback only; SmartPanel uses panelContent.contentPreferredHeight when set.
  preferredHeight: Math.round((root.compactMode ? 240 : 400) * Style.uiScaleRatio)

  property var mediaMiniSettings: {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    return widget ? widget.widgetSettings : null;
  }

  function refreshMediaMiniSettings() {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    root.mediaMiniSettings = widget ? widget.widgetSettings : null;
  }

  Connections {
    target: BarService
    function onActiveWidgetsChanged() {
      root.refreshMediaMiniSettings();
    }
  }

  Connections {
    target: Settings
    function onSettingsSaved() {
      root.refreshMediaMiniSettings();
    }
  }

  readonly property string visualizerType: (mediaMiniSettings && mediaMiniSettings.visualizerType !== undefined) ? mediaMiniSettings.visualizerType : "linear"
  readonly property bool showArtistFirst: !!(mediaMiniSettings && mediaMiniSettings.showArtistFirst !== undefined ? mediaMiniSettings.showArtistFirst : true)
  readonly property bool showAlbumArt: !!(mediaMiniSettings && mediaMiniSettings.panelShowAlbumArt !== undefined ? mediaMiniSettings.panelShowAlbumArt : true)
  readonly property bool showVisualizer: !!(mediaMiniSettings && mediaMiniSettings.showVisualizer !== undefined ? mediaMiniSettings.showVisualizer : true)
  readonly property bool compactMode: !!(mediaMiniSettings && mediaMiniSettings.compactMode !== undefined ? mediaMiniSettings.compactMode : false)
  readonly property string scrollingMode: (mediaMiniSettings && mediaMiniSettings.scrollingMode !== undefined) ? mediaMiniSettings.scrollingMode : "hover"

  readonly property bool isSideBySide: root.compactMode && root.showAlbumArt

  readonly property bool needsSpectrum: root.showVisualizer && root.visualizerType !== "" && root.visualizerType !== "none" && root.isPanelOpen

  onNeedsSpectrumChanged: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("mediaplayerpanel");
    } else {
      SpectrumService.unregisterComponent("mediaplayerpanel");
    }
  }

  Component.onCompleted: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("mediaplayerpanel");
    }
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent("mediaplayerpanel");
  }

  panelContent: Item {
    id: playerContent
    anchors.fill: parent

    property real contentPreferredHeight: mainLayout.implicitHeight + Style.paddingCard * 2

    property Component visualizerSource: {
      switch (root.visualizerType) {
      case "linear":
        return linearComponent;
      case "mirrored":
        return mirroredComponent;
      case "wave":
        return waveComponent;
      default:
        return null;
      }
    }

    ColumnLayout {
      id: mainLayout
      anchors.fill: parent
      anchors.margins: Style.paddingCard
      spacing: Style.spaceS

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.paddingCard * 2
        radius: Style.radiusCard

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.paddingCard
          spacing: Style.spaceS

          NIcon {
            icon: "music"
            pointSize: Style.fontSizeHeadlineSmall
            color: Color.mPrimary
          }

          NText {
            text: I18n.tr("common.media-player")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeTitleSmall
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          Rectangle {
            id: playerSelector
            readonly property real controlRadius: Style.radiusCapsule

            radius: controlRadius
            color: Color.mSurfaceContainerHigh
            implicitWidth: playerRow.implicitWidth + Style.spaceM * 2
            implicitHeight: Style.baseWidgetSize * 0.8
            visible: MediaService.getAvailablePlayers().length > 1
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: MediaService.currentPlayer ? MediaService.currentPlayer.identity : I18n.tr("common.media-player")
            Keys.onReturnPressed: event => {
                                    playerContextMenu.open();
                                    event.accepted = true;
                                  }
            Keys.onSpacePressed: event => {
                                   playerContextMenu.open();
                                   event.accepted = true;
                                 }

            RowLayout {
              id: playerRow
              anchors.centerIn: parent
              spacing: Style.spaceXS

              NText {
                text: MediaService.currentPlayer ? MediaService.currentPlayer.identity : "Select Player"
                pointSize: Style.fontSizeLabelLarge
                color: Color.mOnSurfaceVariant
              }
              NIcon {
                icon: "chevron-down"
                pointSize: Style.fontSizeLabelLarge
                color: Color.mOnSurfaceVariant
              }
            }

            NStateLayer {
              id: playerSelectorStateLayer
              anchors.fill: parent
              hovered: playerSelectorMouse.containsMouse
              pressed: playerSelectorMouse.pressed
              focused: playerSelector.activeFocus
              radius: playerSelector.controlRadius
              stateColor: Color.mOnSurface
            }

            NFocusRing {
              focusVisible: playerSelector.activeFocus
              targetRadius: playerSelector.controlRadius
            }

            MouseArea {
              id: playerSelectorMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPressed: mouse => playerSelectorStateLayer.rippleAt(mouse.x, mouse.y)
              onClicked: playerContextMenu.open()
            }

            Popup {
              id: playerContextMenu
              x: 0
              y: parent.height
              width: 160
              padding: Style.spaceS

              background: Rectangle {
                color: Color.mSurfaceContainerHigh
                border.color: Color.mOutlineVariant
                border.width: Style.borderS
                radius: Style.radiusMenu
              }

              contentItem: ColumnLayout {
                spacing: 0
                Repeater {
                  model: MediaService.getAvailablePlayers()
                  delegate: Rectangle {
                    id: playerItem
                    readonly property bool selected: MediaService.currentPlayer && MediaService.currentPlayer.identity === modelData.identity
                    readonly property real controlRadius: Style.radiusControl

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(40 * Style.uiScaleRatio)
                    color: selected ? Color.mSecondaryContainer : "transparent"
                    radius: controlRadius
                    activeFocusOnTab: true
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData.identity
                    Accessible.selected: selected
                    Keys.onReturnPressed: event => {
                                            MediaService.currentPlayer = modelData;
                                            playerContextMenu.close();
                                            event.accepted = true;
                                          }
                    Keys.onSpacePressed: event => {
                                           MediaService.currentPlayer = modelData;
                                           playerContextMenu.close();
                                           event.accepted = true;
                                         }

                    NStateLayer {
                      id: playerItemStateLayer
                      anchors.fill: parent
                      hovered: itemMouse.containsMouse
                      pressed: itemMouse.pressed
                      focused: playerItem.activeFocus
                      radius: playerItem.controlRadius
                      stateColor: Color.mOnSurface
                    }

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: Style.spaceS
                      spacing: Style.spaceS

                      NIcon {
                        visible: playerItem.selected
                        icon: "check"
                        color: Color.mOnSecondaryContainer
                        pointSize: Style.fontSizeBodySmall
                      }

                      NText {
                        text: modelData.identity
                        pointSize: Style.fontSizeBodySmall
                        color: playerItem.selected ? Color.mOnSecondaryContainer : Color.mOnSurface
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                    }

                    NFocusRing {
                      focusVisible: playerItem.activeFocus
                      targetRadius: playerItem.controlRadius
                    }

                    MouseArea {
                      id: itemMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onPressed: mouse => playerItemStateLayer.rippleAt(mouse.x, mouse.y)
                      onClicked: {
                        MediaService.currentPlayer = modelData;
                        playerContextMenu.close();
                      }
                    }
                  }
                }
              }
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: mediaContentGrid.implicitHeight + Style.paddingCard * 2
        radius: Style.radiusCard

        // Visualizer background for content area
        Loader {
          id: visualizerLoader
          anchors.fill: parent
          active: root.needsSpectrum && !root.showAlbumArt
          sourceComponent: visualizerSource
          visible: active
          opacity: 0.2
        }

        GridLayout {
          id: mediaContentGrid
          anchors.fill: parent
          anchors.leftMargin: Style.paddingCard
          anchors.rightMargin: Style.paddingCard
          anchors.topMargin: Style.paddingCard
          anchors.bottomMargin: Style.paddingCard
          columns: root.isSideBySide ? 2 : 1
          columnSpacing: Style.spaceM
          rowSpacing: root.compactMode ? Style.spaceM : Style.spaceS

          // Album Art (Vertical in normal, Horizontal in compact)
          Item {
            id: albumArtItem
            readonly property real compactArtSize: Math.round(110 * Style.uiScaleRatio)
            readonly property bool artSizeKnown: artSizeProbe.status === Image.Ready && artSizeProbe.sourceSize.width > 0 && artSizeProbe.sourceSize.height > 0
            readonly property real artAspectRatio: artSizeKnown ? artSizeProbe.sourceSize.width / artSizeProbe.sourceSize.height : 1
            // Non-compact: height from width÷aspect so grid implicit height does not depend on panel height (no layout loop).
            readonly property real artBoxW: root.compactMode ? compactArtSize : Math.max(parent.width, 1)
            readonly property real artBoxH: root.compactMode ? compactArtSize : (artBoxW / Math.max(artAspectRatio, 0.001))
            readonly property real fitArtW: artBoxW / artBoxH > artAspectRatio ? artBoxH * artAspectRatio : artBoxW
            readonly property real fitArtH: artBoxW / artBoxH > artAspectRatio ? artBoxH : artBoxW / artAspectRatio

            Layout.preferredWidth: fitArtW
            Layout.preferredHeight: fitArtH
            Layout.minimumWidth: fitArtW
            Layout.maximumWidth: fitArtW
            Layout.minimumHeight: fitArtH
            Layout.maximumHeight: fitArtH
            Layout.fillWidth: false
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignHCenter
            visible: root.showAlbumArt

            Image {
              id: artSizeProbe
              visible: false
              asynchronous: true
              source: MediaService.trackArtUrl
            }

            NImageRounded {
              anchors.fill: parent
              radius: Style.radiusCard
              imagePath: MediaService.trackArtUrl
              imageFillMode: Image.PreserveAspectCrop
              fallbackIcon: "disc"
              fallbackIconSize: root.compactMode ? Style.fontSizeDisplaySmall : Style.fontSizeDisplayLarge
              borderWidth: 0
            }

            Loader {
              anchors.fill: parent
              anchors.margins: Style.spaceS
              z: 2
              active: !!(root.needsSpectrum && root.showAlbumArt)
              sourceComponent: visualizerSource
            }
          }

          ColumnLayout {
            id: controlsLayout
            Layout.preferredWidth: root.compactMode ? -1 : albumArtItem.width
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: root.compactMode
            spacing: root.compactMode ? Style.spaceXS : Style.spaceS

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              NScrollText {
                Layout.fillWidth: true
                maxWidth: parent.width
                text: {
                  if (root.showArtistFirst) {
                    return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
                  } else {
                    return MediaService.trackTitle || "No Media";
                  }
                }

                scrollMode: {
                  if (root.scrollingMode === "always")
                    return NScrollText.ScrollMode.Always;
                  if (root.scrollingMode === "hover")
                    return NScrollText.ScrollMode.Hover;
                  return NScrollText.ScrollMode.Never;
                }
                fadeExtent: 0.01
                fadeCornerRadius: Style.radiusCard

                delegate: NText {
                  pointSize: root.compactMode ? Style.fontSizeTitleMedium : Style.fontSizeHeadlineSmall
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  horizontalAlignment: root.isSideBySide ? Text.AlignLeft : Text.AlignHCenter
                  elide: Text.ElideNone
                  wrapMode: Text.NoWrap
                }
              }

              NScrollText {
                Layout.fillWidth: true
                maxWidth: parent.width
                text: {
                  if (root.showArtistFirst) {
                    return MediaService.trackTitle || "No Media";
                  } else {
                    return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
                  }
                }

                scrollMode: {
                  if (root.scrollingMode === "always")
                    return NScrollText.ScrollMode.Always;
                  if (root.scrollingMode === "hover")
                    return NScrollText.ScrollMode.Hover;
                  return NScrollText.ScrollMode.Never;
                }
                fadeExtent: 0.01
                fadeCornerRadius: Style.radiusCard

                delegate: NText {
                  pointSize: root.compactMode ? Style.fontSizeBodySmall : Style.fontSizeBodyMedium
                  color: Color.mOnSurfaceVariant
                  horizontalAlignment: root.isSideBySide ? Text.AlignLeft : Text.AlignHCenter
                  elide: Text.ElideNone
                  wrapMode: Text.NoWrap
                }
              }
            }

            Item {
              id: progressWrapper
              visible: (MediaService.currentPlayer && MediaService.trackLength > 0)
              Layout.fillWidth: true
              Layout.preferredHeight: progressColumn.implicitHeight

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
                id: seekDebounce
                interval: 75
                repeat: false
                onTriggered: {
                  if (MediaService.isSeeking && progressWrapper.localSeekRatio >= 0) {
                    const next = Math.max(0, Math.min(1, progressWrapper.localSeekRatio));
                    if (progressWrapper.lastSentSeekRatio < 0 || Math.abs(next - progressWrapper.lastSentSeekRatio) >= progressWrapper.seekEpsilon) {
                      MediaService.seekByRatio(next);
                      progressWrapper.lastSentSeekRatio = next;
                    }
                  }
                }
              }

              ColumnLayout {
                id: progressColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 2

                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.compactMode ? (Style.baseWidgetSize * 0.4) : (Style.baseWidgetSize * 0.5)

                  NSlider {
                    id: progressSlider
                    anchors.fill: parent
                    from: 0
                    to: 1
                    stepSize: 0
                    snapAlways: false
                    enabled: MediaService.trackLength > 0 && MediaService.canSeek
                    heightRatio: 0.4
                    wavy: MediaService.isPlaying

                    value: (!MediaService.isSeeking) ? progressWrapper.progressRatio : (progressWrapper.localSeekRatio >= 0 ? progressWrapper.localSeekRatio : 0)

                    onMoved: {
                      progressWrapper.localSeekRatio = value;
                      seekDebounce.restart();
                    }
                    onPressedChanged: {
                      if (pressed) {
                        MediaService.isSeeking = true;
                        progressWrapper.localSeekRatio = value;
                        MediaService.seekByRatio(value);
                        progressWrapper.lastSentSeekRatio = value;
                      } else {
                        seekDebounce.stop();
                        MediaService.seekByRatio(value);
                        MediaService.isSeeking = false;
                        progressWrapper.localSeekRatio = -1;
                        progressWrapper.lastSentSeekRatio = -1;
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 0

                  NText {
                    text: MediaService.positionString || "0:00"
                    pointSize: Style.fontSizeLabelLarge
                    color: Color.mOnSurfaceVariant
                    visible: progressWrapper.visible
                  }

                  Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                  }

                  NText {
                    text: MediaService.lengthString || "0:00"
                    pointSize: Style.fontSizeLabelLarge
                    color: Color.mOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                    visible: progressWrapper.visible
                  }
                }
              }
            }

            Item {
              Layout.preferredHeight: root.isSideBySide ? Style.spaceS : Style.spaceXS
            }

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: root.isSideBySide ? Style.spaceM : Style.spaceL

              NIconButton {
                icon: "media-prev"
                baseSize: root.compactMode ? (Style.baseWidgetSize * 0.9) : (Style.baseWidgetSize * 1.2)
                onClicked: MediaService.previous()
              }

              Rectangle {
                id: playButton
                readonly property real controlRadius: Style.radiusCapsule

                implicitWidth: root.compactMode ? (Style.baseWidgetSize * 1.3) : (Style.baseWidgetSize * 1.8)
                implicitHeight: root.compactMode ? (Style.baseWidgetSize * 1.3) : (Style.baseWidgetSize * 1.8)
                radius: controlRadius
                color: Color.mPrimary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: MediaService.isPlaying ? I18n.tr("common.pause") : I18n.tr("common.play")
                Keys.onReturnPressed: event => {
                                        MediaService.playPause();
                                        event.accepted = true;
                                      }
                Keys.onSpacePressed: event => {
                                       MediaService.playPause();
                                       event.accepted = true;
                                     }

                NStateLayer {
                  id: playStateLayer
                  anchors.fill: parent
                  hovered: playMouse.containsMouse
                  pressed: playMouse.pressed
                  focused: playButton.activeFocus
                  radius: playButton.controlRadius
                  stateColor: Color.mOnPrimary
                }

                NIcon {
                  anchors.centerIn: parent
                  icon: MediaService.isPlaying ? "media-pause" : "media-play"
                  pointSize: root.compactMode ? Style.fontSizeTitleMedium : Style.fontSizeHeadlineSmall
                  color: Color.mOnPrimary
                }

                NFocusRing {
                  focusVisible: playButton.activeFocus
                  targetRadius: playButton.controlRadius
                }

                MouseArea {
                  id: playMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onPressed: mouse => playStateLayer.rippleAt(mouse.x, mouse.y)
                  onClicked: MediaService.playPause()
                }
              }
              NIconButton {
                icon: "media-next"
                baseSize: root.compactMode ? (Style.baseWidgetSize * 0.9) : (Style.baseWidgetSize * 1.2)
                onClicked: MediaService.next()
              }
            }
          }
        }
      }
    }
  }

  // Visualizer Components
  Component {
    id: linearComponent
    NLinearSpectrum {
      width: parent.width - Style.spaceS
      height: 20
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.4
      barPosition: Settings.getBarPositionForScreen(root.screen?.name)
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: mirroredComponent
    NMirroredSpectrum {
      width: parent.width - Style.spaceS
      height: parent.height - Style.spaceS
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.4
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: waveComponent
    NWaveSpectrum {
      width: parent.width - Style.spaceS
      height: parent.height - Style.spaceS
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.4
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }
}
