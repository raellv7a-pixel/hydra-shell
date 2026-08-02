import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.85)
  z: 100
  visible: opacity > 0
  opacity: 0

  property var activeWallpaper: null
  property string highResUrl: (activeWallpaper && typeof WallhavenService !== "undefined") ? WallhavenService.getWallpaperUrl(activeWallpaper) : ""
  property string thumbnailUrl: (activeWallpaper && typeof WallhavenService !== "undefined") ? WallhavenService.getThumbnailUrl(activeWallpaper, "large") : ""

  signal findSimilarRequested(string wallpaperId)
  signal applyRequested(var wallpaper)

  Behavior on opacity { NumberAnimation { duration: 200 } }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true // Block hover from falling through
    onClicked: root.hide()
    onWheel: root.hide()
  }

  function show(wallpaper) {
    activeWallpaper = wallpaper;
    opacity = 1;
  }
  
  function hide() {
    opacity = 0;
  }

  Item {
    anchors.fill: parent
    anchors.margins: Style.margin2L

    ColumnLayout {
      anchors.centerIn: parent
      width: Math.min(parent.width * 0.9, 800)
      height: Math.min(parent.height * 0.9, 600)
      spacing: Style.marginL

      // Main image
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NBusyIndicator {
          anchors.centerIn: parent
          visible: img.status === Image.Loading
        }

        Image {
          id: img
          anchors.fill: parent
          source: root.highResUrl !== "" ? root.highResUrl : root.thumbnailUrl
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        // Apply Button Over Image
        NButton {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.margins: Style.marginL
          text: I18n.tr("common.apply") || "Aplicar"
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: {
            root.applyRequested(root.activeWallpaper);
            root.hide();
          }
        }
      }

      // Metadata and Actions
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        // Resolution
        NBox {
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          Layout.preferredHeight: 40
          Layout.preferredWidth: implicitWidth + Style.marginL
          
          RowLayout {
            anchors.centerIn: parent
            spacing: Style.marginS
            NIcon { icon: "maximize"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
            NText { 
              text: root.activeWallpaper && root.activeWallpaper.resolution ? root.activeWallpaper.resolution : ""
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Find Similar
        NButton {
          text: "Buscar Similares"
          icon: "image-search"
          backgroundColor: Color.mSurfaceVariant
          textColor: Color.mOnSurface
          onClicked: {
            if (root.activeWallpaper) {
              root.findSimilarRequested(root.activeWallpaper.id);
            }
            root.hide();
          }
        }

        // Open in Browser
        NIconButton {
          icon: "external-link"
          tooltipText: "Abrir no Navegador"
          baseSize: 40
          colorBg: Color.mSurfaceVariant
          colorFg: Color.mOnSurface
          onClicked: {
            if (root.activeWallpaper && root.activeWallpaper.url) {
              Qt.openUrlExternally(root.activeWallpaper.url);
            }
          }
        }
        
        NIconButton {
          icon: "close"
          tooltipText: I18n.tr("common.close")
          baseSize: 40
          colorBg: Color.mSurfaceVariant
          colorFg: Color.mOnSurface
          onClicked: root.hide()
        }
      }
    }
  }
}
