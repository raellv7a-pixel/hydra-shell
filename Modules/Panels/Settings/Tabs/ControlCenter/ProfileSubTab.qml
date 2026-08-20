import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.fillWidth: true
  Layout.fillHeight: true

  function dtr(key) {
    return I18n.tr("panels.dashboard." + key);
  }

  NHeader {
    label: root.dtr("settingsProfilePhoto")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsAvatarShapeLabel")
    currentKey: Settings.data.controlCenter.avatarShape
    model: [
      {
        "key": "circle",
        "name": root.dtr("settingsAvatarShapeCircle")
      },
      {
        "key": "rounded",
        "name": root.dtr("settingsAvatarShapeRounded")
      },
      {
        "key": "square",
        "name": root.dtr("settingsAvatarShapeSquare")
      }
    ]
    onSelected: key => Settings.data.controlCenter.avatarShape = key
    defaultValue: Settings.getDefaultValue("controlCenter.avatarShape")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsProfileCardShape")
    description: root.dtr("settingsProfileCardShapeDesc")
    currentKey: Settings.data.controlCenter.profileCardShape
    model: [
      {
        "key": "rounded",
        "name": root.dtr("settingsProfileCardShapeRounded")
      },
      {
        "key": "soft",
        "name": root.dtr("settingsProfileCardShapeSoft")
      },
      {
        "key": "pill",
        "name": root.dtr("settingsProfileCardShapePill")
      },
      {
        "key": "sharp",
        "name": root.dtr("settingsProfileCardShapeSharp")
      }
    ]
    onSelected: key => Settings.data.controlCenter.profileCardShape = key
    defaultValue: Settings.getDefaultValue("controlCenter.profileCardShape")
  }

  NComboBox {
    Layout.fillWidth: true
    label: root.dtr("settingsAvatarMusicEffect")
    description: root.dtr("settingsAvatarMusicEffectDesc")
    currentKey: Settings.data.controlCenter.avatarMusicEffect
    model: [
      {
        "key": "none",
        "name": root.dtr("settingsAvatarEffectNone")
      },
      {
        "key": "ring",
        "name": root.dtr("settingsAvatarEffectRing")
      },
      {
        "key": "morph",
        "name": root.dtr("settingsAvatarEffectMorph")
      },
      {
        "key": "both",
        "name": root.dtr("settingsAvatarEffectBoth")
      },
      {
        "key": "glow",
        "name": root.dtr("settingsAvatarEffectGlow")
      },
      {
        "key": "orbit",
        "name": root.dtr("settingsAvatarEffectOrbit")
      },
      {
        "key": "studio",
        "name": root.dtr("settingsAvatarEffectStudio")
      }
    ]
    onSelected: key => Settings.data.controlCenter.avatarMusicEffect = key
    defaultValue: Settings.getDefaultValue("controlCenter.avatarMusicEffect")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowDanceGif")
    description: root.dtr("settingsShowDanceGifDesc")
    checked: Settings.data.controlCenter.showProfileDanceGif
    onToggled: checked => Settings.data.controlCenter.showProfileDanceGif = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showProfileDanceGif")
  }

  NTextInputButton {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.showProfileDanceGif
    label: root.dtr("settingsProfileDanceGifPath")
    description: root.dtr("settingsProfileDanceGifPathDesc")
    text: Settings.data.controlCenter.profileDanceGifPath
    placeholderText: "~/"
    buttonIcon: "gif"
    onInputTextChanged: text => Settings.data.controlCenter.profileDanceGifPath = text
    onButtonClicked: danceGifPicker.openFilePicker()
  }

  NFilePicker {
    id: danceGifPicker
    title: root.dtr("settingsProfileDanceGifPath")
    selectionMode: "files"
    nameFilters: ["*.gif", "*.png", "*.jpg", "*.jpeg", "*.webp"]
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.controlCenter.profileDanceGifPath = paths[0];
                  }
                }
  }

  NHeader {
    label: root.dtr("settingsProfileCover")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowProfileWallpaper")
    description: root.dtr("settingsShowProfileWallpaperDesc")
    checked: Settings.data.controlCenter.showProfileWallpaper
    onToggled: checked => Settings.data.controlCenter.showProfileWallpaper = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showProfileWallpaper")
  }

  NComboBox {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.showProfileWallpaper
    label: root.dtr("settingsCoverMode")
    description: root.dtr("settingsCoverModeDesc")
    currentKey: Settings.data.controlCenter.profileCoverMode
    model: [
      {
        "key": "auto",
        "name": root.dtr("settingsCoverModeAuto")
      },
      {
        "key": "custom",
        "name": root.dtr("settingsCoverModeCustom")
      },
      {
        "key": "random",
        "name": root.dtr("settingsCoverModeRandom")
      },
      {
        "key": "none",
        "name": root.dtr("settingsCoverModeNone")
      }
    ]
    onSelected: key => Settings.data.controlCenter.profileCoverMode = key
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverMode")
  }

  NTextInputButton {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.showProfileWallpaper && Settings.data.controlCenter.profileCoverMode === "custom"
    label: root.dtr("settingsCoverFile")
    description: root.dtr("settingsCoverFileDesc")
    text: Settings.data.controlCenter.profileCoverPath
    placeholderText: "~/"
    buttonIcon: "photo"
    onInputTextChanged: text => Settings.data.controlCenter.profileCoverPath = text
    onButtonClicked: coverImagePicker.openFilePicker()
  }

  NTextInputButton {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.showProfileWallpaper && Settings.data.controlCenter.profileCoverMode === "random"
    label: root.dtr("settingsCoverFolder")
    description: root.dtr("settingsCoverFolderDesc")
    text: Settings.data.controlCenter.profileCoverFolder
    placeholderText: "~/"
    buttonIcon: "folder"
    onInputTextChanged: text => Settings.data.controlCenter.profileCoverFolder = text
    onButtonClicked: coverFolderPicker.openFilePicker()
  }

  NFilePicker {
    id: coverImagePicker
    title: root.dtr("settingsCoverFile")
    selectionMode: "files"
    nameFilters: ImageCacheService.basicImageFilters
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.controlCenter.profileCoverPath = paths[0];
                  }
                }
  }

  NFilePicker {
    id: coverFolderPicker
    title: root.dtr("settingsCoverFolder")
    selectionMode: "folders"
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.controlCenter.profileCoverFolder = paths[0];
                  }
                }
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsCoverOverlayEnabled")
    description: root.dtr("settingsCoverOverlayEnabledDesc")
    checked: Settings.data.controlCenter.profileCoverOverlayEnabled
    onToggled: checked => Settings.data.controlCenter.profileCoverOverlayEnabled = checked
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverOverlayEnabled")
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverOverlayEnabled
    label: root.dtr("settingsCoverOverlay")
    from: 0.1
    to: 0.9
    stepSize: 0.05
    showReset: true
    value: Settings.data.controlCenter.profileCoverOverlay
    onMoved: val => Settings.data.controlCenter.profileCoverOverlay = Math.round(val * 100) / 100
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverOverlay")
    text: Math.round(Settings.data.controlCenter.profileCoverOverlay * 100) + "%"
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsBlurEnabled")
    description: root.dtr("settingsBlurEnabledDesc")
    checked: Settings.data.controlCenter.profileCoverBlurEnabled
    onToggled: checked => Settings.data.controlCenter.profileCoverBlurEnabled = checked
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBlurEnabled")
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBlurEnabled
    label: root.dtr("settingsBlur")
    from: 0
    to: 64
    stepSize: 1
    showReset: true
    value: Settings.data.controlCenter.profileCoverBlur
    onMoved: val => Settings.data.controlCenter.profileCoverBlur = Math.round(val)
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBlur")
    text: Settings.data.controlCenter.profileCoverBlur + "px"
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsCoverBorder")
    description: root.dtr("settingsCoverBorderDesc")
    checked: Settings.data.controlCenter.profileCoverBorder
    onToggled: checked => Settings.data.controlCenter.profileCoverBorder = checked
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBorder")
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder
    label: root.dtr("settingsBorderWidth")
    from: 1
    to: 6
    stepSize: 1
    showReset: true
    value: Settings.data.controlCenter.profileCoverBorderWidth
    onMoved: val => Settings.data.controlCenter.profileCoverBorderWidth = Math.round(val)
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBorderWidth")
    text: Settings.data.controlCenter.profileCoverBorderWidth + "px"
  }

  NComboBox {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder
    label: root.dtr("settingsBorderColorMode")
    description: root.dtr("settingsBorderColorModeDesc")
    currentKey: Settings.data.controlCenter.profileCoverBorderColorMode
    model: [
      {
        "key": "auto",
        "name": root.dtr("settingsBorderAutoColors")
      },
      {
        "key": "custom",
        "name": root.dtr("settingsBorderCustomColors")
      }
    ]
    onSelected: key => Settings.data.controlCenter.profileCoverBorderColorMode = key
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBorderColorMode")
  }

  NComboBox {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder && Settings.data.controlCenter.profileCoverBorderColorMode === "custom"
    label: root.dtr("settingsBorderColorCount")
    description: root.dtr("settingsBorderColorCountDesc")
    currentKey: String(Settings.data.controlCenter.profileCoverBorderColorCount)
    model: [
      {
        "key": "3",
        "name": "3"
      },
      {
        "key": "4",
        "name": "4"
      },
      {
        "key": "5",
        "name": "5"
      }
    ]
    onSelected: key => Settings.data.controlCenter.profileCoverBorderColorCount = parseInt(key, 10)
    defaultValue: String(Settings.getDefaultValue("controlCenter.profileCoverBorderColorCount"))
  }

  RowLayout {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder && Settings.data.controlCenter.profileCoverBorderColorMode === "custom"
    spacing: Style.marginM

    Repeater {
      model: Math.max(3, Math.min(5, Settings.data.controlCenter.profileCoverBorderColorCount))

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
          selectedColor: Settings.data.controlCenter[colorKey]
          onColorSelected: color => Settings.data.controlCenter[colorKey] = color.toString()
        }
      }
    }
  }

  NComboBox {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder
    label: root.dtr("settingsCoverBorderAnimation")
    currentKey: Settings.data.controlCenter.profileCoverBorderAnimation
    model: [
      {
        "key": "static",
        "name": root.dtr("settingsBorderAnimStatic")
      },
      {
        "key": "fade",
        "name": root.dtr("settingsBorderAnimFade")
      },
      {
        "key": "flow",
        "name": root.dtr("settingsBorderAnimFlow")
      },
      {
        "key": "flowEase",
        "name": root.dtr("settingsBorderAnimFlowEase")
      },
      {
        "key": "spark",
        "name": root.dtr("settingsBorderAnimSpark")
      },
      {
        "key": "pulse",
        "name": root.dtr("settingsBorderAnimPulse")
      },
      {
        "key": "chase",
        "name": root.dtr("settingsBorderAnimChase")
      },
      {
        "key": "comet",
        "name": root.dtr("settingsBorderAnimComet")
      },
      {
        "key": "neon",
        "name": root.dtr("settingsBorderAnimNeon")
      },
      {
        "key": "corners",
        "name": root.dtr("settingsBorderAnimCorners")
      },
      {
        "key": "orbitDots",
        "name": root.dtr("settingsBorderAnimOrbitDots")
      },
      {
        "key": "scan",
        "name": root.dtr("settingsBorderAnimScan")
      },
      {
        "key": "profileAurora",
        "name": root.dtr("settingsBorderAnimProfileAurora")
      },
      {
        "key": "profileHalo",
        "name": root.dtr("settingsBorderAnimProfileHalo")
      },
      {
        "key": "profileHeartbeat",
        "name": root.dtr("settingsBorderAnimProfileHeartbeat")
      },
      {
        "key": "profileSpotlight",
        "name": root.dtr("settingsBorderAnimProfileSpotlight")
      },
      {
        "key": "reactivePulse",
        "name": root.dtr("settingsBorderAnimReactivePulse")
      },
      {
        "key": "reactiveFlow",
        "name": root.dtr("settingsBorderAnimReactiveFlow")
      },
      {
        "key": "reactiveSpark",
        "name": root.dtr("settingsBorderAnimReactiveSpark")
      }
    ]
    onSelected: key => Settings.data.controlCenter.profileCoverBorderAnimation = key
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBorderAnimation")
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: Settings.data.controlCenter.profileCoverBorder
    label: root.dtr("settingsBorderSpeed")
    from: 0.25
    to: 3
    stepSize: 0.25
    showReset: true
    value: Settings.data.controlCenter.profileCoverBorderSpeed
    onMoved: val => Settings.data.controlCenter.profileCoverBorderSpeed = Math.round(val * 100) / 100
    defaultValue: Settings.getDefaultValue("controlCenter.profileCoverBorderSpeed")
    text: Math.round(Settings.data.controlCenter.profileCoverBorderSpeed * 100) + "%"
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
