import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editAvatarPath: cfg.avatarPath ?? defaults.avatarPath ?? ""
  property bool editPanelDetached: cfg.panelDetached ?? defaults.panelDetached ?? true
  property string editPanelPosition: cfg.panelPosition ?? defaults.panelPosition ?? "center"
  property bool editFollowBarEdge: cfg.followBarEdge ?? defaults.followBarEdge ?? true
  property int editPanelWidth: cfg.panelWidth ?? defaults.panelWidth ?? 1120
  property int editPanelHeight: cfg.panelHeight ?? defaults.panelHeight ?? 700
  property real editPanelScale: cfg.panelScale ?? defaults.panelScale ?? 1
  property string editMediaVisualizerEffect: cfg.mediaVisualizerEffect ?? defaults.mediaVisualizerEffect ?? "bars"
  property string editAudioSliderEffect: cfg.audioSliderEffect ?? defaults.audioSliderEffect ?? "wave"
  property string editMicrophoneSliderEffect: cfg.microphoneSliderEffect ?? defaults.microphoneSliderEffect ?? "pulse"
  property string editAvatarMusicEffect: cfg.avatarMusicEffect ?? defaults.avatarMusicEffect ?? "ring"
  property string editAvatarShape: cfg.avatarShape ?? defaults.avatarShape ?? "circle"
  property string editProfileCardShape: cfg.profileCardShape ?? defaults.profileCardShape ?? "rounded"
  property bool editFollowNoctaliaPerformanceMode: cfg.followNoctaliaPerformanceMode ?? defaults.followNoctaliaPerformanceMode ?? true
  property bool editPowerSaverPerformanceMode: cfg.powerSaverPerformanceMode ?? defaults.powerSaverPerformanceMode ?? true
  property string editProfileDanceGifPath: cfg.profileDanceGifPath ?? defaults.profileDanceGifPath ?? ""
  property bool editShowProfileDanceGif: cfg.showProfileDanceGif ?? defaults.showProfileDanceGif ?? true
  property bool editShowProfileWallpaper: cfg.showProfileWallpaper ?? defaults.showProfileWallpaper ?? true
  property string editProfileCoverMode: cfg.profileCoverMode ?? defaults.profileCoverMode ?? (editShowProfileWallpaper ? "auto" : "none")
  property string editProfileCoverPath: cfg.profileCoverPath ?? defaults.profileCoverPath ?? ""
  property string editProfileCoverFolder: cfg.profileCoverFolder ?? defaults.profileCoverFolder ?? ""
  property bool editProfileCoverOverlayEnabled: cfg.profileCoverOverlayEnabled ?? defaults.profileCoverOverlayEnabled ?? true
  property real editProfileCoverOverlay: cfg.profileCoverOverlay ?? defaults.profileCoverOverlay ?? 0.58
  property bool editProfileCoverBlurEnabled: cfg.profileCoverBlurEnabled ?? defaults.profileCoverBlurEnabled ?? false
  property real editProfileCoverBlur: cfg.profileCoverBlur ?? defaults.profileCoverBlur ?? 0
  property bool editProfileCoverBorder: cfg.profileCoverBorder ?? defaults.profileCoverBorder ?? true
  property real editProfileCoverBorderWidth: cfg.profileCoverBorderWidth ?? defaults.profileCoverBorderWidth ?? 2
  property string editProfileCoverBorderEffect: cfg.profileCoverBorderEffect ?? defaults.profileCoverBorderEffect ?? "primary"
  property string editProfileCoverBorderColorMode: cfg.profileCoverBorderColorMode ?? defaults.profileCoverBorderColorMode ?? "auto"
  property string editProfileCoverBorderAnimation: cfg.profileCoverBorderAnimation ?? defaults.profileCoverBorderAnimation ?? "static"
  property real editProfileCoverBorderSpeed: cfg.profileCoverBorderSpeed ?? defaults.profileCoverBorderSpeed ?? 1
  property int editProfileCoverBorderColorCount: cfg.profileCoverBorderColorCount ?? defaults.profileCoverBorderColorCount ?? 3
  property color editProfileCoverBorderColor1: cfg.profileCoverBorderColor1 ?? defaults.profileCoverBorderColor1 ?? "#fff59b"
  property color editProfileCoverBorderColor2: cfg.profileCoverBorderColor2 ?? defaults.profileCoverBorderColor2 ?? "#8bd5ff"
  property color editProfileCoverBorderColor3: cfg.profileCoverBorderColor3 ?? defaults.profileCoverBorderColor3 ?? "#cba6f7"
  property color editProfileCoverBorderColor4: cfg.profileCoverBorderColor4 ?? defaults.profileCoverBorderColor4 ?? "#f38ba8"
  property color editProfileCoverBorderColor5: cfg.profileCoverBorderColor5 ?? defaults.profileCoverBorderColor5 ?? "#a6e3a1"
  property var editComponentStyles: Object.assign({}, cfg.componentStyles ?? defaults.componentStyles ?? ({}))
  property string editComponentStyleTarget: "__global"
  property bool editShowBarMediaInfo: cfg.showBarMediaInfo ?? defaults.showBarMediaInfo ?? true
  property bool editBarMediaShowWhenPaused: cfg.barMediaShowWhenPaused ?? defaults.barMediaShowWhenPaused ?? false
  property bool editBarMediaShowAlbumArt: cfg.barMediaShowAlbumArt ?? defaults.barMediaShowAlbumArt ?? true
  property bool editBarMediaShowVisualizer: cfg.barMediaShowVisualizer ?? defaults.barMediaShowVisualizer ?? true
  property string editBarMediaVisualizerType: cfg.barMediaVisualizerType ?? defaults.barMediaVisualizerType ?? "linear"
  property bool editBarMediaShowProgressRing: cfg.barMediaShowProgressRing ?? defaults.barMediaShowProgressRing ?? true
  property bool editBarMediaShowArtistFirst: cfg.barMediaShowArtistFirst ?? defaults.barMediaShowArtistFirst ?? true
  property string editBarMediaScrollingMode: cfg.barMediaScrollingMode ?? defaults.barMediaScrollingMode ?? "hover"
  property string editBarMediaLayout: cfg.barMediaLayout ?? defaults.barMediaLayout ?? "auto"
  property int editBarMediaMaxWidth: cfg.barMediaMaxWidth ?? defaults.barMediaMaxWidth ?? 170
  property bool editBarMediaUseFixedWidth: cfg.barMediaUseFixedWidth ?? defaults.barMediaUseFixedWidth ?? false
  property string editBarMediaTextColor: cfg.barMediaTextColor ?? defaults.barMediaTextColor ?? "none"
  property bool editShowNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
  property bool editShowMedia: cfg.showMedia ?? defaults.showMedia ?? true
  property bool editShowCalendar: cfg.showCalendar ?? defaults.showCalendar ?? true
  property bool editShowRecordingCard: cfg.showRecordingCard ?? defaults.showRecordingCard ?? true
  property string editIconName: cfg.iconName ?? defaults.iconName ?? "layout-dashboard"
  property string pendingImageTarget: ""
  property int settingsTab: 0

  spacing: Style.marginM

  NTabBar {
    Layout.fillWidth: true
    currentIndex: root.settingsTab
    distributeEvenly: true

    NTabButton {
      text: pluginApi?.tr("settings.tabPanel")
      icon: "layout-dashboard"
      tabIndex: 0
      checked: root.settingsTab === 0
      onClicked: root.settingsTab = 0
    }

    NTabButton {
      text: pluginApi?.tr("settings.tabProfile")
      icon: "user"
      tabIndex: 1
      checked: root.settingsTab === 1
      onClicked: root.settingsTab = 1
    }

    NTabButton {
      text: pluginApi?.tr("settings.tabEffects")
      icon: "sparkles"
      tabIndex: 2
      checked: root.settingsTab === 2
      onClicked: root.settingsTab = 2
    }

    NTabButton {
      text: pluginApi?.tr("settings.tabBar")
      icon: "layout-navbar"
      tabIndex: 3
      checked: root.settingsTab === 3
      onClicked: root.settingsTab = 3
    }

    NTabButton {
      text: pluginApi?.tr("settings.tabSections")
      icon: "layout-grid"
      tabIndex: 4
      checked: root.settingsTab === 4
      onClicked: root.settingsTab = 4
    }

    NTabButton {
      text: pluginApi?.tr("settings.tabColors")
      icon: "palette"
      tabIndex: 5
      checked: root.settingsTab === 5
      onClicked: root.settingsTab = 5
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 0
    spacing: Style.marginM

  NText {
    text: pluginApi?.tr("settings.panelBehavior")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.panelDetached")
    description: pluginApi?.tr("settings.panelDetachedDesc")
    checked: root.editPanelDetached
    onToggled: checked => root.editPanelDetached = checked
    defaultValue: defaults.panelDetached ?? true
  }

  NToggle {
    Layout.fillWidth: true
    visible: !root.editPanelDetached
    label: pluginApi?.tr("settings.followBarEdge")
    description: pluginApi?.tr("settings.followBarEdgeDesc")
    checked: root.editFollowBarEdge
    onToggled: checked => root.editFollowBarEdge = checked
    defaultValue: defaults.followBarEdge ?? true
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editPanelDetached || !root.editFollowBarEdge
    label: pluginApi?.tr("settings.panelPosition")
    description: pluginApi?.tr("settings.panelPositionDesc")
    model: [
      {
        "key": "left",
        "name": pluginApi?.tr("settings.panelPositionLeft")
      },
      {
        "key": "center",
        "name": pluginApi?.tr("settings.panelPositionCenter")
      },
      {
        "key": "right",
        "name": pluginApi?.tr("settings.panelPositionRight")
      },
      {
        "key": "top",
        "name": pluginApi?.tr("settings.panelPositionTop")
      },
      {
        "key": "bottom",
        "name": pluginApi?.tr("settings.panelPositionBottom")
      }
    ]
    currentKey: root.editPanelPosition
    onSelected: key => root.editPanelPosition = key
    defaultValue: defaults.panelPosition ?? "center"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.panelWidth") + ": " + root.editPanelWidth + "px"
      description: pluginApi?.tr("settings.panelWidthDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 760
      to: 1320
      stepSize: 10
      value: root.editPanelWidth
      onMoved: root.editPanelWidth = Math.round(value)
    }

    NLabel {
      label: pluginApi?.tr("settings.panelHeight") + ": " + root.editPanelHeight + "px"
      description: pluginApi?.tr("settings.panelHeightDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 560
      to: 860
      stepSize: 10
      value: root.editPanelHeight
      onMoved: root.editPanelHeight = Math.round(value)
    }
  }

  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 1
    spacing: Style.marginM

  NText {
    text: pluginApi?.tr("settings.appearance")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NTextInputButton {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.avatarPath")
    description: pluginApi?.tr("settings.avatarPathDesc")
    placeholderText: "~/Pictures/profile.gif"
    text: root.editAvatarPath
    buttonIcon: "photo"
    buttonTooltip: pluginApi?.tr("settings.chooseImageFile")
    onInputTextChanged: text => root.editAvatarPath = text
    onButtonClicked: root.openImagePicker("avatar")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showProfileWallpaper")
    description: pluginApi?.tr("settings.showProfileWallpaperDesc")
    checked: root.editShowProfileWallpaper
    onToggled: checked => {
                 root.editShowProfileWallpaper = checked;
                 if (!checked)
                   root.editProfileCoverMode = "none";
                 else if (root.editProfileCoverMode === "none")
                   root.editProfileCoverMode = "auto";
               }
    defaultValue: defaults.showProfileWallpaper ?? true
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.profileCoverMode")
    description: pluginApi?.tr("settings.profileCoverModeDesc")
    model: [
      { "key": "auto", "name": pluginApi?.tr("settings.profileCoverModeAuto") },
      { "key": "custom", "name": pluginApi?.tr("settings.profileCoverModeCustom") },
      { "key": "random", "name": pluginApi?.tr("settings.profileCoverModeRandom") },
      { "key": "none", "name": pluginApi?.tr("settings.profileCoverModeNone") }
    ]
    currentKey: root.editProfileCoverMode
    onSelected: key => {
                  root.editProfileCoverMode = key;
                  root.editShowProfileWallpaper = key !== "none";
                }
    defaultValue: defaults.profileCoverMode ?? "auto"
  }

  NTextInputButton {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode === "custom"
    label: pluginApi?.tr("settings.profileCoverPath")
    description: pluginApi?.tr("settings.profileCoverPathDesc")
    placeholderText: "~/Pictures/cover.gif"
    text: root.editProfileCoverPath
    buttonIcon: "photo"
    buttonTooltip: pluginApi?.tr("settings.chooseImageFile")
    onInputTextChanged: text => root.editProfileCoverPath = text
    onButtonClicked: root.openImagePicker("cover")
  }

  NTextInputButton {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode === "random"
    label: pluginApi?.tr("settings.profileCoverFolder")
    description: pluginApi?.tr("settings.profileCoverFolderDesc")
    placeholderText: "~/Pictures/Wallpapers"
    text: root.editProfileCoverFolder
    buttonIcon: "folder"
    buttonTooltip: pluginApi?.tr("settings.chooseFolder")
    onInputTextChanged: text => root.editProfileCoverFolder = text
    onButtonClicked: root.openImagePicker("coverFolder")
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none"
    label: pluginApi?.tr("settings.profileCoverOverlayEnabled")
    description: pluginApi?.tr("settings.profileCoverOverlayEnabledDesc")
    checked: root.editProfileCoverOverlayEnabled
    onToggled: checked => root.editProfileCoverOverlayEnabled = checked
    defaultValue: defaults.profileCoverOverlayEnabled ?? true
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverOverlayEnabled
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.profileCoverOverlay") + ": " + Math.round(root.editProfileCoverOverlay * 100) + "%"
      description: pluginApi?.tr("settings.profileCoverOverlayDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 0.82
      stepSize: 0.01
      value: root.editProfileCoverOverlay
      onMoved: root.editProfileCoverOverlay = value
    }
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none"
    label: pluginApi?.tr("settings.profileCoverBlurEnabled")
    description: pluginApi?.tr("settings.profileCoverBlurEnabledDesc")
    checked: root.editProfileCoverBlurEnabled
    onToggled: checked => root.editProfileCoverBlurEnabled = checked
    defaultValue: defaults.profileCoverBlurEnabled ?? false
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBlurEnabled
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.profileCoverBlur") + ": " + Math.round(root.editProfileCoverBlur * 100) + "%"
      description: pluginApi?.tr("settings.profileCoverBlurDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 1
      stepSize: 0.01
      value: root.editProfileCoverBlur
      onMoved: root.editProfileCoverBlur = value
    }
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none"
    label: pluginApi?.tr("settings.profileCoverBorder")
    description: pluginApi?.tr("settings.profileCoverBorderDesc")
    checked: root.editProfileCoverBorder
    onToggled: checked => root.editProfileCoverBorder = checked
    defaultValue: defaults.profileCoverBorder ?? true
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBorder
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.profileCoverBorderWidth") + ": " + root.editProfileCoverBorderWidth.toFixed(1) + "px"
      description: pluginApi?.tr("settings.profileCoverBorderWidthDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 1
      to: 8
      stepSize: 0.5
      value: root.editProfileCoverBorderWidth
      onMoved: root.editProfileCoverBorderWidth = value
    }
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBorder
    label: pluginApi?.tr("settings.profileCoverBorderColorMode")
    description: pluginApi?.tr("settings.profileCoverBorderColorModeDesc")
    model: [
      { "key": "auto", "name": pluginApi?.tr("settings.profileCoverBorderAutoColors") },
      { "key": "custom", "name": pluginApi?.tr("settings.profileCoverBorderCustomColors") }
    ]
    currentKey: root.editProfileCoverBorderColorMode
    onSelected: key => root.editProfileCoverBorderColorMode = key
    defaultValue: defaults.profileCoverBorderColorMode ?? "auto"
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBorder && root.editProfileCoverBorderColorMode === "custom"
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.profileCoverBorderColorCount") + ": " + root.editProfileCoverBorderColorCount
      description: pluginApi?.tr("settings.profileCoverBorderColorCountDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 3
      to: 5
      stepSize: 1
      value: root.editProfileCoverBorderColorCount
      onMoved: root.editProfileCoverBorderColorCount = Math.round(value)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NColorPicker {
        Layout.fillWidth: true
        selectedColor: root.editProfileCoverBorderColor1
        onColorSelected: color => root.editProfileCoverBorderColor1 = color
      }
      NColorPicker {
        Layout.fillWidth: true
        selectedColor: root.editProfileCoverBorderColor2
        onColorSelected: color => root.editProfileCoverBorderColor2 = color
      }
      NColorPicker {
        Layout.fillWidth: true
        selectedColor: root.editProfileCoverBorderColor3
        onColorSelected: color => root.editProfileCoverBorderColor3 = color
      }
    }

    RowLayout {
      Layout.fillWidth: true
      visible: root.editProfileCoverBorderColorCount > 3
      spacing: Style.marginS

      NColorPicker {
        Layout.fillWidth: true
        selectedColor: root.editProfileCoverBorderColor4
        onColorSelected: color => root.editProfileCoverBorderColor4 = color
      }
      NColorPicker {
        Layout.fillWidth: true
        visible: root.editProfileCoverBorderColorCount > 4
        selectedColor: root.editProfileCoverBorderColor5
        onColorSelected: color => root.editProfileCoverBorderColor5 = color
      }
    }
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBorder
    label: pluginApi?.tr("settings.profileCoverBorderAnimation")
    description: pluginApi?.tr("settings.profileCoverBorderAnimationDesc")
    model: [
      { "key": "static", "name": pluginApi?.tr("settings.profileCoverBorderStatic") },
      { "key": "fade", "name": pluginApi?.tr("settings.profileCoverBorderFade") },
      { "key": "flow", "name": pluginApi?.tr("settings.profileCoverBorderFlow") },
      { "key": "flowEase", "name": pluginApi?.tr("settings.profileCoverBorderFlowEase") },
      { "key": "spark", "name": pluginApi?.tr("settings.profileCoverBorderSpark") },
      { "key": "pulse", "name": pluginApi?.tr("settings.profileCoverBorderPulse") },
      { "key": "chase", "name": pluginApi?.tr("settings.profileCoverBorderChase") },
      { "key": "comet", "name": pluginApi?.tr("settings.profileCoverBorderComet") },
      { "key": "neon", "name": pluginApi?.tr("settings.profileCoverBorderNeon") },
      { "key": "corners", "name": pluginApi?.tr("settings.profileCoverBorderCorners") },
      { "key": "orbitDots", "name": pluginApi?.tr("settings.profileCoverBorderOrbitDots") },
      { "key": "scan", "name": pluginApi?.tr("settings.profileCoverBorderScan") },
      { "key": "profileAurora", "name": pluginApi?.tr("settings.profileCoverBorderAurora") },
      { "key": "profileHalo", "name": pluginApi?.tr("settings.profileCoverBorderHalo") },
      { "key": "profileHeartbeat", "name": pluginApi?.tr("settings.profileCoverBorderHeartbeat") },
      { "key": "profileSpotlight", "name": pluginApi?.tr("settings.profileCoverBorderSpotlight") },
      { "key": "reactivePulse", "name": pluginApi?.tr("settings.profileCoverBorderReactivePulse") },
      { "key": "reactiveFlow", "name": pluginApi?.tr("settings.profileCoverBorderReactiveFlow") },
      { "key": "reactiveSpark", "name": pluginApi?.tr("settings.profileCoverBorderReactiveSpark") }
    ]
    currentKey: root.editProfileCoverBorderAnimation
    onSelected: key => root.editProfileCoverBorderAnimation = key
    defaultValue: defaults.profileCoverBorderAnimation ?? "static"
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editProfileCoverMode !== "none" && root.editProfileCoverBorder && root.editProfileCoverBorderAnimation !== "static"
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.profileCoverBorderSpeed") + ": " + root.editProfileCoverBorderSpeed.toFixed(2) + "x"
      description: pluginApi?.tr("settings.profileCoverBorderSpeedDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 0.15
      to: 3
      stepSize: 0.05
      value: root.editProfileCoverBorderSpeed
      onMoved: root.editProfileCoverBorderSpeed = value
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.profileCardShape")
    description: pluginApi?.tr("settings.profileCardShapeDesc")
    model: [
      { "key": "rounded", "name": pluginApi?.tr("settings.profileCardShapeRounded") },
      { "key": "soft", "name": pluginApi?.tr("settings.profileCardShapeSoft") },
      { "key": "pill", "name": pluginApi?.tr("settings.profileCardShapePill") },
      { "key": "sharp", "name": pluginApi?.tr("settings.profileCardShapeSharp") }
    ]
    currentKey: root.editProfileCardShape
    onSelected: key => root.editProfileCardShape = key
    defaultValue: defaults.profileCardShape ?? "rounded"
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.avatarShape")
    description: pluginApi?.tr("settings.avatarShapeDesc")
    model: [
      {
        "key": "circle",
        "name": pluginApi?.tr("settings.avatarShapeCircle")
      },
      {
        "key": "rounded",
        "name": pluginApi?.tr("settings.avatarShapeRounded")
      }
    ]
    currentKey: root.editAvatarShape
    onSelected: key => root.editAvatarShape = key
    defaultValue: defaults.avatarShape ?? "circle"
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.panelScale") + ": " + Math.round(root.editPanelScale * 100) + "%"
      description: pluginApi?.tr("settings.panelScaleDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 0.75
      to: 1.25
      stepSize: 0.01
      value: root.editPanelScale
      onMoved: root.editPanelScale = value
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.iconName")
    description: pluginApi?.tr("settings.iconNameDesc")
    placeholderText: "layout-dashboard"
    text: root.editIconName
    onTextChanged: root.editIconName = text
  }

  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 2
    spacing: Style.marginM

  NText {
    text: pluginApi?.tr("settings.musicReactivity")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NLabel {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.dashboardMusicEffects")
    description: pluginApi?.tr("settings.dashboardMusicEffectsDesc")
  }

  NText {
    text: pluginApi?.tr("settings.dashboardPerformanceMode")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.followNoctaliaPerformanceMode")
    description: pluginApi?.tr("settings.followNoctaliaPerformanceModeDesc")
    checked: root.editFollowNoctaliaPerformanceMode
    onToggled: checked => root.editFollowNoctaliaPerformanceMode = checked
    defaultValue: defaults.followNoctaliaPerformanceMode ?? true
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.powerSaverPerformanceMode")
    description: pluginApi?.tr("settings.powerSaverPerformanceModeDesc")
    checked: root.editPowerSaverPerformanceMode
    onToggled: checked => root.editPowerSaverPerformanceMode = checked
    defaultValue: defaults.powerSaverPerformanceMode ?? true
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.mediaVisualizerEffect")
    description: pluginApi?.tr("settings.mediaVisualizerEffectDesc")
    model: [
      {
        "key": "none",
        "name": pluginApi?.tr("settings.visualizerNone")
      },
      {
        "key": "bars",
        "name": pluginApi?.tr("settings.visualizerBars")
      },
      {
        "key": "wave",
        "name": pluginApi?.tr("settings.visualizerWave")
      },
      {
        "key": "shock",
        "name": pluginApi?.tr("settings.visualizerShock")
      },
      {
        "key": "pulse",
        "name": pluginApi?.tr("settings.visualizerPulse")
      },
      {
        "key": "nebula",
        "name": pluginApi?.tr("settings.visualizerNebula")
      },
      {
        "key": "aurora",
        "name": pluginApi?.tr("settings.visualizerAurora")
      },
      {
        "key": "constellation",
        "name": pluginApi?.tr("settings.visualizerConstellation")
      },
      {
        "key": "radar",
        "name": pluginApi?.tr("settings.visualizerRadar")
      }
    ]
    currentKey: root.editMediaVisualizerEffect
    onSelected: key => root.editMediaVisualizerEffect = key
    defaultValue: defaults.mediaVisualizerEffect ?? "bars"
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.audioSliderEffect")
    description: pluginApi?.tr("settings.audioSliderEffectDesc")
    model: [
      {
        "key": "none",
        "name": pluginApi?.tr("settings.sliderEffectNone")
      },
      {
        "key": "wave",
        "name": pluginApi?.tr("settings.sliderEffectWave")
      },
      {
        "key": "zigzag",
        "name": pluginApi?.tr("settings.sliderEffectZigzag")
      },
      {
        "key": "pulse",
        "name": pluginApi?.tr("settings.sliderEffectPulse")
      },
      {
        "key": "bars",
        "name": pluginApi?.tr("settings.sliderEffectBars")
      }
    ]
    currentKey: root.editAudioSliderEffect
    onSelected: key => root.editAudioSliderEffect = key
    defaultValue: defaults.audioSliderEffect ?? "wave"
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.microphoneSliderEffect")
    description: pluginApi?.tr("settings.microphoneSliderEffectDesc")
    model: [
      {
        "key": "none",
        "name": pluginApi?.tr("settings.sliderEffectNone")
      },
      {
        "key": "wave",
        "name": pluginApi?.tr("settings.sliderEffectWave")
      },
      {
        "key": "zigzag",
        "name": pluginApi?.tr("settings.sliderEffectZigzag")
      },
      {
        "key": "pulse",
        "name": pluginApi?.tr("settings.sliderEffectPulse")
      },
      {
        "key": "bars",
        "name": pluginApi?.tr("settings.sliderEffectBars")
      }
    ]
    currentKey: root.editMicrophoneSliderEffect
    onSelected: key => root.editMicrophoneSliderEffect = key
    defaultValue: defaults.microphoneSliderEffect ?? "pulse"
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.avatarMusicEffect")
    description: pluginApi?.tr("settings.avatarMusicEffectDesc")
    model: [
      {
        "key": "none",
        "name": pluginApi?.tr("settings.avatarEffectNone")
      },
      {
        "key": "ring",
        "name": pluginApi?.tr("settings.avatarEffectRing")
      },
      {
        "key": "morph",
        "name": pluginApi?.tr("settings.avatarEffectMorph")
      },
      {
        "key": "both",
        "name": pluginApi?.tr("settings.avatarEffectBoth")
      },
      {
        "key": "glow",
        "name": pluginApi?.tr("settings.avatarEffectGlow")
      },
      {
        "key": "orbit",
        "name": pluginApi?.tr("settings.avatarEffectOrbit")
      },
      {
        "key": "studio",
        "name": pluginApi?.tr("settings.avatarEffectStudio")
      }
    ]
    currentKey: root.editAvatarMusicEffect
    onSelected: key => root.editAvatarMusicEffect = key
    defaultValue: defaults.avatarMusicEffect ?? "ring"
  }

  NTextInputButton {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.profileDanceGifPath")
    description: pluginApi?.tr("settings.profileDanceGifPathDesc")
    placeholderText: "~/Pictures/dance.gif"
    text: root.editProfileDanceGifPath
    buttonIcon: "photo"
    buttonTooltip: pluginApi?.tr("settings.chooseImageFile")
    onInputTextChanged: text => root.editProfileDanceGifPath = text
    onButtonClicked: root.openImagePicker("dance")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showProfileDanceGif")
    checked: root.editShowProfileDanceGif
    onToggled: checked => root.editShowProfileDanceGif = checked
    defaultValue: defaults.showProfileDanceGif ?? true
  }

  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 3
    spacing: Style.marginM

  NLabel {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.barMediaWidget")
    description: pluginApi?.tr("settings.barMediaWidgetDesc")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showBarMediaInfo")
    description: pluginApi?.tr("settings.showBarMediaInfoDesc")
    checked: root.editShowBarMediaInfo
    onToggled: checked => root.editShowBarMediaInfo = checked
    defaultValue: defaults.showBarMediaInfo ?? true
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaShowWhenPaused")
    description: pluginApi?.tr("settings.barMediaShowWhenPausedDesc")
    checked: root.editBarMediaShowWhenPaused
    onToggled: checked => root.editBarMediaShowWhenPaused = checked
    defaultValue: defaults.barMediaShowWhenPaused ?? false
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaShowAlbumArt")
    description: pluginApi?.tr("settings.barMediaShowAlbumArtDesc")
    checked: root.editBarMediaShowAlbumArt
    onToggled: checked => root.editBarMediaShowAlbumArt = checked
    defaultValue: defaults.barMediaShowAlbumArt ?? true
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaShowProgressRing")
    description: pluginApi?.tr("settings.barMediaShowProgressRingDesc")
    checked: root.editBarMediaShowProgressRing
    onToggled: checked => root.editBarMediaShowProgressRing = checked
    defaultValue: defaults.barMediaShowProgressRing ?? true
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaShowVisualizer")
    description: pluginApi?.tr("settings.barMediaShowVisualizerDesc")
    checked: root.editBarMediaShowVisualizer
    onToggled: checked => root.editBarMediaShowVisualizer = checked
    defaultValue: defaults.barMediaShowVisualizer ?? true
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo && root.editBarMediaShowVisualizer
    label: pluginApi?.tr("settings.barMediaVisualizerType")
    description: pluginApi?.tr("settings.barMediaVisualizerTypeDesc")
    model: [
      {
        "key": "linear",
        "name": pluginApi?.tr("settings.barVisualizerLinear")
      },
      {
        "key": "mirrored",
        "name": pluginApi?.tr("settings.barVisualizerMirrored")
      },
      {
        "key": "wave",
        "name": pluginApi?.tr("settings.barVisualizerWave")
      }
    ]
    currentKey: root.editBarMediaVisualizerType
    onSelected: key => root.editBarMediaVisualizerType = key
    defaultValue: defaults.barMediaVisualizerType ?? "linear"
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaShowArtistFirst")
    description: pluginApi?.tr("settings.barMediaShowArtistFirstDesc")
    checked: root.editBarMediaShowArtistFirst
    onToggled: checked => root.editBarMediaShowArtistFirst = checked
    defaultValue: defaults.barMediaShowArtistFirst ?? true
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaLayout")
    description: pluginApi?.tr("settings.barMediaLayoutDesc")
    model: [
      {
        "key": "auto",
        "name": pluginApi?.tr("settings.barMediaLayoutAuto")
      },
      {
        "key": "media-left",
        "name": pluginApi?.tr("settings.barMediaLayoutLeft")
      },
      {
        "key": "media-right",
        "name": pluginApi?.tr("settings.barMediaLayoutRight")
      }
    ]
    currentKey: root.editBarMediaLayout
    onSelected: key => root.editBarMediaLayout = key
    defaultValue: defaults.barMediaLayout ?? "auto"
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaScrollingMode")
    description: pluginApi?.tr("settings.barMediaScrollingModeDesc")
    model: [
      {
        "key": "always",
        "name": pluginApi?.tr("settings.scrollingAlways")
      },
      {
        "key": "hover",
        "name": pluginApi?.tr("settings.scrollingHover")
      },
      {
        "key": "never",
        "name": pluginApi?.tr("settings.scrollingNever")
      }
    ]
    currentKey: root.editBarMediaScrollingMode
    onSelected: key => root.editBarMediaScrollingMode = key
    defaultValue: defaults.barMediaScrollingMode ?? "hover"
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.barMediaMaxWidth") + ": " + root.editBarMediaMaxWidth + "px"
      description: pluginApi?.tr("settings.barMediaMaxWidthDesc")
    }

    NSlider {
      Layout.fillWidth: true
      from: 90
      to: 260
      stepSize: 5
      value: root.editBarMediaMaxWidth
      onMoved: root.editBarMediaMaxWidth = Math.round(value)
    }
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editShowBarMediaInfo
    label: pluginApi?.tr("settings.barMediaUseFixedWidth")
    description: pluginApi?.tr("settings.barMediaUseFixedWidthDesc")
    checked: root.editBarMediaUseFixedWidth
    onToggled: checked => root.editBarMediaUseFixedWidth = checked
    defaultValue: defaults.barMediaUseFixedWidth ?? false
  }

  NColorChoice {
    visible: root.editShowBarMediaInfo
    currentKey: root.editBarMediaTextColor
    onSelected: key => root.editBarMediaTextColor = key
    defaultValue: defaults.barMediaTextColor ?? "none"
  }

  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 4
    spacing: Style.marginM

  NText {
    text: pluginApi?.tr("settings.sections")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showNotifications")
    checked: root.editShowNotifications
    onToggled: checked => root.editShowNotifications = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showMedia")
    checked: root.editShowMedia
    onToggled: checked => root.editShowMedia = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showCalendar")
    checked: root.editShowCalendar
    onToggled: checked => root.editShowCalendar = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showRecordingCard")
    checked: root.editShowRecordingCard
    onToggled: checked => root.editShowRecordingCard = checked
  }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.settingsTab === 5
    spacing: Style.marginM

    NText {
      text: pluginApi?.tr("settings.componentColors")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    NLabel {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.componentColorsIntro")
      description: pluginApi?.tr("settings.componentColorsIntroDesc")
    }

    NComboBox {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.componentStyleTarget")
      description: pluginApi?.tr("settings.componentStyleTargetDesc")
      model: [
        { "key": "__global", "name": pluginApi?.tr("settings.componentAll") },
        { "key": "profile", "name": pluginApi?.tr("settings.componentProfile") },
        { "key": "quickActions", "name": pluginApi?.tr("settings.componentQuickActions") },
        { "key": "recording", "name": pluginApi?.tr("settings.componentRecording") },
        { "key": "performance", "name": pluginApi?.tr("settings.componentPerformance") },
        { "key": "systemControls", "name": pluginApi?.tr("settings.componentSystemControls") },
        { "key": "notifications", "name": pluginApi?.tr("settings.componentNotifications") },
        { "key": "media", "name": pluginApi?.tr("settings.componentMedia") },
        { "key": "calendar", "name": pluginApi?.tr("settings.componentCalendar") },
        { "key": "screenUsage", "name": pluginApi?.tr("settings.componentScreenUsage") },
        { "key": "barWidget", "name": pluginApi?.tr("settings.componentBarWidget") }
      ]
      currentKey: root.editComponentStyleTarget
      onSelected: key => root.editComponentStyleTarget = key
      defaultValue: "__global"
    }

    NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.componentStyleEnabled")
      description: pluginApi?.tr("settings.componentStyleEnabledDesc")
      checked: root.componentStyleValue("enabled", false)
      onToggled: checked => root.setComponentStyleValue("enabled", checked)
      defaultValue: false
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentBackground")
        description: pluginApi?.tr("settings.componentBackgroundDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("background", Color.mSurfaceVariant)
        onColorSelected: color => root.setComponentStyleValue("background", color.toString())
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentText")
        description: pluginApi?.tr("settings.componentTextDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("text", Color.mOnSurface)
        onColorSelected: color => root.setComponentStyleValue("text", color.toString())
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentSubtext")
        description: pluginApi?.tr("settings.componentSubtextDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("subtext", Color.mOnSurfaceVariant)
        onColorSelected: color => root.setComponentStyleValue("subtext", color.toString())
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentAccent")
        description: pluginApi?.tr("settings.componentAccentDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("accent", Color.mPrimary)
        onColorSelected: color => root.setComponentStyleValue("accent", color.toString())
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentButtonBackground")
        description: pluginApi?.tr("settings.componentButtonBackgroundDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("buttonBackground", Color.mPrimary)
        onColorSelected: color => root.setComponentStyleValue("buttonBackground", color.toString())
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      enabled: root.componentStyleValue("enabled", false)
      opacity: enabled ? 1 : 0.5

      NLabel {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.componentButtonText")
        description: pluginApi?.tr("settings.componentButtonTextDesc")
      }

      NColorPicker {
        Layout.minimumWidth: 180
        selectedColor: root.componentStyleColor("buttonText", Color.mOnPrimary)
        onColorSelected: color => root.setComponentStyleValue("buttonText", color.toString())
      }
    }

    NText {
      text: pluginApi?.tr("settings.componentBorder")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }

    NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.componentBorderEnabled")
      description: pluginApi?.tr("settings.componentBorderEnabledDesc")
      checked: root.componentStyleValue("borderEnabled", false)
      onToggled: checked => root.setComponentStyleValue("borderEnabled", checked)
      defaultValue: false
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false)
      spacing: Style.marginS

      NLabel {
        label: pluginApi?.tr("settings.componentBorderWidth") + ": " + Number(root.componentStyleValue("borderWidth", 2)).toFixed(1) + "px"
        description: pluginApi?.tr("settings.componentBorderWidthDesc")
      }

      NSlider {
        Layout.fillWidth: true
        from: 1
        to: 8
        stepSize: 0.5
        value: Number(root.componentStyleValue("borderWidth", 2))
        onMoved: root.setComponentStyleValue("borderWidth", value)
      }
    }

    NComboBox {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false)
      label: pluginApi?.tr("settings.componentBorderScope")
      description: pluginApi?.tr("settings.componentBorderScopeDesc")
      model: [
        { "key": "all", "name": pluginApi?.tr("settings.componentBorderScopeAll") },
        { "key": "container", "name": pluginApi?.tr("settings.componentBorderScopeContainer") },
        { "key": "children", "name": pluginApi?.tr("settings.componentBorderScopeChildren") }
      ]
      currentKey: String(root.componentStyleValue("borderScope", "all"))
      onSelected: key => root.setComponentStyleValue("borderScope", key)
      defaultValue: "all"
    }

    NComboBox {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false)
      label: pluginApi?.tr("settings.componentBorderColorMode")
      description: pluginApi?.tr("settings.componentBorderColorModeDesc")
      model: [
        { "key": "auto", "name": pluginApi?.tr("settings.profileCoverBorderAutoColors") },
        { "key": "custom", "name": pluginApi?.tr("settings.profileCoverBorderCustomColors") }
      ]
      currentKey: String(root.componentStyleValue("borderColorMode", "auto"))
      onSelected: key => root.setComponentStyleValue("borderColorMode", key)
      defaultValue: "auto"
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false) && root.componentStyleValue("borderColorMode", "auto") === "custom"
      spacing: Style.marginS

      NLabel {
        label: pluginApi?.tr("settings.profileCoverBorderColorCount") + ": " + Number(root.componentStyleValue("borderColorCount", 3))
        description: pluginApi?.tr("settings.profileCoverBorderColorCountDesc")
      }

      NSlider {
        Layout.fillWidth: true
        from: 3
        to: 5
        stepSize: 1
        value: Number(root.componentStyleValue("borderColorCount", 3))
        onMoved: root.setComponentStyleValue("borderColorCount", Math.round(value))
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NColorPicker {
          Layout.fillWidth: true
          selectedColor: root.componentStyleColor("borderColor1", "#fff59b")
          onColorSelected: color => root.setComponentStyleValue("borderColor1", color.toString())
        }
        NColorPicker {
          Layout.fillWidth: true
          selectedColor: root.componentStyleColor("borderColor2", "#8bd5ff")
          onColorSelected: color => root.setComponentStyleValue("borderColor2", color.toString())
        }
        NColorPicker {
          Layout.fillWidth: true
          selectedColor: root.componentStyleColor("borderColor3", "#cba6f7")
          onColorSelected: color => root.setComponentStyleValue("borderColor3", color.toString())
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: Number(root.componentStyleValue("borderColorCount", 3)) > 3
        spacing: Style.marginS

        NColorPicker {
          Layout.fillWidth: true
          selectedColor: root.componentStyleColor("borderColor4", "#f38ba8")
          onColorSelected: color => root.setComponentStyleValue("borderColor4", color.toString())
        }
        NColorPicker {
          Layout.fillWidth: true
          visible: Number(root.componentStyleValue("borderColorCount", 3)) > 4
          selectedColor: root.componentStyleColor("borderColor5", "#a6e3a1")
          onColorSelected: color => root.setComponentStyleValue("borderColor5", color.toString())
        }
      }
    }

    NComboBox {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false)
      label: pluginApi?.tr("settings.componentBorderAnimation")
      description: pluginApi?.tr("settings.componentBorderAnimationDesc")
      model: [
        { "key": "static", "name": pluginApi?.tr("settings.profileCoverBorderStatic") },
        { "key": "fade", "name": pluginApi?.tr("settings.profileCoverBorderFade") },
        { "key": "flow", "name": pluginApi?.tr("settings.profileCoverBorderFlow") },
        { "key": "flowEase", "name": pluginApi?.tr("settings.profileCoverBorderFlowEase") },
        { "key": "spark", "name": pluginApi?.tr("settings.profileCoverBorderSpark") },
        { "key": "pulse", "name": pluginApi?.tr("settings.profileCoverBorderPulse") },
        { "key": "chase", "name": pluginApi?.tr("settings.profileCoverBorderChase") },
        { "key": "comet", "name": pluginApi?.tr("settings.profileCoverBorderComet") },
        { "key": "neon", "name": pluginApi?.tr("settings.profileCoverBorderNeon") },
        { "key": "corners", "name": pluginApi?.tr("settings.profileCoverBorderCorners") },
        { "key": "orbitDots", "name": pluginApi?.tr("settings.profileCoverBorderOrbitDots") },
        { "key": "scan", "name": pluginApi?.tr("settings.profileCoverBorderScan") },
        { "key": "reactivePulse", "name": pluginApi?.tr("settings.profileCoverBorderReactivePulse") },
        { "key": "reactiveFlow", "name": pluginApi?.tr("settings.profileCoverBorderReactiveFlow") },
        { "key": "reactiveSpark", "name": pluginApi?.tr("settings.profileCoverBorderReactiveSpark") }
      ]
      currentKey: String(root.componentStyleValue("borderAnimation", "static"))
      onSelected: key => root.setComponentStyleValue("borderAnimation", key)
      defaultValue: "static"
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: root.componentStyleValue("borderEnabled", false) && root.componentStyleValue("borderAnimation", "static") !== "static"
      spacing: Style.marginS

      NLabel {
        label: pluginApi?.tr("settings.componentBorderSpeed") + ": " + Number(root.componentStyleValue("borderSpeed", 1)).toFixed(2) + "x"
        description: pluginApi?.tr("settings.componentBorderSpeedDesc")
      }

      NSlider {
        Layout.fillWidth: true
        from: 0.15
        to: 3
        stepSize: 0.05
        value: Number(root.componentStyleValue("borderSpeed", 1))
        onMoved: root.setComponentStyleValue("borderSpeed", value)
      }
    }
  }

  function currentComponentStyle() {
    return root.editComponentStyles[root.editComponentStyleTarget] || {};
  }

  function componentStyleValue(field, fallback) {
    const style = root.currentComponentStyle();
    return style[field] !== undefined ? style[field] : fallback;
  }

  function componentStyleColor(field, fallback) {
    const value = String(root.componentStyleValue(field, "") || "").trim();
    return value !== "" ? value : fallback;
  }

  function componentStyleTargetKeys() {
    return [
      "profile",
      "quickActions",
      "recording",
      "performance",
      "systemControls",
      "notifications",
      "media",
      "calendar",
      "screenUsage",
      "barWidget"
    ];
  }

  function setComponentStyleValue(field, value) {
    const styles = Object.assign({}, root.editComponentStyles || {});
    const targets = root.editComponentStyleTarget === "__global" ? ["__global"].concat(root.componentStyleTargetKeys()) : [root.editComponentStyleTarget];

    for (let i = 0; i < targets.length; i++) {
      const key = targets[i];
      const style = Object.assign({}, styles[key] || {});
      style[field] = value;
      styles[key] = style;
    }

    root.editComponentStyles = styles;
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("RaellDashboard", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.avatarPath = root.editAvatarPath;
    pluginApi.pluginSettings.panelDetached = root.editPanelDetached;
    pluginApi.pluginSettings.panelPosition = root.editPanelPosition;
    pluginApi.pluginSettings.followBarEdge = root.editFollowBarEdge;
    pluginApi.pluginSettings.panelWidth = root.editPanelWidth;
    pluginApi.pluginSettings.panelHeight = root.editPanelHeight;
    pluginApi.pluginSettings.panelScale = root.editPanelScale;
    pluginApi.pluginSettings.mediaVisualizerEffect = root.editMediaVisualizerEffect;
    pluginApi.pluginSettings.audioSliderEffect = root.editAudioSliderEffect;
    pluginApi.pluginSettings.microphoneSliderEffect = root.editMicrophoneSliderEffect;
    pluginApi.pluginSettings.avatarMusicEffect = root.editAvatarMusicEffect;
    pluginApi.pluginSettings.avatarShape = root.editAvatarShape;
    pluginApi.pluginSettings.profileCardShape = root.editProfileCardShape;
    pluginApi.pluginSettings.followNoctaliaPerformanceMode = root.editFollowNoctaliaPerformanceMode;
    pluginApi.pluginSettings.powerSaverPerformanceMode = root.editPowerSaverPerformanceMode;
    pluginApi.pluginSettings.profileDanceGifPath = root.editProfileDanceGifPath;
    pluginApi.pluginSettings.showProfileDanceGif = root.editShowProfileDanceGif;
    pluginApi.pluginSettings.showProfileWallpaper = root.editShowProfileWallpaper;
    pluginApi.pluginSettings.profileCoverMode = root.editProfileCoverMode;
    pluginApi.pluginSettings.profileCoverPath = root.editProfileCoverPath;
    pluginApi.pluginSettings.profileCoverFolder = root.editProfileCoverFolder;
    pluginApi.pluginSettings.profileCoverOverlayEnabled = root.editProfileCoverOverlayEnabled;
    pluginApi.pluginSettings.profileCoverOverlay = root.editProfileCoverOverlay;
    pluginApi.pluginSettings.profileCoverBlurEnabled = root.editProfileCoverBlurEnabled;
    pluginApi.pluginSettings.profileCoverBlur = root.editProfileCoverBlur;
    pluginApi.pluginSettings.profileCoverBorder = root.editProfileCoverBorder;
    pluginApi.pluginSettings.profileCoverBorderWidth = root.editProfileCoverBorderWidth;
    pluginApi.pluginSettings.profileCoverBorderEffect = root.editProfileCoverBorderEffect;
    pluginApi.pluginSettings.profileCoverBorderColorMode = root.editProfileCoverBorderColorMode;
    pluginApi.pluginSettings.profileCoverBorderAnimation = root.editProfileCoverBorderAnimation;
    pluginApi.pluginSettings.profileCoverBorderSpeed = root.editProfileCoverBorderSpeed;
    pluginApi.pluginSettings.profileCoverBorderColorCount = root.editProfileCoverBorderColorCount;
    pluginApi.pluginSettings.profileCoverBorderColor1 = root.editProfileCoverBorderColor1.toString();
    pluginApi.pluginSettings.profileCoverBorderColor2 = root.editProfileCoverBorderColor2.toString();
    pluginApi.pluginSettings.profileCoverBorderColor3 = root.editProfileCoverBorderColor3.toString();
    pluginApi.pluginSettings.profileCoverBorderColor4 = root.editProfileCoverBorderColor4.toString();
    pluginApi.pluginSettings.profileCoverBorderColor5 = root.editProfileCoverBorderColor5.toString();
    pluginApi.pluginSettings.componentStyles = root.editComponentStyles;
    pluginApi.pluginSettings.showBarMediaInfo = root.editShowBarMediaInfo;
    pluginApi.pluginSettings.barMediaShowWhenPaused = root.editBarMediaShowWhenPaused;
    pluginApi.pluginSettings.barMediaShowAlbumArt = root.editBarMediaShowAlbumArt;
    pluginApi.pluginSettings.barMediaShowVisualizer = root.editBarMediaShowVisualizer;
    pluginApi.pluginSettings.barMediaVisualizerType = root.editBarMediaVisualizerType;
    pluginApi.pluginSettings.barMediaShowProgressRing = root.editBarMediaShowProgressRing;
    pluginApi.pluginSettings.barMediaShowArtistFirst = root.editBarMediaShowArtistFirst;
    pluginApi.pluginSettings.barMediaScrollingMode = root.editBarMediaScrollingMode;
    pluginApi.pluginSettings.barMediaLayout = root.editBarMediaLayout;
    pluginApi.pluginSettings.barMediaMaxWidth = root.editBarMediaMaxWidth;
    pluginApi.pluginSettings.barMediaUseFixedWidth = root.editBarMediaUseFixedWidth;
    pluginApi.pluginSettings.barMediaTextColor = root.editBarMediaTextColor;
    pluginApi.pluginSettings.showNotifications = root.editShowNotifications;
    pluginApi.pluginSettings.showMedia = root.editShowMedia;
    pluginApi.pluginSettings.showCalendar = root.editShowCalendar;
    pluginApi.pluginSettings.showRecordingCard = root.editShowRecordingCard;
    pluginApi.pluginSettings.iconName = root.editIconName;
    delete pluginApi.pluginSettings.attachmentStyle;
    delete pluginApi.pluginSettings.recordingDir;
    pluginApi.saveSettings();

    Logger.i("RaellDashboard", "Settings saved");
  }

  function pickerInitialPath(path) {
    const resolved = Settings.preprocessPath(path || "");
    const slash = resolved.lastIndexOf("/");
    if (slash > 0)
      return resolved.substring(0, slash);
    return Quickshell.env("HOME") || "/home";
  }

  function openImagePicker(target) {
    root.pendingImageTarget = target;
    const currentPath = target === "dance" ? root.editProfileDanceGifPath : (target === "cover" ? root.editProfileCoverPath : (target === "coverFolder" ? root.editProfileCoverFolder : root.editAvatarPath));
    imagePicker.selectionMode = target === "coverFolder" ? "folders" : "files";
    imagePicker.initialPath = root.pickerInitialPath(currentPath);
    imagePicker.openFilePicker();
  }

  NFilePicker {
    id: imagePicker
    title: pluginApi?.tr("settings.chooseImageFile")
    selectionMode: "files"
    nameFilters: ImageCacheService.extendedImageFilters
    initialPath: Quickshell.env("HOME") || "/home"
    onAccepted: paths => {
      if (!paths || paths.length === 0)
        return;
      if (root.pendingImageTarget === "dance")
        root.editProfileDanceGifPath = paths[0];
      else if (root.pendingImageTarget === "cover")
        root.editProfileCoverPath = paths[0];
      else if (root.pendingImageTarget === "coverFolder")
        root.editProfileCoverFolder = paths[0];
      else
        root.editAvatarPath = paths[0];
    }
  }
}
