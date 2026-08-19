import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property string wallpaperPath: ""
  property string screenName: ""
  property real brightnessValue: 0.0 // -1.0 to 1.0
  property real contrastValue: 0.0   // -1.0 to 1.0
  property real saturationValue: 0.0 // -1.0 to 1.0
  property real warmthValue: 0.0     // -1.0 to 1.0
  property bool vignetteActive: false
  property string activePreset: "Original"
  property string previewImagePath: ""
  property bool isBaking: false
  readonly property bool isVideoWallpaper: isVideoPath(wallpaperPath)

  Timer {
    id: bakeDebounceTimer
    interval: 300
    repeat: false
    onTriggered: root.bakePreview()
  }

  onWallpaperPathChanged: schedulePreviewBake()
  onBrightnessValueChanged: schedulePreviewBake()
  onContrastValueChanged: schedulePreviewBake()
  onSaturationValueChanged: schedulePreviewBake()
  onWarmthValueChanged: schedulePreviewBake()
  onVignetteActiveChanged: schedulePreviewBake()

  Component.onDestruction: {
    bakeDebounceTimer.stop();
    bakeProc.running = false;
    applyProc.running = false;
  }

  function isVideoPath(path) {
    const lowerPath = (path || "").toLowerCase();
    return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".mov");
  }

  function schedulePreviewBake() {
    if (isVideoWallpaper) {
      bakeDebounceTimer.stop();
      bakeProc.running = false;
      previewImagePath = "";
      isBaking = false;
      return;
    }
    bakeDebounceTimer.restart();
  }

  function resetGrading() {
    brightnessValue = 0.0;
    contrastValue = 0.0;
    saturationValue = 0.0;
    warmthValue = 0.0;
    vignetteActive = false;
    activePreset = "Original";
    previewImagePath = "";
  }

  function applyPreset(name) {
    activePreset = name;
    switch (name) {
    case "Cyberpunk":
      brightnessValue = 0.1;
      contrastValue = 0.35;
      saturationValue = 0.6;
      warmthValue = -0.4;
      vignetteActive = true;
      break;
    case "Vaporwave":
      brightnessValue = 0.15;
      contrastValue = 0.2;
      saturationValue = 0.5;
      warmthValue = -0.3;
      vignetteActive = false;
      break;
    case "Sunset":
      brightnessValue = 0.05;
      contrastValue = 0.25;
      saturationValue = 0.4;
      warmthValue = 0.6;
      vignetteActive = false;
      break;
    case "Cinematic":
      brightnessValue = -0.05;
      contrastValue = 0.3;
      saturationValue = -0.15;
      warmthValue = 0.1;
      vignetteActive = true;
      break;
    case "Emerald":
      brightnessValue = 0.0;
      contrastValue = 0.2;
      saturationValue = 0.3;
      warmthValue = -0.5;
      vignetteActive = false;
      break;
    case "Vintage":
      brightnessValue = 0.1;
      contrastValue = -0.1;
      saturationValue = -0.3;
      warmthValue = 0.4;
      vignetteActive = true;
      break;
    case "Monochrome":
      brightnessValue = 0.0;
      contrastValue = 0.2;
      saturationValue = -1.0;
      warmthValue = 0.0;
      vignetteActive = false;
      break;
    case "Warm Dusk":
      brightnessValue = 0.08;
      contrastValue = 0.15;
      saturationValue = 0.25;
      warmthValue = 0.5;
      vignetteActive = false;
      break;
    case "Cool Dusk":
      brightnessValue = -0.08;
      contrastValue = 0.2;
      saturationValue = 0.2;
      warmthValue = -0.5;
      vignetteActive = true;
      break;
    case "Deep Blue":
      brightnessValue = -0.1;
      contrastValue = 0.25;
      saturationValue = 0.35;
      warmthValue = -0.7;
      vignetteActive = true;
      break;
    case "Original":
    default:
      resetGrading();
      break;
    }
  }

  function bakePreview() {
    if (wallpaperPath === "" || isVideoWallpaper)
      return;
    isBaking = true;

    var br = Math.round(100 + brightnessValue * 100);
    var sat = Math.round(100 + saturationValue * 100);
    var ct = Math.round(contrastValue * 50);

    var rmul = (1 + warmthValue * 0.2).toFixed(4);
    var bmul = (1 - warmthValue * 0.2).toFixed(4);

    var outPath = "/tmp/hydra-graded-preview.png";

    var cmd = "src='" + wallpaperPath.replace(/'/g, "'\\''") + "'; out='" + outPath + "'; " + "args=(-resize '600x600>'); " + "if [ '" + warmthValue + "' != '0' ]; then args+=(-channel R -evaluate multiply " + rmul + " +channel -channel B -evaluate multiply " + bmul + " +channel); fi; " + "args+=(-modulate '" + br + "," + sat + ",100'); " + "if [ '" + ct
        + "' != '0' ]; then args+=(-brightness-contrast '0x" + ct + "'); fi; " + "if [ '" + (vignetteActive ? 1 : 0) + "' = '1' ]; then args+=(-background black -vignette 0x18); fi; " + "exec magick \"$src\" \"${args[@]}\" \"$out\" 2>/dev/null";

    bakeProc.command = ["bash", "-c", cmd];
    bakeProc.running = true;
  }

  function applyFullGraded() {
    if (wallpaperPath === "" || isVideoWallpaper)
      return;
    isBaking = true;

    var br = Math.round(100 + brightnessValue * 100);
    var sat = Math.round(100 + saturationValue * 100);
    var ct = Math.round(contrastValue * 50);
    var rmul = (1 + warmthValue * 0.2).toFixed(4);
    var bmul = (1 - warmthValue * 0.2).toFixed(4);

    var destDir = Quickshell.env("HOME") + "/Pictures/Wallpapers";
    var outPath = destDir + "/hydra-graded-" + Date.now() + ".png";

    var cmd = "mkdir -p '" + destDir + "'; src='" + wallpaperPath.replace(/'/g, "'\\''") + "'; out='" + outPath + "'; " + "args=(); " + "if [ '" + warmthValue + "' != '0' ]; then args+=(-channel R -evaluate multiply " + rmul + " +channel -channel B -evaluate multiply " + bmul + " +channel); fi; " + "args+=(-modulate '" + br + "," + sat + ",100'); "
        + "if [ '" + ct + "' != '0' ]; then args+=(-brightness-contrast '0x" + ct + "'); fi; " + "if [ '" + (vignetteActive ? 1 : 0) + "' = '1' ]; then args+=(-background black -vignette 0x18); fi; " + "exec magick \"$src\" \"${args[@]}\" \"$out\" 2>/dev/null";

    applyProc.targetOutPath = outPath;
    applyProc.command = ["bash", "-c", cmd];
    applyProc.running = true;
  }

  Process {
    id: bakeProc
    onExited: exitCode => {
                root.isBaking = false;
                if (exitCode === 0) {
                  root.previewImagePath = "file:///tmp/hydra-graded-preview.png?t=" + Date.now();
                }
              }
  }

  Process {
    id: applyProc
    property string targetOutPath: ""
    onExited: exitCode => {
                root.isBaking = false;
                if (exitCode === 0 && targetOutPath.length > 0) {
                  WallpaperService.changeWallpaper(targetOutPath, root.screenName, WallpaperService.wallpaperSelectionAppearance);
                  AppThemeService.generate();
                  ToastService.showNotice("Papel de Parede", "Ajustes de imagem aplicados com sucesso!", "adjustments", 3000);
                } else {
                  ToastService.showError("Erro", "Falha ao processar ajustes da imagem.");
                }
              }
  }

  RowLayout {
    anchors.fill: parent
    spacing: Style.marginL

    // Left Column: Live Image Preview with Shader / Filter overlay
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 3
      color: Color.mSurfaceContainerLow
      radius: Style.radiusL
      clip: true

      Image {
        id: previewImg
        anchors.fill: parent
        anchors.margins: Style.marginS
        source: root.isVideoWallpaper ? "" : (root.previewImagePath !== "" ? root.previewImagePath : (root.wallpaperPath !== "" ? (root.wallpaperPath.startsWith("/") ? "file://" + root.wallpaperPath : root.wallpaperPath) : ""))
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
        asynchronous: true

        NBusyIndicator {
          anchors.centerIn: parent
          visible: root.isBaking
          running: visible
          size: 32
        }

        // Preset Name Badge
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.margins: Style.marginM
          height: 28
          width: presetText.implicitWidth + 24
          color: Qt.alpha("#000000", 0.75)
          radius: 14

          NText {
            id: presetText
            anchors.centerIn: parent
            text: "Preset: " + root.activePreset
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            color: "#ffffff"
          }
        }
      }
    }

    // Right Column: Controls & Presets Grid
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 2
      color: Color.mSurfaceContainerHigh
      radius: Style.radiusL

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NIcon {
            icon: "adjustments"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: "Ajustes de Imagem (ImageMagick)"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NButton {
            text: "Restaurar"
            icon: "rotate-2"
            fontSize: Style.fontSizeS
            onClicked: root.resetGrading()
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        NText {
          text: "Presets de Estilo (Filtros de Cor)"
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightBold
          color: Color.mOnSurfaceVariant
        }

        // Presets Grid
        GridLayout {
          Layout.fillWidth: true
          columns: 3
          rowSpacing: Style.marginS
          columnSpacing: Style.marginS

          Repeater {
            model: ["Original", "Cyberpunk", "Vaporwave", "Sunset", "Emerald", "Cinematic", "Vintage", "Monochrome", "Warm Dusk", "Cool Dusk", "Deep Blue"]

            NButton {
              required property string modelData
              text: modelData
              Layout.fillWidth: true
              fontSize: Style.fontSizeS
              backgroundColor: root.activePreset === modelData ? Color.mSecondaryContainer : Color.mSurfaceContainerHighest
              textColor: root.activePreset === modelData ? Color.mOnSecondaryContainer : Color.mOnSurface
              onClicked: root.applyPreset(modelData)
            }
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        NText {
          text: "Ajustes Finos"
          pointSize: Style.fontSizeS
          font.weight: Style.fontWeightBold
          color: Color.mOnSurfaceVariant
        }

        // Sliders
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          // Brightness Slider
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: "Brilho"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.preferredWidth: 80
            }
            Slider {
              Layout.fillWidth: true
              from: -1.0
              to: 1.0
              value: root.brightnessValue
              onValueChanged: root.brightnessValue = value
            }
            NText {
              text: Math.round(root.brightnessValue * 100) + "%"
              pointSize: Style.fontSizeS
              color: Color.mPrimary
              Layout.preferredWidth: 40
            }
          }

          // Contrast Slider
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: "Contraste"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.preferredWidth: 80
            }
            Slider {
              Layout.fillWidth: true
              from: -1.0
              to: 1.0
              value: root.contrastValue
              onValueChanged: root.contrastValue = value
            }
            NText {
              text: Math.round(root.contrastValue * 100) + "%"
              pointSize: Style.fontSizeS
              color: Color.mPrimary
              Layout.preferredWidth: 40
            }
          }

          // Saturation Slider
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: "Saturação"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.preferredWidth: 80
            }
            Slider {
              Layout.fillWidth: true
              from: -1.0
              to: 1.0
              value: root.saturationValue
              onValueChanged: root.saturationValue = value
            }
            NText {
              text: Math.round(root.saturationValue * 100) + "%"
              pointSize: Style.fontSizeS
              color: Color.mPrimary
              Layout.preferredWidth: 40
            }
          }

          // Warmth Slider
          RowLayout {
            Layout.fillWidth: true
            NText {
              text: "Temperatura"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.preferredWidth: 80
            }
            Slider {
              Layout.fillWidth: true
              from: -1.0
              to: 1.0
              value: root.warmthValue
              onValueChanged: root.warmthValue = value
            }
            NText {
              text: Math.round(root.warmthValue * 100) + "%"
              pointSize: Style.fontSizeS
              color: Color.mPrimary
              Layout.preferredWidth: 40
            }
          }
        }

        Item {
          Layout.fillHeight: true
        }

        NButton {
          Layout.fillWidth: true
          text: "Aplicar Papel de Parede Editado"
          icon: "check"
          enabled: !root.isVideoWallpaper && !root.isBaking
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          onClicked: root.applyFullGraded()
        }
      }
    }
  }
}
