import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NComboBox {
    label: I18n.tr("common.position")
    description: I18n.tr("panels.session-menu.position-description")
    Layout.fillWidth: true
    model: [
      {
        "key": "follow_bar",
        "name": I18n.tr("positions.follow-bar")
      },
      {
        "key": "center",
        "name": I18n.tr("positions.center")
      },
      {
        "key": "top_center",
        "name": I18n.tr("positions.top-center")
      },
      {
        "key": "top_left",
        "name": I18n.tr("positions.top-left")
      },
      {
        "key": "top_right",
        "name": I18n.tr("positions.top-right")
      },
      {
        "key": "bottom_center",
        "name": I18n.tr("positions.bottom-center")
      },
      {
        "key": "bottom_left",
        "name": I18n.tr("positions.bottom-left")
      },
      {
        "key": "bottom_right",
        "name": I18n.tr("positions.bottom-right")
      }
    ]
    currentKey: Settings.data.sessionMenu.position || "follow_bar"
    onSelected: key => Settings.data.sessionMenu.position = key
    defaultValue: Settings.getDefaultValue("sessionMenu.position")
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.show-profile-badge-label")
    description: I18n.tr("panels.session-menu.show-profile-badge-description")
    checked: Settings.data.sessionMenu.showProfileBadge ?? true
    onToggled: checked => Settings.data.sessionMenu.showProfileBadge = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.showProfileBadge")
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.show-uptime-badge-label")
    description: I18n.tr("panels.session-menu.show-uptime-badge-description")
    checked: Settings.data.sessionMenu.showUptimeBadge ?? true
    onToggled: checked => Settings.data.sessionMenu.showUptimeBadge = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.showUptimeBadge")
  }

  NComboBox {
    label: I18n.tr("panels.session-menu.cover-card-mode-label")
    description: I18n.tr("panels.session-menu.cover-card-mode-description")
    Layout.fillWidth: true
    model: [
      {
        "key": "auto",
        "name": I18n.tr("options.session-menu-cover-mode.auto")
      },
      {
        "key": "avatar",
        "name": I18n.tr("options.session-menu-cover-mode.avatar")
      },
      {
        "key": "custom",
        "name": I18n.tr("options.session-menu-cover-mode.custom")
      }
    ]
    currentKey: Settings.data.sessionMenu.coverCardMode || "auto"
    onSelected: key => Settings.data.sessionMenu.coverCardMode = key
    defaultValue: Settings.getDefaultValue("sessionMenu.coverCardMode")
  }

  NTextInputButton {
    visible: (Settings.data.sessionMenu.coverCardMode || "auto") === "custom"
    label: I18n.tr("panels.session-menu.cover-card-path-label")
    description: I18n.tr("panels.session-menu.cover-card-path-description")
    Layout.fillWidth: true
    text: Settings.data.sessionMenu.coverCardPath || ""
    placeholderText: "~/Pictures/Wallpapers/cover.png"
    buttonIcon: "photo"
    buttonTooltip: I18n.tr("widgets.file-picker.select-file")
    onInputTextChanged: text => Settings.data.sessionMenu.coverCardPath = text
    onButtonClicked: coverFilePicker.openFilePicker()
  }

  NFilePicker {
    id: coverFilePicker
    title: I18n.tr("widgets.file-picker.select-file")
    selectionMode: "files"
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
    onAccepted: paths => {
      if (paths && paths.length > 0)
        Settings.data.sessionMenu.coverCardPath = paths[0];
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.show-keybinds-label")
    description: I18n.tr("panels.session-menu.show-keybinds-description")
    checked: Settings.data.sessionMenu.showKeybinds
    onToggled: checked => Settings.data.sessionMenu.showKeybinds = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.showKeybinds")
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.enable-countdown-label")
    description: I18n.tr("panels.session-menu.enable-countdown-description")
    checked: Settings.data.sessionMenu.enableCountdown
    onToggled: checked => Settings.data.sessionMenu.enableCountdown = checked
    defaultValue: Settings.getDefaultValue("sessionMenu.enableCountdown")
  }

  NValueSlider {
    visible: Settings.data.sessionMenu.enableCountdown
    Layout.fillWidth: true
    label: I18n.tr("panels.session-menu.countdown-duration-label")
    description: I18n.tr("panels.session-menu.countdown-duration-description")
    from: 1000
    to: 30000
    stepSize: 1000
    showReset: true
    value: Settings.data.sessionMenu.countdownDuration
    onMoved: value => Settings.data.sessionMenu.countdownDuration = value
    text: Math.round(Settings.data.sessionMenu.countdownDuration / 1000) + "s"
    defaultValue: Settings.getDefaultValue("sessionMenu.countdownDuration")
  }
}
