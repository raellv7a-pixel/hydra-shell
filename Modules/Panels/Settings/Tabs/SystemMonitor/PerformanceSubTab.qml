import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.hydra-performance-disable-wallpaper-label")
    description: I18n.tr("panels.system.hydra-performance-disable-wallpaper-description")
    checked: !Settings.data.hydraPerformance.disableWallpaper
    defaultValue: !Settings.getDefaultValue("hydraPerformance.disableWallpaper")
    onToggled: checked => Settings.data.hydraPerformance.disableWallpaper = !checked
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.hydra-performance-disable-desktop-widgets-label")
    description: I18n.tr("panels.system.hydra-performance-disable-desktop-widgets-description")
    checked: !Settings.data.hydraPerformance.disableDesktopWidgets
    defaultValue: !Settings.getDefaultValue("hydraPerformance.disableDesktopWidgets")
    onToggled: checked => Settings.data.hydraPerformance.disableDesktopWidgets = !checked
  }
}
