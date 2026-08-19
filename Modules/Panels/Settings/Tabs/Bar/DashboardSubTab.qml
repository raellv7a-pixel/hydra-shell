import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginM
  Layout.fillWidth: true
  implicitHeight: subTabBar.implicitHeight + contentCol.implicitHeight + Style.marginM * 4

  property var cfg: ControlCenterService.settings
  property int subTab: 0

  function dtr(key) {
    return I18n.tr("panels.dashboard." + key);
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    currentIndex: root.subTab
    distributeEvenly: true

    NTabButton {
      text: root.dtr("settingsTabWindow")
      tabIndex: 0
      checked: root.subTab === 0
      onClicked: root.subTab = 0
    }
    NTabButton {
      text: root.dtr("settingsTabProfile")
      tabIndex: 1
      checked: root.subTab === 1
      onClicked: root.subTab = 1
    }
    NTabButton {
      text: root.dtr("settingsTabEffects")
      tabIndex: 2
      checked: root.subTab === 2
      onClicked: root.subTab = 2
    }
    NTabButton {
      text: root.dtr("settingsTabSections")
      tabIndex: 3
      checked: root.subTab === 3
      onClicked: root.subTab = 3
    }
  }

  ColumnLayout {
    id: contentCol
    Layout.fillWidth: true
    spacing: Style.marginL

    // ==========================================
    // SUBTAB 0: JANELA & LAYOUT
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 0
      spacing: Style.marginM

      NText {
        text: root.dtr("settingsWindowBehavior")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsPanelDetached")
        description: root.dtr("settingsPanelDetachedDesc")
        checked: root.cfg.panelDetached ?? true
        onToggled: checked => {
                     root.cfg.panelDetached = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        visible: !root.cfg.panelDetached
        label: root.dtr("settingsFollowBarEdge")
        description: root.dtr("settingsFollowBarEdgeDesc")
        checked: root.cfg.followBarEdge ?? true
        onToggled: checked => {
                     root.cfg.followBarEdge = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsPanelPosition")
        description: root.dtr("settingsPanelPositionDesc")
        currentKey: root.cfg.panelPosition ?? "center"
        model: [
          {
            key: "center",
            name: root.dtr("settingsPositionCenter")
          },
          {
            key: "top_left",
            name: root.dtr("settingsPositionTopLeft")
          },
          {
            key: "top_right",
            name: root.dtr("settingsPositionTopRight")
          },
          {
            key: "bottom_left",
            name: root.dtr("settingsPositionBottomLeft")
          },
          {
            key: "bottom_right",
            name: root.dtr("settingsPositionBottomRight")
          },
          {
            key: "left",
            name: root.dtr("settingsPositionLeft")
          },
          {
            key: "right",
            name: root.dtr("settingsPositionRight")
          }
        ]
        onSelected: key => {
                      root.cfg.panelPosition = key;
                      ControlCenterService.saveSettings();
                    }
      }

      Item {
        Layout.preferredHeight: Style.marginS
      }

      NText {
        text: root.dtr("settingsDimensions")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NValueSlider {
        Layout.fillWidth: true
        label: root.dtr("settingsPanelWidth")
        from: 800
        to: 1400
        stepSize: 20
        value: root.cfg.panelWidth ?? 1120
        onMoved: val => {
                   root.cfg.panelWidth = Math.round(val);
                   ControlCenterService.saveSettings();
                 }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: root.dtr("settingsPanelHeight")
        from: 500
        to: 950
        stepSize: 20
        value: root.cfg.panelHeight ?? 700
        onMoved: val => {
                   root.cfg.panelHeight = Math.round(val);
                   ControlCenterService.saveSettings();
                 }
      }

      NValueSlider {
        Layout.fillWidth: true
        label: root.dtr("settingsPanelScale")
        from: 0.7
        to: 1.3
        stepSize: 0.05
        value: root.cfg.panelScale ?? 1.0
        onMoved: val => {
                   root.cfg.panelScale = Math.round(val * 100) / 100;
                   ControlCenterService.saveSettings();
                 }
      }
    }

    // ==========================================
    // SUBTAB 1: PERFIL & BANNER
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 1
      spacing: Style.marginM

      NText {
        text: root.dtr("settingsProfilePhoto")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsAvatarShapeLabel")
        currentKey: root.cfg.avatarShape ?? "circle"
        model: [
          {
            key: "circle",
            name: root.dtr("settingsAvatarShapeCircle")
          },
          {
            key: "rounded",
            name: root.dtr("settingsAvatarShapeRounded")
          },
          {
            key: "square",
            name: root.dtr("settingsAvatarShapeSquare")
          }
        ]
        onSelected: key => {
                      root.cfg.avatarShape = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsProfileCardShape")
        description: root.dtr("settingsProfileCardShapeDesc")
        currentKey: root.cfg.profileCardShape ?? "rounded"
        model: [
          {
            key: "rounded",
            name: root.dtr("settingsProfileCardShapeRounded")
          },
          {
            key: "soft",
            name: root.dtr("settingsProfileCardShapeSoft")
          },
          {
            key: "pill",
            name: root.dtr("settingsProfileCardShapePill")
          },
          {
            key: "sharp",
            name: root.dtr("settingsProfileCardShapeSharp")
          }
        ]
        onSelected: key => {
                      root.cfg.profileCardShape = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsAvatarMusicEffect")
        description: root.dtr("settingsAvatarMusicEffectDesc")
        currentKey: root.cfg.avatarMusicEffect ?? "ring"
        model: [
          {
            key: "none",
            name: root.dtr("settingsAvatarEffectNone")
          },
          {
            key: "ring",
            name: root.dtr("settingsAvatarEffectRing")
          },
          {
            key: "morph",
            name: root.dtr("settingsAvatarEffectMorph")
          },
          {
            key: "both",
            name: root.dtr("settingsAvatarEffectBoth")
          },
          {
            key: "glow",
            name: root.dtr("settingsAvatarEffectGlow")
          },
          {
            key: "orbit",
            name: root.dtr("settingsAvatarEffectOrbit")
          },
          {
            key: "studio",
            name: root.dtr("settingsAvatarEffectStudio")
          }
        ]
        onSelected: key => {
                      root.cfg.avatarMusicEffect = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowDanceGif")
        description: root.dtr("settingsShowDanceGifDesc")
        checked: root.cfg.showProfileDanceGif ?? true
        onToggled: checked => {
                     root.cfg.showProfileDanceGif = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NTextInputButton {
        Layout.fillWidth: true
        visible: root.cfg.showProfileDanceGif ?? true
        label: root.dtr("settingsProfileDanceGifPath")
        description: root.dtr("settingsProfileDanceGifPathDesc")
        text: root.cfg.profileDanceGifPath ?? ""
        placeholderText: "~/"
        buttonIcon: "gif"
        onInputTextChanged: text => {
                               root.cfg.profileDanceGifPath = text;
                               ControlCenterService.saveSettings();
                             }
        onButtonClicked: danceGifPicker.openFilePicker()
      }

      NFilePicker {
        id: danceGifPicker
        title: root.dtr("settingsProfileDanceGifPath")
        selectionMode: "files"
        nameFilters: ["*.gif", "*.png", "*.jpg", "*.jpeg", "*.webp"]
        onAccepted: paths => {
                      if (paths.length > 0) {
                        root.cfg.profileDanceGifPath = paths[0];
                        ControlCenterService.saveSettings();
                      }
                    }
      }

      Item {
        Layout.preferredHeight: Style.marginS
      }

      NText {
        text: root.dtr("settingsProfileCover")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowProfileWallpaper")
        description: root.dtr("settingsShowProfileWallpaperDesc")
        checked: root.cfg.showProfileWallpaper ?? true
        onToggled: checked => {
                     root.cfg.showProfileWallpaper = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.cfg.showProfileWallpaper ?? true
        label: root.dtr("settingsCoverMode")
        description: root.dtr("settingsCoverModeDesc")
        currentKey: root.cfg.profileCoverMode ?? "auto"
        model: [
          {
            key: "auto",
            name: root.dtr("settingsCoverModeAuto")
          },
          {
            key: "custom",
            name: root.dtr("settingsCoverModeCustom")
          },
          {
            key: "random",
            name: root.dtr("settingsCoverModeRandom")
          },
          {
            key: "none",
            name: root.dtr("settingsCoverModeNone")
          }
        ]
        onSelected: key => {
                      root.cfg.profileCoverMode = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NTextInputButton {
        Layout.fillWidth: true
        visible: (root.cfg.showProfileWallpaper ?? true) && root.cfg.profileCoverMode === "custom"
        label: root.dtr("settingsCoverFile")
        description: root.dtr("settingsCoverFileDesc")
        text: root.cfg.profileCoverPath ?? ""
        placeholderText: "~/"
        buttonIcon: "photo"
        onInputTextChanged: text => {
                              root.cfg.profileCoverPath = text;
                              ControlCenterService.saveSettings();
                            }
        onButtonClicked: coverImagePicker.openFilePicker()
      }

      NTextInputButton {
        Layout.fillWidth: true
        visible: (root.cfg.showProfileWallpaper ?? true) && root.cfg.profileCoverMode === "random"
        label: root.dtr("settingsCoverFolder")
        description: root.dtr("settingsCoverFolderDesc")
        text: root.cfg.profileCoverFolder ?? ""
        placeholderText: "~/"
        buttonIcon: "folder"
        onInputTextChanged: text => {
                              root.cfg.profileCoverFolder = text;
                              ControlCenterService.saveSettings();
                            }
        onButtonClicked: coverFolderPicker.openFilePicker()
      }

      NFilePicker {
        id: coverImagePicker
        title: root.dtr("settingsCoverFile")
        selectionMode: "files"
        nameFilters: ImageCacheService.basicImageFilters
        onAccepted: paths => {
                      if (paths.length > 0) {
                        root.cfg.profileCoverPath = paths[0];
                        ControlCenterService.saveSettings();
                      }
                    }
      }

      NFilePicker {
        id: coverFolderPicker
        title: root.dtr("settingsCoverFolder")
        selectionMode: "folders"
        onAccepted: paths => {
                      if (paths.length > 0) {
                        root.cfg.profileCoverFolder = paths[0];
                        ControlCenterService.saveSettings();
                      }
                    }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsCoverOverlayEnabled")
        description: root.dtr("settingsCoverOverlayEnabledDesc")
        checked: root.cfg.profileCoverOverlayEnabled ?? true
        onToggled: checked => {
                     root.cfg.profileCoverOverlayEnabled = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverOverlayEnabled ?? true
        label: root.dtr("settingsCoverOverlay")
        from: 0.1
        to: 0.9
        stepSize: 0.05
        value: root.cfg.profileCoverOverlay ?? 0.58
        onMoved: val => {
                   root.cfg.profileCoverOverlay = Math.round(val * 100) / 100;
                   ControlCenterService.saveSettings();
                 }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsBlurEnabled")
        description: root.dtr("settingsBlurEnabledDesc")
        checked: root.cfg.profileCoverBlurEnabled ?? false
        onToggled: checked => {
                     root.cfg.profileCoverBlurEnabled = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBlurEnabled ?? false
        label: root.dtr("settingsBlur")
        from: 0
        to: 64
        stepSize: 1
        value: root.cfg.profileCoverBlur ?? 0
        onMoved: val => {
                   root.cfg.profileCoverBlur = Math.round(val);
                   ControlCenterService.saveSettings();
                 }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsCoverBorder")
        description: root.dtr("settingsCoverBorderDesc")
        checked: root.cfg.profileCoverBorder ?? true
        onToggled: checked => {
                     root.cfg.profileCoverBorder = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBorder ?? true
        label: root.dtr("settingsBorderWidth")
        from: 1
        to: 6
        stepSize: 1
        value: root.cfg.profileCoverBorderWidth ?? 2
        onMoved: val => {
                   root.cfg.profileCoverBorderWidth = Math.round(val);
                   ControlCenterService.saveSettings();
                 }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBorder ?? true
        label: root.dtr("settingsBorderColorMode")
        description: root.dtr("settingsBorderColorModeDesc")
        currentKey: root.cfg.profileCoverBorderColorMode ?? "auto"
        model: [
          {
            key: "auto",
            name: root.dtr("settingsBorderAutoColors")
          },
          {
            key: "custom",
            name: root.dtr("settingsBorderCustomColors")
          }
        ]
        onSelected: key => {
                      root.cfg.profileCoverBorderColorMode = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: (root.cfg.profileCoverBorder ?? true) && root.cfg.profileCoverBorderColorMode === "custom"
        label: root.dtr("settingsBorderColorCount")
        description: root.dtr("settingsBorderColorCountDesc")
        currentKey: String(root.cfg.profileCoverBorderColorCount ?? 3)
        model: [
          {
            key: "3",
            name: "3"
          },
          {
            key: "4",
            name: "4"
          },
          {
            key: "5",
            name: "5"
          }
        ]
        onSelected: key => {
                      root.cfg.profileCoverBorderColorCount = parseInt(key, 10);
                      ControlCenterService.saveSettings();
                    }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: (root.cfg.profileCoverBorder ?? true) && root.cfg.profileCoverBorderColorMode === "custom"
        spacing: Style.marginM

        Repeater {
          model: Math.max(3, Math.min(5, root.cfg.profileCoverBorderColorCount ?? 3))

          ColumnLayout {
            required property int index
            readonly property string colorKey: "profileCoverBorderColor" + (index + 1)
            spacing: Style.marginXS

            NText {
              text: root.dtr("settingsBorderColor" + (index + 1))
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NColorPicker {
              selectedColor: root.cfg[colorKey] ?? "#ffffff"
              onColorSelected: color => {
                                  root.cfg[colorKey] = color.toString();
                                  ControlCenterService.saveSettings();
                                }
            }
          }
        }
      }

      NComboBox {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBorder ?? true
        label: root.dtr("settingsCoverBorderAnimation")
        currentKey: root.cfg.profileCoverBorderAnimation ?? "static"
        model: [
          {
            key: "static",
            name: root.dtr("settingsBorderAnimStatic")
          },
          {
            key: "fade",
            name: root.dtr("settingsBorderAnimFade")
          },
          {
            key: "flow",
            name: root.dtr("settingsBorderAnimFlow")
          },
          {
            key: "flowEase",
            name: root.dtr("settingsBorderAnimFlowEase")
          },
          {
            key: "spark",
            name: root.dtr("settingsBorderAnimSpark")
          },
          {
            key: "pulse",
            name: root.dtr("settingsBorderAnimPulse")
          },
          {
            key: "chase",
            name: root.dtr("settingsBorderAnimChase")
          },
          {
            key: "comet",
            name: root.dtr("settingsBorderAnimComet")
          },
          {
            key: "neon",
            name: root.dtr("settingsBorderAnimNeon")
          },
          {
            key: "corners",
            name: root.dtr("settingsBorderAnimCorners")
          },
          {
            key: "orbitDots",
            name: root.dtr("settingsBorderAnimOrbitDots")
          },
          {
            key: "scan",
            name: root.dtr("settingsBorderAnimScan")
          },
          {
            key: "profileAurora",
            name: root.dtr("settingsBorderAnimProfileAurora")
          },
          {
            key: "profileHalo",
            name: root.dtr("settingsBorderAnimProfileHalo")
          },
          {
            key: "profileHeartbeat",
            name: root.dtr("settingsBorderAnimProfileHeartbeat")
          },
          {
            key: "profileSpotlight",
            name: root.dtr("settingsBorderAnimProfileSpotlight")
          },
          {
            key: "reactivePulse",
            name: root.dtr("settingsBorderAnimReactivePulse")
          },
          {
            key: "reactiveFlow",
            name: root.dtr("settingsBorderAnimReactiveFlow")
          },
          {
            key: "reactiveSpark",
            name: root.dtr("settingsBorderAnimReactiveSpark")
          }
        ]
        onSelected: key => {
                      root.cfg.profileCoverBorderAnimation = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NValueSlider {
        Layout.fillWidth: true
        visible: root.cfg.profileCoverBorder ?? true
        label: root.dtr("settingsBorderSpeed")
        from: 0.25
        to: 3
        stepSize: 0.25
        value: root.cfg.profileCoverBorderSpeed ?? 1
        onMoved: val => {
                   root.cfg.profileCoverBorderSpeed = Math.round(val * 100) / 100;
                   ControlCenterService.saveSettings();
                 }
      }
    }

    // ==========================================
    // SUBTAB 2: EFEITOS & ÁUDIO
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 2
      spacing: Style.marginM

      NText {
        text: root.dtr("settingsAudioVisualizers")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsMediaVisualizer")
        description: root.dtr("settingsMediaVisualizerDesc")
        currentKey: root.cfg.mediaVisualizerEffect ?? "bars"
        model: [
          {
            key: "none",
            name: root.dtr("visualizerNone")
          },
          {
            key: "bars",
            name: root.dtr("visualizerBars")
          },
          {
            key: "mirror",
            name: root.dtr("settingsVisualizerMirror")
          },
          {
            key: "wave",
            name: root.dtr("visualizerWave")
          },
          {
            key: "ribbon",
            name: root.dtr("settingsVisualizerRibbon")
          },
          {
            key: "shock",
            name: root.dtr("visualizerShock")
          },
          {
            key: "pulse",
            name: root.dtr("visualizerPulse")
          },
          {
            key: "nebula",
            name: root.dtr("visualizerNebula")
          },
          {
            key: "aurora",
            name: root.dtr("visualizerAurora")
          },
          {
            key: "constellation",
            name: root.dtr("visualizerConstellation")
          },
          {
            key: "radar",
            name: root.dtr("visualizerRadar")
          }
        ]
        onSelected: key => {
                      root.cfg.mediaVisualizerEffect = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsAudioSliderEffect")
        description: root.dtr("settingsAudioSliderEffectDesc")
        currentKey: root.cfg.audioSliderEffect ?? "wave"
        model: [
          {
            key: "none",
            name: root.dtr("sliderEffectNone")
          },
          {
            key: "wave",
            name: root.dtr("sliderEffectWave")
          },
          {
            key: "zigzag",
            name: root.dtr("sliderEffectZigzag")
          },
          {
            key: "pulse",
            name: root.dtr("sliderEffectPulse")
          },
          {
            key: "bars",
            name: root.dtr("sliderEffectBars")
          },
          {
            key: "spectrum",
            name: root.dtr("sliderEffectSpectrum")
          },
          {
            key: "filament",
            name: root.dtr("sliderEffectFilament")
          },
          {
            key: "ripple",
            name: root.dtr("sliderEffectRipple")
          },
          {
            key: "glow",
            name: root.dtr("sliderEffectGlow")
          },
          {
            key: "wavy_fill",
            name: root.dtr("sliderEffectWavyFill")
          },
          {
            key: "blocks",
            name: root.dtr("sliderEffectBlocks")
          },
          {
            key: "dots",
            name: root.dtr("sliderEffectDots")
          },
          {
            key: "comet",
            name: root.dtr("settingsSliderEffectComet")
          },
          {
            key: "aurora",
            name: root.dtr("settingsSliderEffectAurora")
          }
        ]
        onSelected: key => {
                      root.cfg.audioSliderEffect = key;
                      ControlCenterService.saveSettings();
                    }
      }

      NComboBox {
        Layout.fillWidth: true
        label: root.dtr("settingsMicSliderEffect")
        description: root.dtr("settingsMicSliderEffectDesc")
        currentKey: root.cfg.microphoneSliderEffect ?? "pulse"
        model: [
          {
            key: "none",
            name: root.dtr("sliderEffectNone")
          },
          {
            key: "wave",
            name: root.dtr("sliderEffectWave")
          },
          {
            key: "zigzag",
            name: root.dtr("sliderEffectZigzag")
          },
          {
            key: "pulse",
            name: root.dtr("sliderEffectPulse")
          },
          {
            key: "bars",
            name: root.dtr("sliderEffectBars")
          },
          {
            key: "glow",
            name: root.dtr("sliderEffectGlow")
          },
          {
            key: "wavy_fill",
            name: root.dtr("sliderEffectWavyFill")
          },
          {
            key: "blocks",
            name: root.dtr("sliderEffectBlocks")
          },
          {
            key: "dots",
            name: root.dtr("sliderEffectDots")
          },
          {
            key: "comet",
            name: root.dtr("settingsSliderEffectComet")
          },
          {
            key: "aurora",
            name: root.dtr("settingsSliderEffectAurora")
          }
        ]
        onSelected: key => {
                      root.cfg.microphoneSliderEffect = key;
                      ControlCenterService.saveSettings();
                    }
      }

      Item {
        Layout.preferredHeight: Style.marginS
      }

      NText {
        text: root.dtr("settingsPerformanceEnergy")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsFollowShellPerf")
        description: root.dtr("settingsFollowShellPerfDesc")
        checked: root.cfg.followNoctaliaPerformanceMode ?? true
        onToggled: checked => {
                     root.cfg.followNoctaliaPerformanceMode = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsPowerSaver")
        description: root.dtr("settingsPowerSaverDesc")
        checked: root.cfg.powerSaverPerformanceMode ?? true
        onToggled: checked => {
                     root.cfg.powerSaverPerformanceMode = checked;
                     ControlCenterService.saveSettings();
                   }
      }
    }

    // ==========================================
    // SUBTAB 3: SEÇÕES DA TELA
    // ==========================================
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.subTab === 3
      spacing: Style.marginM

      NText {
        text: root.dtr("settingsVisibleCards")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowNotifications")
        checked: root.cfg.showNotifications ?? true
        onToggled: checked => {
                     root.cfg.showNotifications = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowMedia")
        checked: root.cfg.showMedia ?? true
        onToggled: checked => {
                     root.cfg.showMedia = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowCalendar")
        checked: root.cfg.showCalendar ?? true
        onToggled: checked => {
                     root.cfg.showCalendar = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowRecordingCard")
        checked: root.cfg.showRecordingCard ?? true
        onToggled: checked => {
                     root.cfg.showRecordingCard = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      Item {
        Layout.preferredHeight: Style.marginS
      }

      NText {
        text: root.dtr("settingsBarMedia")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NToggle {
        Layout.fillWidth: true
        label: root.dtr("settingsShowBarMediaInfo")
        checked: root.cfg.showBarMediaInfo ?? true
        onToggled: checked => {
                     root.cfg.showBarMediaInfo = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.showBarMediaInfo ?? true
        label: root.dtr("settingsShowBarAlbumArt")
        checked: root.cfg.barMediaShowAlbumArt ?? true
        onToggled: checked => {
                     root.cfg.barMediaShowAlbumArt = checked;
                     ControlCenterService.saveSettings();
                   }
      }

      NToggle {
        Layout.fillWidth: true
        visible: root.cfg.showBarMediaInfo ?? true
        label: root.dtr("settingsShowBarProgressRing")
        checked: root.cfg.barMediaShowProgressRing ?? true
        onToggled: checked => {
                     root.cfg.barMediaShowProgressRing = checked;
                     ControlCenterService.saveSettings();
                   }
      }
    }
  }
}
