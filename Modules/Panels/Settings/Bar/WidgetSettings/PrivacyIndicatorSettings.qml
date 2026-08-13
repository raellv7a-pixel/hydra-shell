import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  property bool valueHideInactive: widgetData.hideInactive !== undefined ? widgetData.hideInactive : widgetMetadata.hideInactive

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.hideInactive = valueHideInactive;
    settingsChanged(settings);
  }

  NToggle {
    label: I18n.tr("bar.privacy-indicator.hide-inactive-label")
    description: I18n.tr("bar.privacy-indicator.hide-inactive-description")
    checked: root.valueHideInactive
    onToggled: checked => {
                 valueHideInactive = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideInactive
  }
}
