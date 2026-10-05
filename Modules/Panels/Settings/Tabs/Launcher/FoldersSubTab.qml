import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  spacing: Style.marginL
  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("launcher-home.settings.folder-icons")
    model: [
      { key: "hydra", name: I18n.tr("launcher-home.settings.hydra-icons") },
      { key: "system", name: I18n.tr("launcher-home.settings.system-icons") }
    ]
    currentKey: Settings.data.appLauncher.folderIconSource
    onSelected: key => Settings.data.appLauncher.folderIconSource = key
    defaultValue: Settings.getDefaultValue("appLauncher.folderIconSource")
  }
  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("launcher-home.settings.folder-icon-size")
    description: I18n.tr("launcher-home.settings.folder-icon-size-description")
    from: 24
    to: 48
    stepSize: 2
    value: Settings.data.appLauncher.folderIconSize
    text: Math.round(value) + "px"
    onMoved: value => Settings.data.appLauncher.folderIconSize = Math.round(value)
    defaultValue: Settings.getDefaultValue("appLauncher.folderIconSize")
  }
}
