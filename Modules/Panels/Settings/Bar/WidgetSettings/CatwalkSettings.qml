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

  // Local state
  property real valueMinimumThreshold: widgetData.minimumThreshold !== undefined ? widgetData.minimumThreshold : widgetMetadata.minimumThreshold

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.minimumThreshold = valueMinimumThreshold;
    settingsChanged(settings);
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.catwalk.minimum-threshold-label")
    description: I18n.tr("bar.catwalk.minimum-threshold-description")
    from: 5
    to: 25
    stepSize: 1
    showReset: true
    value: root.valueMinimumThreshold
    defaultValue: widgetMetadata.minimumThreshold
    onMoved: value => {
      root.valueMinimumThreshold = Math.round(value);
      saveSettings();
    }
    text: Math.round(root.valueMinimumThreshold) + "%"
  }
}
