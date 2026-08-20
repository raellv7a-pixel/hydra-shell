import QtQuick
import QtQuick.Layouts
import qs.Commons
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
    label: root.dtr("settingsVisibleCards")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowNotifications")
    checked: Settings.data.controlCenter.showNotifications
    onToggled: checked => Settings.data.controlCenter.showNotifications = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showNotifications")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowMedia")
    checked: Settings.data.controlCenter.showMedia
    onToggled: checked => Settings.data.controlCenter.showMedia = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showMedia")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowCalendar")
    checked: Settings.data.controlCenter.showCalendar
    onToggled: checked => Settings.data.controlCenter.showCalendar = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showCalendar")
  }

  NToggle {
    Layout.fillWidth: true
    label: root.dtr("settingsShowRecordingCard")
    checked: Settings.data.controlCenter.showRecordingCard
    onToggled: checked => Settings.data.controlCenter.showRecordingCard = checked
    defaultValue: Settings.getDefaultValue("controlCenter.showRecordingCard")
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
