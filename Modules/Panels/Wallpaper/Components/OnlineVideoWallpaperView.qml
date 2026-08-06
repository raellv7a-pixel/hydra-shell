import QtQuick
import QtMultimedia
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  required property var providerService
  required property string providerName
  property string screenName: ""
  property string applyingVideoId: ""

  readonly property int resultCount: providerService?.currentResults?.length || 0

  Component.onCompleted: {
    if (resultCount === 0 && !providerService.fetching) {
      providerService.search("", 1);
    }
  }

  Connections {
    target: root.providerService
    ignoreUnknownSignals: true

    function onVideoDownloadFailed(videoId, error) {
      ToastService.showError(root.providerName, error || I18n.tr("wallpaper.live-video.download-failed"));
    }
  }

  function downloadAndApply(item) {
    if (applyingVideoId !== "") {
      return;
    }
    applyingVideoId = String(item?.id || "");
    ToastService.showNotice(providerName, I18n.tr("wallpaper.live-video.downloading"), "download", 2500);
    providerService.downloadVideo(item, path => {
                                    applyingVideoId = "";
                                    if (path === "") {
                                      return;
                                    }
                                    WallpaperService.changeWallpaper(path, screenName, WallpaperService.wallpaperSelectionAppearance);
                                    ToastService.showNotice(providerName, I18n.tr("wallpaper.live-video.applied"), "check", 3000);
                                  });
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NTextInput {
        id: searchInput
        inputIconName: "search"
        placeholderText: I18n.tr("wallpaper.live-video.search-placeholder", { source: root.providerName })
        Layout.fillWidth: true
        onEditingFinished: root.providerService.search(text, 1)
      }

      NIconButton {
        icon: "search"
        tooltipText: I18n.tr("common.search")
        enabled: !root.providerService.fetching
        onClicked: root.providerService.search(searchInput.text, 1)
      }

      NIconButton {
        icon: "chevron-left"
        tooltipText: I18n.tr("common.previous")
        enabled: root.providerService.currentPage > 1 && !root.providerService.fetching
        onClicked: root.providerService.search(searchInput.text, root.providerService.currentPage - 1)
      }

      NText {
        text: I18n.tr("wallpaper.live-video.page", { page: root.providerService.currentPage })
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NIconButton {
        icon: "chevron-right"
        tooltipText: I18n.tr("common.next")
        enabled: root.resultCount > 0 && !root.providerService.fetching
        onClicked: root.providerService.search(searchInput.text, root.providerService.currentPage + 1)
      }
    }

    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.mSurfaceContainerLow
      radius: Style.radiusL

      NBusyIndicator {
        anchors.centerIn: parent
        visible: root.providerService.fetching
        running: visible
        size: 36
      }

      ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.margin2L, 460 * Style.uiScaleRatio)
        visible: !root.providerService.fetching && root.resultCount === 0
        spacing: Style.marginM

        NIcon {
          icon: root.providerService.lastError ? "alert-circle" : "video"
          pointSize: Style.fontSizeXXL
          color: root.providerService.lastError ? Color.mError : Color.mOnSurfaceVariant
          Layout.alignment: Qt.AlignHCenter
        }

        NText {
          text: root.providerService.lastError || I18n.tr("wallpaper.live-video.no-results")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
        }
      }

      GridView {
        id: videoGrid
        anchors.fill: parent
        anchors.margins: Style.marginM
        cellWidth: Math.floor(width / Math.max(2, Math.floor(width / (220 * Style.uiScaleRatio))))
        cellHeight: Math.floor(cellWidth * 0.65) + 30 * Style.uiScaleRatio
        clip: true
        visible: !root.providerService.fetching && root.resultCount > 0
        model: root.providerService.currentResults

        delegate: Item {
          id: delegateRoot

          required property var modelData
          required property int index

          width: videoGrid.cellWidth
          height: videoGrid.cellHeight
          activeFocusOnTab: true
          Accessible.role: Accessible.ListItem
          Accessible.name: modelData.name || modelData.id || root.providerName
          Keys.onReturnPressed: root.downloadAndApply(modelData)
          Keys.onEnterPressed: root.downloadAndApply(modelData)

          NBox {
            anchors.fill: parent
            anchors.margins: Style.marginS
            color: cardMouse.containsMouse ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh
            radius: Style.radiusL
            clip: true

            MouseArea {
              id: cardMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: root.applyingVideoId === ""
              onClicked: root.downloadAndApply(delegateRoot.modelData)
            }

            ColumnLayout {
              anchors.fill: parent
              spacing: 0

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Image {
                  id: thumbnail
                  anchors.fill: parent
                  source: delegateRoot.modelData.thumb || ""
                  sourceSize: Qt.size(480, 270)
                  asynchronous: true
                  fillMode: Image.PreserveAspectCrop
                  smooth: true
                }

                NIcon {
                  anchors.centerIn: parent
                  visible: thumbnail.status === Image.Loading || thumbnail.status === Image.Error
                  icon: thumbnail.status === Image.Error ? "alert-circle" : "image"
                  pointSize: Style.fontSizeXL
                  color: Color.mOnSurfaceVariant
                }

                Loader {
                  id: videoHoverLoader
                  anchors.fill: parent
                  active: root.visible && cardMouse.containsMouse && delegateRoot.modelData.video && root.applyingVideoId !== String(delegateRoot.modelData.id || "")
                  asynchronous: true

                  sourceComponent: Component {
                    Item {
                      MediaPlayer {
                        id: hoverPlayer
                        source: delegateRoot.modelData.video || ""
                        loops: MediaPlayer.Infinite
                        videoOutput: hoverVideoOutput
                        audioOutput: AudioOutput { muted: true }
                        Component.onCompleted: play()
                        Component.onDestruction: stop()
                      }

                      VideoOutput {
                        id: hoverVideoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                      }
                    }
                  }
                }

                Rectangle {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.marginS
                  height: 20 * Style.uiScaleRatio
                  width: cardMouse.containsMouse ? 108 * Style.uiScaleRatio : 48 * Style.uiScaleRatio
                  radius: height / 2
                  color: cardMouse.containsMouse ? Color.mSecondaryContainer : Color.mPrimaryContainer

                  Behavior on width {
                    NumberAnimation { duration: Style.animationFast }
                  }

                  NText {
                    anchors.centerIn: parent
                    text: cardMouse.containsMouse ? I18n.tr("wallpaper.live-video.motion-badge") : I18n.tr("wallpaper.live-video.live-badge")
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                    color: cardMouse.containsMouse ? Color.mOnSecondaryContainer : Color.mOnPrimaryContainer
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32 * Style.uiScaleRatio
                color: cardMouse.containsMouse ? Color.mPrimaryContainer : Color.mSurfaceContainerHigh

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginS
                  anchors.rightMargin: Style.marginS

                  NText {
                    text: delegateRoot.modelData.name || I18n.tr("wallpaper.live-video.unnamed")
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  NText {
                    visible: !!delegateRoot.modelData.resolution
                    text: delegateRoot.modelData.resolution || ""
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                  }

                  NIconButton {
                    icon: "download"
                    tooltipText: I18n.tr("wallpaper.live-video.download-and-apply")
                    baseSize: 24 * Style.uiScaleRatio
                    onClicked: root.downloadAndApply(delegateRoot.modelData)
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
