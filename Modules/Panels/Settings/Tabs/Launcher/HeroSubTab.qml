import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  readonly property bool heroEnabled: Settings.data.appLauncher.coverMode !== "none"
  NComboBox {
    label: I18n.tr("launcher-home.settings.cover-mode")
    description: I18n.tr("launcher-home.settings.cover-mode-description")
    Layout.fillWidth: true
    model: [
      {
        "key": "auto",
        "name": I18n.tr("options.launcher-cover-mode.auto")
      },
      {
        "key": "custom",
        "name": I18n.tr("options.launcher-cover-mode.custom")
      },
      {
        "key": "random",
        "name": I18n.tr("options.launcher-cover-mode.random")
      },
      {
        "key": "none",
        "name": I18n.tr("options.launcher-cover-mode.none")
      }
    ]
    currentKey: Settings.data.appLauncher.coverMode || "auto"
    onSelected: function (key) {
      Settings.data.appLauncher.coverMode = key;
    }
    defaultValue: Settings.getDefaultValue("appLauncher.coverMode")
  }

  NTextInputButton {
    visible: (Settings.data.appLauncher.coverMode || "auto") === "custom"
    label: I18n.tr("panels.launcher.settings-cover-path-label")
    description: I18n.tr("panels.launcher.settings-cover-path-description")
    Layout.fillWidth: true
    text: Settings.data.appLauncher.coverPath || ""
    placeholderText: "~/Pictures/Wallpapers/cover.png"
    buttonIcon: "photo"
    buttonTooltip: I18n.tr("widgets.file-picker.select-file")
    onInputTextChanged: text => Settings.data.appLauncher.coverPath = text
    onButtonClicked: coverFilePicker.openFilePicker()
  }

  NTextInputButton {
    visible: (Settings.data.appLauncher.coverMode || "auto") === "random"
    label: I18n.tr("panels.launcher.settings-cover-folder-label")
    description: I18n.tr("panels.launcher.settings-cover-folder-description")
    Layout.fillWidth: true
    text: Settings.data.appLauncher.coverFolder || ""
    placeholderText: "~/Pictures/Wallpapers"
    buttonIcon: "folder"
    buttonTooltip: I18n.tr("widgets.file-picker.select-folder")
    onInputTextChanged: text => Settings.data.appLauncher.coverFolder = text
    onButtonClicked: coverFolderPicker.openFilePicker()
  }

  NLabel {
    visible: (Settings.data.appLauncher.coverMode || "auto") !== "none"
    label: I18n.tr("panels.launcher.settings-cover-height-label") + ": " + Math.round(Settings.data.appLauncher.coverHeight || 160) + "px"
    description: I18n.tr("panels.launcher.settings-cover-height-description")
  }

  NSlider {
    visible: (Settings.data.appLauncher.coverMode || "auto") !== "none"
    Layout.fillWidth: true
    value: Settings.data.appLauncher.coverHeight || 160
    from: 100
    to: 260
    stepSize: 10
    onMoved: Settings.data.appLauncher.coverHeight = Math.round(value)
  }

  NLabel {
    visible: (Settings.data.appLauncher.coverMode || "auto") !== "none"
    label: I18n.tr("launcher-home.settings.overlay") + ": " + Math.round((Settings.data.appLauncher.coverOverlay ?? 0.40) * 100) + "%"
    description: I18n.tr("launcher-home.settings.overlay-description")
  }

  NSlider {
    visible: (Settings.data.appLauncher.coverMode || "auto") !== "none"
    Layout.fillWidth: true
    value: Settings.data.appLauncher.coverOverlay ?? 0.40
    from: 0.0
    to: 0.90
    stepSize: 0.05
    onMoved: Settings.data.appLauncher.coverOverlay = value
  }

  NFilePicker {
    id: coverFilePicker
    title: I18n.tr("widgets.file-picker.select-file")
    selectionMode: "files"
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
    onAccepted: paths => {
                  if (paths && paths.length > 0)
                  Settings.data.appLauncher.coverPath = paths[0];
                }
  }

  NFilePicker {
    id: coverFolderPicker
    title: I18n.tr("widgets.file-picker.select-folder")
    selectionMode: "folders"
    showDirs: true
    onAccepted: paths => {
                  if (paths && paths.length > 0)
                  Settings.data.appLauncher.coverFolder = paths[0];
                }
  }

  NComboBox {
    visible: root.heroEnabled
    Layout.fillWidth: true
    label: I18n.tr("launcher-home.settings.contrast")
    description: I18n.tr("launcher-home.settings.contrast-description")
    model: [
      { key: "light", name: I18n.tr("launcher-home.settings.light-text") },
      { key: "dark", name: I18n.tr("launcher-home.settings.dark-text") }
    ]
    currentKey: Settings.data.appLauncher.heroTextContrast
    onSelected: key => Settings.data.appLauncher.heroTextContrast = key
    defaultValue: Settings.getDefaultValue("appLauncher.heroTextContrast")
  }
  NToggle {
    visible: root.heroEnabled
    label: I18n.tr("launcher-home.settings.context")
    description: I18n.tr("launcher-home.settings.context-description")
    checked: Settings.data.appLauncher.heroShowContext
    onToggled: checked => Settings.data.appLauncher.heroShowContext = checked
    defaultValue: Settings.getDefaultValue("appLauncher.heroShowContext")
  }
  NToggle {
    visible: root.heroEnabled && Settings.data.appLauncher.heroShowContext
    label: I18n.tr("launcher-home.settings.auto-rotate")
    description: I18n.tr("launcher-home.settings.auto-rotate-description")
    checked: Settings.data.appLauncher.heroAutoRotate
    onToggled: checked => Settings.data.appLauncher.heroAutoRotate = checked
    defaultValue: Settings.getDefaultValue("appLauncher.heroAutoRotate")
  }
  NToggle {
    visible: root.heroEnabled
    label: I18n.tr("launcher-home.settings.blur")
    description: I18n.tr("launcher-home.settings.blur-description")
    checked: Settings.data.appLauncher.coverBlurEnabled
    onToggled: checked => Settings.data.appLauncher.coverBlurEnabled = checked
    defaultValue: Settings.getDefaultValue("appLauncher.coverBlurEnabled")
  }
  NValueSlider {
    visible: root.heroEnabled
    Layout.fillWidth: true
    label: I18n.tr("launcher-home.settings.blur-intensity")
    description: I18n.tr("launcher-home.settings.blur-intensity-description")
    from: 0
    to: 1
    stepSize: 0.05
    value: Settings.data.appLauncher.heroBlurIntensity
    text: Math.round(value * 100) + "%"
    enabled: Settings.data.appLauncher.coverBlurEnabled
    onMoved: value => Settings.data.appLauncher.heroBlurIntensity = value
    defaultValue: Settings.getDefaultValue("appLauncher.heroBlurIntensity")
  }
}
