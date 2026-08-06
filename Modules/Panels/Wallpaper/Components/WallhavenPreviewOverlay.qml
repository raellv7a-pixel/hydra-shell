import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  anchors.fill: parent
  color: Qt.alpha(Color.mShadow, 0.78)
  z: 100
  visible: opacity > 0 || releaseTimer.running
  opacity: 0
  focus: visible

  property var activeWallpaper: null
  property bool loadOriginal: false
  property bool previewFailed: false
  readonly property string highResUrl: activeWallpaper && typeof WallhavenService !== "undefined" ? WallhavenService.getWallpaperUrl(activeWallpaper) : ""
  readonly property string thumbnailUrl: activeWallpaper && typeof WallhavenService !== "undefined" ? WallhavenService.getThumbnailUrl(activeWallpaper, "large") : ""
  readonly property string previewUrl: loadOriginal && highResUrl !== "" ? highResUrl : thumbnailUrl
  readonly property bool downloading: activeWallpaper && typeof WallhavenService !== "undefined" && WallhavenService.isDownloading(activeWallpaper.id || "")

  signal findSimilarRequested(string wallpaperId)
  signal applyRequested(var wallpaper)

  Keys.onEscapePressed: event => {
                          root.hide();
                          event.accepted = true;
                        }

  Behavior on opacity {
    NumberAnimation {
      duration: Settings.data.general.animationDisabled ? 0 : Style.animationFast
      easing.type: root.opacity > 0 ? Easing.OutCubic : Easing.InCubic
    }
  }

  Timer {
    id: releaseTimer
    interval: Settings.data.general.animationDisabled ? 1 : Style.animationFast + 20
    onTriggered: {
      root.activeWallpaper = null;
      root.loadOriginal = false;
      root.previewFailed = false;
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: root.hide()
    onWheel: wheel => {
               root.hide();
               wheel.accepted = true;
             }
  }

  Item {
    anchors.fill: parent
    anchors.margins: Style.margin2L

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width * 0.92, 860 * Style.uiScaleRatio)
      height: Math.min(parent.height * 0.92, 640 * Style.uiScaleRatio)
      spacing: Style.marginM

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NBusyIndicator {
          anchors.centerIn: parent
          visible: previewImage.status === Image.Loading
          running: visible
        }

        Image {
          id: previewImage
          anchors.fill: parent
          source: root.previewUrl
          sourceSize.width: Math.max(1, Math.ceil(width))
          sourceSize.height: Math.max(1, Math.ceil(height))
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          cache: true

          onStatusChanged: {
            if (status !== Image.Error) {
              if (status === Image.Ready) {
                root.previewFailed = false;
              }
              return;
            }
            if (root.loadOriginal && root.thumbnailUrl !== "") {
              root.loadOriginal = false;
            } else {
              root.previewFailed = true;
            }
          }
        }

        ColumnLayout {
          anchors.centerIn: parent
          visible: root.previewFailed
          spacing: Style.marginM

          NIcon {
            icon: "photo-off"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurfaceVariant
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: I18n.tr("wallpaper.wallhaven.preview-failed")
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }

          NButton {
            text: I18n.tr("common.retry")
            icon: "refresh"
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
              root.previewFailed = false;
              previewImage.source = "";
              previewImage.source = Qt.binding(() => root.previewUrl);
            }
          }
        }

        NButton {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.margins: Style.marginL
          text: root.downloading ? I18n.tr("wallpaper.wallhaven.downloading") : I18n.tr("common.apply")
          icon: root.downloading ? "loader-2" : "check"
          enabled: !root.downloading && !root.previewFailed
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: {
            root.applyRequested(root.activeWallpaper);
            root.hide();
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: metadataLayout.implicitHeight + Style.marginL
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL

        ColumnLayout {
          id: metadataLayout
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "photo"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXXS

              NText {
                Layout.fillWidth: true
                text: root.primaryMetadata()
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightMedium
                elide: Text.ElideRight
              }

              NText {
                Layout.fillWidth: true
                text: root.secondaryMetadata()
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                elide: Text.ElideRight
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Item {
              Layout.fillWidth: true
            }

            NButton {
              visible: root.highResUrl !== "" && !root.loadOriginal
              text: I18n.tr("wallpaper.wallhaven.load-original")
              icon: "maximize"
              backgroundColor: Color.mSurfaceContainerHighest
              textColor: Color.mOnSurface
              onClicked: {
                root.previewFailed = false;
                root.loadOriginal = true;
              }
            }

            NButton {
              text: I18n.tr("wallpaper.wallhaven.find-similar")
              icon: "image-search"
              backgroundColor: Color.mSecondaryContainer
              textColor: Color.mOnSecondaryContainer
              onClicked: {
                if (root.activeWallpaper) {
                  root.findSimilarRequested(root.activeWallpaper.id);
                }
                root.hide();
              }
            }

            NIconButton {
              icon: "external-link"
              tooltipText: I18n.tr("wallpaper.wallhaven.open-browser")
              baseSize: 40 * Style.uiScaleRatio
              colorBg: Color.mSurfaceContainerHighest
              colorFg: Color.mOnSurfaceVariant
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              enabled: root.activeWallpaper && root.activeWallpaper.url
              onClicked: Qt.openUrlExternally(root.activeWallpaper.url)
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("common.close")
              baseSize: 40 * Style.uiScaleRatio
              colorBg: Color.mSurfaceContainerHighest
              colorFg: Color.mOnSurfaceVariant
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: root.hide()
            }
          }
        }
      }
    }
  }

  function show(wallpaper) {
    releaseTimer.stop();
    activeWallpaper = wallpaper;
    loadOriginal = false;
    previewFailed = false;
    opacity = 1;
    forceActiveFocus();
  }

  function hide() {
    opacity = 0;
    releaseTimer.restart();
  }

  function primaryMetadata() {
    if (!activeWallpaper) {
      return "";
    }
    const resolution = activeWallpaper.resolution || "—";
    const format = activeWallpaper.file_type ? String(activeWallpaper.file_type).replace("image/", "").toUpperCase() : "—";
    const size = formatFileSize(Number(activeWallpaper.file_size) || 0);
    return I18n.tr("wallpaper.wallhaven.metadata-primary", {
                     resolution: resolution,
                     format: format,
                     size: size
                   });
  }

  function secondaryMetadata() {
    if (!activeWallpaper) {
      return "";
    }
    return I18n.tr("wallpaper.wallhaven.metadata-secondary", {
                     category: capitalize(activeWallpaper.category || "—"),
                     purity: String(activeWallpaper.purity || "—").toUpperCase(),
                     views: Number(activeWallpaper.views) || 0,
                     favorites: Number(activeWallpaper.favorites) || 0
                   });
  }

  function formatFileSize(bytes) {
    if (bytes <= 0) {
      return "—";
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(0) + " KiB";
    }
    return (bytes / (1024 * 1024)).toFixed(1) + " MiB";
  }

  function capitalize(value) {
    const text = String(value || "");
    return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text;
  }
}
