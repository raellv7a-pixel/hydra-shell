import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  property bool valueShowPercentage: widgetData.showPercentage !== undefined ? widgetData.showPercentage : widgetMetadata.showPercentage

  function saveSettings() {
    const settings = Object.assign({}, widgetData || {});
    settings.showPercentage = valueShowPercentage;
    settingsChanged(settings);
  }

  NToggle {
    label: I18n.tr("bar.tamagotchi.show-percentage-label")
    description: I18n.tr("bar.tamagotchi.show-percentage-description")
    checked: root.valueShowPercentage
    defaultValue: widgetMetadata.showPercentage
    onToggled: checked => {
      root.valueShowPercentage = checked;
      root.saveSettings();
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.tamagotchi.difficulty-label")
    description: I18n.tr("bar.tamagotchi.difficulty-description")
    from: 0
    to: 100
    stepSize: 1
    showReset: true
    value: Settings.data.tamagotchi.difficulty
    defaultValue: 50
    onMoved: value => Settings.data.tamagotchi.difficulty = Math.round(value)
    text: Math.round(Settings.data.tamagotchi.difficulty) + "%"
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("bar.tamagotchi.volume-label")
    description: I18n.tr("bar.tamagotchi.volume-description")
    from: 0
    to: 100
    stepSize: 1
    showReset: true
    value: Settings.data.tamagotchi.volume * 100
    defaultValue: 50
    onMoved: value => Settings.data.tamagotchi.volume = Math.round(value) / 100
    text: Math.round(Settings.data.tamagotchi.volume * 100) + "%"
  }
}
