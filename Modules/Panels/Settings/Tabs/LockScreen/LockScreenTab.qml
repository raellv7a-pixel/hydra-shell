import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
  id: root
  spacing: Style.marginL

  Component.onCompleted: {
    LockThemeService.fetchCatalog();
  }

  // No TabBar needed anymore, just directly show the content

  NHeader {
    label: "Installed SDDM Themes"
    description: "Themes available locally. Click 'Apply' to set as your system SDDM theme."
  }

  NGridView {
    id: installedGrid
    Layout.fillWidth: true
    // Dynamic height based on elements
    Layout.preferredHeight: Math.max(220, (Math.ceil(LockThemeService.installedThemes.length / 2) * 230))
    model: LockThemeService.installedThemes
    cellWidth: width / 2
    cellHeight: 230
    interactive: false
    delegate: Item {
      width: installedGrid.cellWidth
      height: installedGrid.cellHeight

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.marginS
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.4)
        radius: Style.radiusM
        border.color: (Settings.data.general && Settings.data.general.sddmTheme === modelData.slug) ? Color.mPrimary : Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.1)
        border.width: 2
        
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.5)
            radius: Style.radiusS
            clip: true
            
            AnimatedImage {
              anchors.fill: parent
              source: modelData.preview_url || ""
              fillMode: Image.PreserveAspectCrop
              visible: source.toString() !== ""
            }
          }
          
          RowLayout {
            Layout.fillWidth: true
            NText {
              Layout.fillWidth: true
              text: modelData.name
              font.bold: true
              pointSize: Style.fontSizeS
            }
            NButton {
              text: "Apply"
              onClicked: {
                LockThemeService.applyTheme(modelData.slug, modelData.path);
              }
            }
          }
        }
      }
    }
  }

  NHeader {
    label: "Theme Store (Qylock Catalog)"
    description: "Browse and install themes from the upstream Qylock repository."
  }

  RowLayout {
    Layout.fillWidth: true
    NButton {
      text: "Refresh Catalog"
      icon: "refresh"
      onClicked: LockThemeService.fetchCatalog()
    }
    BusyIndicator {
      running: LockThemeService.isFetchingCatalog || LockThemeService.isInstalling
      visible: running
    }
  }

  NGridView {
    id: catalogGrid
    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(220, (Math.ceil(LockThemeService.catalogThemes.length / 2) * 230))
    model: LockThemeService.catalogThemes
    cellWidth: width / 2
    cellHeight: 230
    interactive: false
    delegate: Item {
      width: catalogGrid.cellWidth
      height: catalogGrid.cellHeight

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.marginS
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.4)
        radius: Style.radiusM
        border.color: Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.1)
        border.width: 1
        
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.5)
            radius: Style.radiusS
            clip: true
            
            AnimatedImage {
              anchors.fill: parent
              source: modelData.preview_url || ""
              fillMode: Image.PreserveAspectCrop
              visible: source.toString() !== ""
            }
          }
          
          RowLayout {
            Layout.fillWidth: true
            NText {
              Layout.fillWidth: true
              text: modelData.name
              font.bold: true
              pointSize: Style.fontSizeS
            }
            NButton {
              text: modelData.installed ? "Installed" : "Install"
              enabled: !modelData.installed && !LockThemeService.isInstalling
              icon: "download"
              onClicked: {
                LockThemeService.installTheme(modelData.slug);
              }
            }
          }
        }
      }
    }
  }
}
