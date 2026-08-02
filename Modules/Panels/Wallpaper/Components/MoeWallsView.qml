import QtQuick
import QtMultimedia
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property string screenName: ""

  Component.onCompleted: {
    if (MoeWallsService.currentResults.length === 0 && !MoeWallsService.fetching) {
      MoeWallsService.search("", 1);
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    // Top Search & Page controls
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NTextInput {
        id: moeSearchInput
        placeholderText: "Pesquisar Live Wallpapers em MoeWalls..."
        Layout.fillWidth: true
        onEditingFinished: {
          MoeWallsService.search(text, 1);
        }
      }

      NIconButton {
        icon: "search"
        tooltipText: "Buscar"
        onClicked: MoeWallsService.search(moeSearchInput.text, 1)
      }

      NIconButton {
        icon: "chevron-left"
        enabled: MoeWallsService.currentPage > 1 && !MoeWallsService.fetching
        onClicked: MoeWallsService.search(moeSearchInput.text, MoeWallsService.currentPage - 1)
      }

      NText {
        text: "Página " + MoeWallsService.currentPage
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NIconButton {
        icon: "chevron-right"
        enabled: !MoeWallsService.fetching
        onClicked: MoeWallsService.search(moeSearchInput.text, MoeWallsService.currentPage + 1)
      }
    }

    // Grid View for Live Wallpapers
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      NBusyIndicator {
        anchors.centerIn: parent
        visible: MoeWallsService.fetching
        running: visible
        size: 36
      }

      NText {
        anchors.centerIn: parent
        visible: !MoeWallsService.fetching && MoeWallsService.currentResults.length === 0
        text: "Nenhum Live Wallpaper encontrado."
        color: Color.mOnSurfaceVariant
      }

      GridView {
        id: moeGrid
        anchors.fill: parent
        anchors.margins: Style.marginM
        cellWidth: Math.floor(width / Math.max(2, Math.floor(width / 220)))
        cellHeight: Math.floor(cellWidth * 0.65) + 30
        clip: true
        visible: !MoeWallsService.fetching && MoeWallsService.currentResults.length > 0
        model: MoeWallsService.currentResults

        delegate: Item {
          required property var modelData
          required property int index

          width: moeGrid.cellWidth
          height: moeGrid.cellHeight

          NBox {
            anchors.fill: parent
            anchors.margins: Style.marginS
            color: cardMouse.containsMouse ? Color.mSurfaceVariant : Color.mSurface
            radius: Style.radiusS
            clip: true

            MouseArea {
              id: cardMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                ToastService.showNotice("MoeWalls", "Baixando live wallpaper...", "download", 2500);
                MoeWallsService.downloadVideo(modelData, function(path) {
                  WallpaperService.changeWallpaper(path, root.screenName, WallpaperService.wallpaperSelectionAppearance);
                  ToastService.showNotice("MoeWalls", "Live Wallpaper aplicado!", "check", 3000);
                });
              }
            }

            ColumnLayout {
              anchors.fill: parent
              spacing: 0

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Image {
                  id: thumbImg
                  anchors.fill: parent
                  source: modelData.thumb || ""
                  fillMode: Image.PreserveAspectCrop
                  smooth: true
                }

                // Live Motion Video Preview on Hover
                Loader {
                  id: videoHoverLoader
                  anchors.fill: parent
                  active: cardMouse.containsMouse && modelData.video && modelData.video !== ""

                  sourceComponent: Item {
                    anchors.fill: parent

                    MediaPlayer {
                      id: hoverPlayer
                      source: modelData.video || ""
                      loops: MediaPlayer.Infinite
                      videoOutput: hoverVideoOut
                      audioOutput: AudioOutput { muted: true }
                      onSourceChanged: {
                        if (source !== "") {
                          play();
                        }
                      }
                      onMediaStatusChanged: {
                        if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) {
                          play();
                        }
                      }
                      Component.onCompleted: play()
                    }

                    VideoOutput {
                      id: hoverVideoOut
                      anchors.fill: parent
                      fillMode: VideoOutput.PreserveAspectCrop
                    }
                  }
                }

                // Live WebM badge
                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: 6
                  height: 20
                  width: cardMouse.containsMouse ? 92 : 48
                  radius: 10
                  color: cardMouse.containsMouse ? Color.mSecondary : Color.mPrimary

                  Behavior on width { NumberAnimation { duration: 150 } }

                  NText {
                    anchors.centerIn: parent
                    text: cardMouse.containsMouse ? "EM MOVIMENTO" : "LIVE"
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                    color: Color.mOnPrimary
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 32
                color: Color.mSurface

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8

                  NText {
                    text: modelData.name || "Live Wallpaper"
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  NIconButton {
                    icon: "download"
                    tooltipText: "Baixar e Aplicar Live Wallpaper"
                    baseSize: 24
                    onClicked: {
                      ToastService.showNotice("MoeWalls", "Baixando live wallpaper...", "download", 2500);
                      MoeWallsService.downloadVideo(modelData, function(path) {
                        WallpaperService.changeWallpaper(path, root.screenName, WallpaperService.wallpaperSelectionAppearance);
                        ToastService.showNotice("MoeWalls", "Live Wallpaper aplicado!", "check", 3000);
                      });
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
