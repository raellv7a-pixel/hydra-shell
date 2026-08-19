import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Modal shown when a picked wallpaper is smaller than the target screen:
// a dimming full-fill Rectangle with a centered NBox card, the established
// "modal inside the wallpaper panel" pattern.
Rectangle {
  id: root

  anchors.fill: parent
  color: Qt.alpha(Color.mShadow, 0.78)
  z: 200
  visible: opacity > 0 || releaseTimer.running
  opacity: 0
  focus: visible

  readonly property var phaseOrder: ["probe", "prepare", "enhance", "assemble"]
  readonly property var phaseModel: [
    {
      "key": "probe",
      "icon": "search",
      "label": I18n.tr("wallpaper.upscale.phase-probe")
    },
    {
      "key": "prepare",
      "icon": "folder",
      "label": I18n.tr("wallpaper.upscale.phase-prepare")
    },
    {
      "key": "enhance",
      "icon": "sparkles",
      "label": I18n.tr("wallpaper.upscale.phase-enhance")
    },
    {
      "key": "assemble",
      "icon": "package",
      "label": I18n.tr("wallpaper.upscale.phase-assemble")
    }
  ]

  // "choice" | "obtaining" | "installing" | "processing" | "error"
  property string state: "choice"
  property var targetScreen: null
  property int candidateWidth: 0
  property int candidateHeight: 0
  property string currentUpscalePhase: ""
  property string errorText: ""

  property var _onDecision: null
  // function(callback) that hands a local file path to `callback(path, error)`
  // once one is available — synchronous for local picks (path already known),
  // asynchronous for Wallhaven picks (only resolved after the download, and
  // only if the user actually asks to upscale — no point downloading early
  // just to show a warning).
  property var _resolveSourcePath: null

  readonly property var _targetPixelSize: WallpaperUpscaleService.targetPixelSize(root.targetScreen)

  function show(screen, width, height, resolveSourcePath, onDecision) {
    if (root.visible && root.opacity > 0) {
      return;
    }
    releaseTimer.stop();
    root.targetScreen = screen;
    root.candidateWidth = width;
    root.candidateHeight = height;
    root._resolveSourcePath = resolveSourcePath;
    root._onDecision = onDecision;
    root.state = "choice";
    root.errorText = "";
    WallpaperUpscaleService.probeCapabilities();
    opacity = 1;
    forceActiveFocus();
  }

  function hide() {
    opacity = 0;
    releaseTimer.restart();
  }

  function _resolve(decision, upscaledPath) {
    const cb = root._onDecision;
    hide();
    if (cb) {
      cb(decision, upscaledPath);
    }
  }

  function _startUpscale() {
    root.state = "obtaining";
    root._resolveSourcePath(function (path, error) {
      if (!path) {
        root.state = "error";
        root.errorText = error || I18n.tr("wallpaper.upscale.generic-error");
        return;
      }
      root.state = "installing";
      WallpaperUpscaleService.ensureInstalled(function () {
        root.state = "processing";
        root.currentUpscalePhase = "probe";
        const scale = WallpaperUpscaleService.recommendedScale(root.candidateWidth, root.candidateHeight, root.targetScreen);
        WallpaperUpscaleService.upscale(path, scale, function (phase) {
          root.currentUpscalePhase = phase;
        }, function (outPath) {
          root._resolve("upscaled", outPath);
        }, function (err) {
          root.state = "error";
          root.errorText = err;
        });
      }, function (err) {
        root.state = "error";
        root.errorText = err;
      });
    });
  }

  Keys.onEscapePressed: event => {
                          root._resolve("cancel");
                          event.accepted = true;
                        }

  Timer {
    id: releaseTimer
    interval: Settings.data.general.animationDisabled ? 1 : Style.animationFast + 20
    onTriggered: {
      root.targetScreen = null;
      root._onDecision = null;
      root._resolveSourcePath = null;
    }
  }

  Behavior on opacity {
    NAnim {
      motionType: NAnim.StandardEffects
    }
  }

  // Background dim swallows clicks so they don't fall through to the grid
  // underneath; only Cancel/Escape dismiss, same restraint as the choice
  // buttons below (no accidental cancel from a stray tap while reading).
  MouseArea {
    anchors.fill: parent
  }

  NBox {
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.62, 520 * Style.uiScaleRatio)
    implicitHeight: contentCol.implicitHeight + Style.paddingCard * 2
    color: Color.mSurfaceContainerHigh
    radius: Style.radiusCard

    MouseArea {
      // Absorb clicks on the card itself so they don't reach the backdrop MouseArea.
      anchors.fill: parent
    }

    ColumnLayout {
      id: contentCol
      anchors.fill: parent
      anchors.margins: Style.paddingCard
      spacing: Style.spaceS

      // ---- choice state ----
      ColumnLayout {
        visible: root.state === "choice"
        Layout.fillWidth: true
        spacing: Style.spaceS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceS

          NIcon {
            icon: "alert-triangle"
            pointSize: Style.fontSizeTitleMedium
            color: Color.mSecondary
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spaceXXS

            NText {
              text: I18n.tr("wallpaper.upscale.warning-title")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeLabelMedium
              text: I18n.tr("wallpaper.upscale.warning-body", {
                              candidate: root.candidateWidth + "×" + root.candidateHeight,
                              target: root._targetPixelSize.width + "×" + root._targetPixelSize.height
                            })
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceXS

          Item {
            Layout.fillWidth: true
          }

          NButton {
            text: I18n.tr("common.cancel")
            backgroundColor: Color.mSurfaceContainerHighest
            textColor: Color.mOnSurface
            onClicked: root._resolve("cancel")
          }

          NButton {
            text: I18n.tr("wallpaper.upscale.improve-with-ai")
            icon: "sparkles"
            enabled: !WallpaperUpscaleService.vulkanChecked || WallpaperUpscaleService.vulkanAvailable
            tooltipText: (WallpaperUpscaleService.vulkanChecked && !WallpaperUpscaleService.vulkanAvailable) ? I18n.tr("wallpaper.upscale.no-vulkan-tooltip") : ""
            backgroundColor: Color.mSecondaryContainer
            textColor: Color.mOnSecondaryContainer
            onClicked: root._startUpscale()
          }

          NButton {
            text: I18n.tr("wallpaper.upscale.apply-as-is")
            icon: "check"
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            onClicked: root._resolve("as-is")
          }
        }
      }

      // ---- obtaining state (Wallhaven picks: downloading before we can upscale) ----
      ColumnLayout {
        visible: root.state === "obtaining"
        Layout.fillWidth: true
        spacing: Style.spaceS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceS

          NBusyIndicator {
            running: root.state === "obtaining"
            size: 22
          }

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurface
            text: I18n.tr("wallpaper.upscale.obtaining")
          }
        }
      }

      // ---- installing state ----
      ColumnLayout {
        visible: root.state === "installing"
        Layout.fillWidth: true
        spacing: Style.spaceS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spaceS

          NBusyIndicator {
            running: root.state === "installing"
            size: 22
          }

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurface
            text: I18n.tr("wallpaper.upscale.installing")
          }
        }
      }

      // ---- processing state ----
      ColumnLayout {
        visible: root.state === "processing"
        Layout.fillWidth: true
        spacing: Style.spaceS

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.paddingCard

          Repeater {
            model: root.phaseModel

            delegate: ColumnLayout {
              required property var modelData
              required property int index
              readonly property int currentPhaseIndex: root.phaseOrder.indexOf(root.currentUpscalePhase)

              spacing: Style.spaceXXS

              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 28
                height: 28
                radius: width / 2
                color: index <= currentPhaseIndex ? Color.mPrimary : Color.mSurfaceVariant

                Behavior on color {
                  NColorAnimation {
                    motionType: NColorAnimation.Standard
                  }
                }

                NIcon {
                  anchors.centerIn: parent
                  icon: modelData.icon
                  pointSize: Style.fontSizeS
                  color: index <= currentPhaseIndex ? Color.mOnPrimary : Color.mOnSurfaceVariant
                }
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.label
                pointSize: Style.fontSizeXS
                color: index === currentPhaseIndex ? Color.mPrimary : Color.mOnSurfaceVariant
                font.weight: index === currentPhaseIndex ? Style.fontWeightBold : Style.fontWeightRegular
              }
            }
          }
        }
      }

      // ---- error state ----
      ColumnLayout {
        visible: root.state === "error"
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: "alert-circle"
            pointSize: Style.fontSizeXL
            color: Color.mError
          }

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurface
            text: root.errorText || I18n.tr("wallpaper.upscale.generic-error")
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          Item {
            Layout.fillWidth: true
          }

          NButton {
            text: I18n.tr("common.cancel")
            backgroundColor: Color.mSurfaceContainerHighest
            textColor: Color.mOnSurface
            onClicked: root._resolve("cancel")
          }

          NButton {
            text: I18n.tr("wallpaper.upscale.apply-as-is")
            backgroundColor: Color.mPrimary
            textColor: Color.mOnPrimary
            onClicked: root._resolve("as-is")
          }
        }
      }
    }
  }
}
