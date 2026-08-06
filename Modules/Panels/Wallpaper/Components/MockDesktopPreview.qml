import QtQuick
import QtMultimedia
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property string wallpaperPath: ""
  property string screenName: ""
  property string currentFillMode: Settings.data.wallpaper.fillMode || "crop"
  property bool previewDarkMode: Settings.data.colorSchemes.darkMode

  readonly property bool isVideoPath: {
    var p = root.wallpaperPath.toLowerCase();
    return p.endsWith(".webm") || p.endsWith(".mp4") || p.endsWith(".mkv") || p.endsWith(".mov");
  }
  property string activeVideoSource: ""

  // Candidate palette for wallpaperPath, computed read-only (no side effects on the
  // live theme) via TemplateProcessor.previewWallpaperPalette(). null while loading,
  // unavailable (video — no frame extraction today), or on failure; paletteColor()
  // falls back to the live Color.* singleton in all those cases.
  property var candidatePalette: null

  function paletteColor(key) {
    var mode = root.previewDarkMode ? "dark" : "light";
    if (candidatePalette && candidatePalette[mode] && candidatePalette[mode][key] !== undefined) {
      return candidatePalette[mode][key];
    }
    return Color[key];
  }

  // Snapshot of the live theme, restricted to the same role set candidatePalette
  // uses (TemplateProcessor.colorKeyMap) — what WallpaperThemeDiffBadge diffs against.
  function _currentColorSnapshot() {
    var snapshot = {};
    var keys = Object.keys(TemplateProcessor.colorKeyMap);
    for (var i = 0; i < keys.length; i++) {
      snapshot[keys[i]] = Color[keys[i]];
    }
    return snapshot;
  }

  function _requestCandidatePalette() {
    root.candidatePalette = null;
    if (root.isVideoPath || root.wallpaperPath === "") {
      return;
    }
    TemplateProcessor.previewWallpaperPalette(root.wallpaperPath, TemplateProcessor.getSchemeType(), function (result) {
      if (!result || root.wallpaperPath === "") {
        return;
      }
      root.candidatePalette = {
        "dark": TemplateProcessor.mapToColorKeys(result.dark),
        "light": TemplateProcessor.mapToColorKeys(result.light)
      };
      if (Settings.data.colorSchemes.schedulingMode === "wallpaper" && result.recommendedMode) {
        root.previewDarkMode = (result.recommendedMode === "dark");
      }
    });
  }

  Timer {
    id: paletteDebounceTimer
    interval: 350
    repeat: false
    onTriggered: root._requestCandidatePalette()
  }

  onWallpaperPathChanged: {
    refreshVideoSource();
    paletteDebounceTimer.restart();
  }
  Component.onCompleted: refreshVideoSource()

  function refreshVideoSource() {
    videoSourceTimer.stop();
    activeVideoSource = "";
    if (isVideoPath && wallpaperPath !== "") {
      videoSourceTimer.restart();
    }
  }

  Timer {
    id: videoSourceTimer
    interval: 100
    repeat: false
    onTriggered: root.activeVideoSource = root.wallpaperPath.startsWith("/") ? "file://" + root.wallpaperPath : root.wallpaperPath
  }

  signal applyRequested(string path, string fillMode)

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    // Toolbar / Controls bar
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: 48
      color: Color.mSurfaceContainerHigh
      radius: Style.radiusL

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginXS
        anchors.bottomMargin: Style.marginXS
        spacing: Style.marginS

        NText {
          text: "Modo:"
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }

        NComboBox {
          id: fillModeCombo
          Layout.preferredWidth: 105
          model: [
            { "key": "crop", "name": "Cortar" },
            { "key": "fit", "name": "Ajustar" },
            { "key": "stretch", "name": "Esticar" },
            { "key": "repeat", "name": "Mosaico" }
          ]
          currentKey: root.currentFillMode
          onSelected: key => {
            root.currentFillMode = key;
            Settings.data.wallpaper.fillMode = key;
          }
        }

        Item { Layout.fillWidth: true }

        WallpaperThemeDiffBadge {
          currentPalette: root._currentColorSnapshot()
          candidatePalette: root.candidatePalette ? root.candidatePalette[root.previewDarkMode ? "dark" : "light"] : null
        }

        NIconButton {
          icon: root.previewDarkMode ? "moon" : "sun"
          tooltipText: root.previewDarkMode ? "Modo Claro" : "Modo Escuro"
          baseSize: Style.baseWidgetSize * 0.8
          colorBg: root.previewDarkMode ? Color.mSecondaryContainer : Color.mSurfaceContainerHighest
          colorFg: root.previewDarkMode ? Color.mOnSecondaryContainer : Color.mOnSurfaceVariant
          colorBorder: "transparent"
          colorBorderHover: "transparent"
          onClicked: root.previewDarkMode = !root.previewDarkMode
        }

        NButton {
          text: "Aplicar"
          icon: "check"
          tooltipText: "Aplicar este papel de parede no desktop"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: {
            if (root.wallpaperPath !== "") {
              root.applyRequested(root.wallpaperPath, root.currentFillMode);
            }
          }
        }
      }
    }

    // Mock Desktop Screen Container (Maintains 16:9 Aspect Ratio)
    Item {
      id: screenContainer
      Layout.fillWidth: true
      Layout.fillHeight: true

      NBox {
        id: screenBox
        width: Math.min(screenContainer.width, screenContainer.height * 16 / 9)
        height: Math.min(screenContainer.height, screenContainer.width * 9 / 16)
        anchors.centerIn: parent
        color: Color.mSurfaceContainerHighest
        radius: Style.radiusL
        border.color: Qt.alpha(Color.mOutline, 0.35)
        border.width: Style.borderS
        clip: true

      // Live Video Preview Loader
      Loader {
        anchors.fill: parent
        active: root.isVideoPath && root.wallpaperPath !== ""
        visible: active

        sourceComponent: Item {
          anchors.fill: parent

          MediaPlayer {
            id: previewVideoPlayer
            source: root.activeVideoSource
            loops: MediaPlayer.Infinite
            videoOutput: previewVideoOutput
            audioOutput: AudioOutput { muted: true }
            onSourceChanged: {
              if (source !== "") {
                play();
              } else {
                stop();
              }
            }
            onMediaStatusChanged: {
              if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) {
                play();
              }
            }
            Component.onCompleted: play()
            Component.onDestruction: stop()
          }

          VideoOutput {
            id: previewVideoOutput
            anchors.fill: parent
            fillMode: {
              switch (root.currentFillMode) {
                case "fit": return VideoOutput.PreserveAspectFit;
                case "stretch": return VideoOutput.Stretch;
                case "crop":
                default: return VideoOutput.PreserveAspectCrop;
              }
            }
          }
        }
      }

      // Wallpaper Background Image
      Image {
        id: bgImage
        anchors.fill: parent
        source: !root.isVideoPath && root.wallpaperPath !== "" ? (root.wallpaperPath.startsWith("/") ? "file://" + root.wallpaperPath : root.wallpaperPath) : ""
        fillMode: {
          switch (root.currentFillMode) {
            case "fit": return Image.PreserveAspectFit;
            case "stretch": return Image.Stretch;
            case "repeat": return Image.Tile;
            case "crop":
            default: return Image.PreserveAspectCrop;
          }
        }
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
        asynchronous: true

        // Fallback placeholder if empty or loading
        Rectangle {
          anchors.fill: parent
          visible: bgImage.status !== Image.Ready
          color: Color.mSurfaceContainer
          NText {
            anchors.centerIn: parent
            text: "Selecione um papel de parede para visualizar"
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // Mock Desktop Shell Overlay
      Item {
        id: shellOverlay
        anchors.fill: parent

        // Mirrors the user's actual bar config (position + which widgets are
        // enabled per section) instead of a fixed fake layout. "left"/"right"
        // (vertical bar) positions fall back to the top horizontal mock — a full
        // vertical-bar mockup would need its own geometry, out of scope here.
        readonly property string barPosition: Settings.getBarPositionForScreen(root.screenName)
        readonly property bool barAtBottom: barPosition === "bottom"
        readonly property var barWidgetSections: Settings.getBarWidgetsForScreen(root.screenName) || ({
                                                                                                          "left": [],
                                                                                                          "center": [],
                                                                                                          "right": []
                                                                                                        })

        function barIconFor(widgetId) {
          switch (widgetId) {
          case "Clock":
            return "clock";
          case "Battery":
            return "battery-charging";
          case "Volume":
          case "MediaMini":
            return "volume";
          case "Brightness":
            return "brightness";
          case "Tray":
            return "apps";
          case "NotificationHistory":
            return "bell";
          case "Network":
          case "VPN":
            return "wifi";
          case "Bluetooth":
            return "bluetooth";
          case "ControlCenter":
            return "settings";
          case "Launcher":
            return "grid-dots";
          default:
            return "app-window";
          }
        }

        // 1. Bar Simulation (top or bottom, per the real bar config)
        Rectangle {
          id: mockBar
          anchors.top: shellOverlay.barAtBottom ? undefined : parent.top
          anchors.bottom: shellOverlay.barAtBottom ? parent.bottom : undefined
          anchors.left: parent.left
          anchors.right: parent.right
          height: 32
          color: Qt.alpha(root.previewDarkMode ? "#14161f" : "#f5f5fa", 0.78)
          border.color: Qt.alpha(root.paletteColor("mPrimary"), 0.25)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginM
            anchors.rightMargin: Style.marginM

            // Left section
            Row {
              spacing: Style.marginS
              Layout.alignment: Qt.AlignVCenter
              Repeater {
                model: shellOverlay.barWidgetSections.left
                NIcon {
                  required property var modelData
                  icon: shellOverlay.barIconFor(modelData.id)
                  pointSize: Style.fontSizeS
                  color: root.paletteColor("mPrimary")
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Center section — special-cased workspace pills when present, icons otherwise
            Row {
              spacing: 6
              Layout.alignment: Qt.AlignVCenter
              Repeater {
                model: shellOverlay.barWidgetSections.center
                Loader {
                  required property var modelData
                  sourceComponent: modelData.id === "Workspace" ? workspacePillsComponent : centerIconComponent

                  Component {
                    id: workspacePillsComponent
                    Row {
                      spacing: 6
                      Repeater {
                        model: 4
                        Rectangle {
                          width: index === 0 ? 22 : 10
                          height: 10
                          radius: 5
                          color: index === 0 ? root.paletteColor("mPrimary") : Qt.alpha(root.paletteColor("mOnSurface"), 0.3)
                        }
                      }
                    }
                  }
                  Component {
                    id: centerIconComponent
                    NText {
                      text: "14:30"
                      pointSize: Style.fontSizeS
                      font.weight: Style.fontWeightBold
                      color: root.previewDarkMode ? "#ffffff" : "#1a1a2e"
                    }
                  }
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Right section
            Row {
              spacing: Style.marginS
              Layout.alignment: Qt.AlignVCenter
              Repeater {
                model: shellOverlay.barWidgetSections.right
                NIcon {
                  required property var modelData
                  icon: shellOverlay.barIconFor(modelData.id)
                  pointSize: Style.fontSizeS
                  color: root.paletteColor("mPrimary")
                }
              }
            }
          }
        }

        // 2. Mock Floating Window 1 (Code Editor / App)
        Rectangle {
          id: mockWindow1
          width: Math.min(parent.width * 0.48, 380)
          height: Math.min(parent.height * 0.55, 260)
          x: Style.marginXL
          y: mockBar.height + Style.marginL
          color: Qt.alpha(root.previewDarkMode ? "#181a24" : "#ffffff", 0.92)
          radius: Style.radiusS
          border.color: Qt.alpha(root.paletteColor("mPrimary"), 0.4)
          border.width: 1

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Titlebar
            Rectangle {
              Layout.fillWidth: true
              height: 28
              color: Qt.alpha(root.paletteColor("mPrimary"), 0.12)
              radius: Style.radiusS

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Row {
                  spacing: 5
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#ff5f56" }
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#ffbd2e" }
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#27c93f" }
                }

                NText {
                  text: "Hydra Shell - Editor"
                  pointSize: Style.fontSizeXS
                  color: root.paletteColor("mOnSurface")
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                }
              }
            }

            // Window Content Mockup
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Row {
                  spacing: 8
                  NText { text: "1"; pointSize: Style.fontSizeXS; color: Qt.alpha(root.paletteColor("mOnSurface"), 0.4) }
                  NText { text: "import Quickshell"; pointSize: Style.fontSizeXS; color: root.paletteColor("mPrimary"); font.weight: Style.fontWeightBold }
                }
                Row {
                  spacing: 8
                  NText { text: "2"; pointSize: Style.fontSizeXS; color: Qt.alpha(root.paletteColor("mOnSurface"), 0.4) }
                  NText { text: "import qs.Services.Theming"; pointSize: Style.fontSizeXS; color: root.paletteColor("mSecondary") }
                }
                Row {
                  spacing: 8
                  NText { text: "3"; pointSize: Style.fontSizeXS; color: Qt.alpha(root.paletteColor("mOnSurface"), 0.4) }
                  NText { text: "WallpaperPanel {"; pointSize: Style.fontSizeXS; color: root.paletteColor("mOnSurface") }
                }
                Row {
                  spacing: 8
                  NText { text: "4"; pointSize: Style.fontSizeXS; color: Qt.alpha(root.paletteColor("mOnSurface"), 0.4) }
                  NText { text: "  themeColors: extracted"; pointSize: Style.fontSizeXS; color: root.paletteColor("mPrimary") }
                }
                Row {
                  spacing: 8
                  NText { text: "5"; pointSize: Style.fontSizeXS; color: Qt.alpha(root.paletteColor("mOnSurface"), 0.4) }
                  NText { text: "}"; pointSize: Style.fontSizeXS; color: root.paletteColor("mOnSurface") }
                }
              }
            }
          }
        }

        // 3. Mock Floating Window 2 (Terminal / Pywal Preview)
        Rectangle {
          id: mockWindow2
          width: Math.min(parent.width * 0.42, 340)
          height: Math.min(parent.height * 0.48, 220)
          anchors.right: parent.right
          anchors.rightMargin: Style.marginXL
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.marginL
          color: Qt.alpha(root.previewDarkMode ? "#0f111a" : "#fafafa", 0.95)
          radius: Style.radiusS
          border.color: Qt.alpha(root.paletteColor("mSecondary"), 0.35)
          border.width: 1

          ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Titlebar
            Rectangle {
              Layout.fillWidth: true
              height: 28
              color: Qt.alpha(root.paletteColor("mSecondary"), 0.12)
              radius: Style.radiusS

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                Row {
                  spacing: 5
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#ff5f56" }
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#ffbd2e" }
                  Rectangle { width: 9; height: 9; radius: 4.5; color: "#27c93f" }
                }

                NText {
                  text: "terminal - neofetch"
                  pointSize: Style.fontSizeXS
                  color: root.paletteColor("mOnSurface")
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                }
              }
            }

            // Terminal Content
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                NText {
                  text: "raell@hydra-pc ~ $"
                  pointSize: Style.fontSizeXS
                  color: root.paletteColor("mPrimary")
                  font.weight: Style.fontWeightBold
                }

                NText {
                  text: "OS: Arch Linux x86_64\nWM: Hyprland (Wayland)\nShell: Hydra Shell v1.3.6"
                  pointSize: Style.fontSizeXS
                  color: root.paletteColor("mOnSurfaceVariant")
                }

                Row {
                  spacing: 4
                  Repeater {
                    model: [root.paletteColor("mPrimary"), root.paletteColor("mSecondary"), "#e74c3c", "#f1c40f", "#2ecc71", "#9b59b6", "#3498db"]
                    Rectangle {
                      required property var modelData
                      width: 18
                      height: 12
                      radius: 2
                      color: modelData
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
}
