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

  // Local state persisted with this bar-widget instance.
  property string valueIconColor: widgetData.iconColor !== undefined ? widgetData.iconColor : widgetMetadata.iconColor
  property int valueVibranceValue: widgetData.vibranceValue !== undefined ? widgetData.vibranceValue : Settings.data.nvibrant.vibranceValue
  property int valueDisplayIndex: widgetData.displayIndex !== undefined ? widgetData.displayIndex : Settings.data.nvibrant.displayIndex

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.iconColor = valueIconColor;
    settings.vibranceValue = valueVibranceValue;
    settings.displayIndex = valueDisplayIndex;
    settingsChanged(settings);
  }

  NColorChoice {
    label: I18n.tr("common.select-icon-color")
    currentKey: valueIconColor
    onSelected: key => {
      valueIconColor = key;
      saveSettings();
    }
    defaultValue: widgetMetadata.iconColor
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.nvibrant.vibrance-value-label")
    description: I18n.tr("bar.nvibrant.vibrance-value-description")
    from: 0
    to: 1023
    stepSize: 1
    showReset: true
    value: root.valueVibranceValue
    defaultValue: widgetMetadata.vibranceValue
    onMoved: value => {
      root.valueVibranceValue = Math.round(value);
      root.saveSettings();
    }
    text: String(root.valueVibranceValue)
  }

  NSpinBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.nvibrant.display-index-label")
    description: I18n.tr("bar.nvibrant.display-index-description")
    from: 1
    to: 8
    stepSize: 1
    value: root.valueDisplayIndex
    defaultValue: widgetMetadata.displayIndex
    onValueChanged: {
      root.valueDisplayIndex = value;
      root.saveSettings();
    }
  }
}
