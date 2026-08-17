import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  property bool valueHideWhenInactive: widgetData.hideWhenInactive ?? widgetMetadata.hideWhenInactive ?? false
  property bool valueShowElapsed: widgetData.showElapsed ?? widgetMetadata.showElapsed ?? true
  property string valueIconColor: widgetData.iconColor ?? widgetMetadata.iconColor ?? "none"

  readonly property var connectionConfig: Settings.data.obsControl ?? ({
                                                                         manualConfiguration: false,
                                                                         host: "127.0.0.1",
                                                                         port: 4455,
                                                                         password: "",
                                                                         pollInterval: 1500
                                                                       })

  signal settingsChanged(var settings)

  function saveWidgetSettings() {
    const settings = Object.assign({}, widgetData || {});
    settings.hideWhenInactive = valueHideWhenInactive;
    settings.showElapsed = valueShowElapsed;
    settings.iconColor = valueIconColor;
    settingsChanged(settings);
  }

  function updateConnectionSetting(key, value) {
    if (Settings.data.obsControl)
      Settings.data.obsControl[key] = value;
  }

  NText {
    Layout.fillWidth: true
    text: I18n.tr("bar.obs-control.connection-settings")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightSemiBold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.obs-control.manual-configuration-label")
    description: I18n.tr("bar.obs-control.manual-configuration-description")
    checked: root.connectionConfig.manualConfiguration
    defaultValue: false
    onToggled: checked => root.updateConnectionSetting("manualConfiguration", checked)
  }

  NTextInput {
    id: hostInput
    Layout.fillWidth: true
    enabled: root.connectionConfig.manualConfiguration
    label: I18n.tr("bar.obs-control.host-label")
    description: I18n.tr("bar.obs-control.host-description")
    text: root.connectionConfig.host
    placeholderText: "127.0.0.1"
    defaultValue: "127.0.0.1"
    onEditingFinished: root.updateConnectionSetting("host", text.trim())
  }

  NTextInput {
    id: portInput
    Layout.fillWidth: true
    enabled: root.connectionConfig.manualConfiguration
    label: I18n.tr("bar.obs-control.port-label")
    description: I18n.tr("bar.obs-control.port-description")
    text: String(root.connectionConfig.port)
    placeholderText: "4455"
    inputMethodHints: Qt.ImhDigitsOnly
    defaultValue: "4455"
    onEditingFinished: {
      const value = Number(text);
      if (value > 0 && value <= 65535 && Math.floor(value) === value)
        root.updateConnectionSetting("port", value);
      else
        text = String(root.connectionConfig.port);
    }
  }

  NTextInput {
    id: passwordInput
    Layout.fillWidth: true
    enabled: root.connectionConfig.manualConfiguration
    label: I18n.tr("bar.obs-control.password-label")
    description: I18n.tr("bar.obs-control.password-description")
    text: root.connectionConfig.password
    defaultValue: ""
    inputItem.echoMode: TextInput.Password
    onEditingFinished: root.updateConnectionSetting("password", text)
  }

  NSpinBox {
    Layout.fillWidth: true
    label: I18n.tr("bar.obs-control.poll-interval-label")
    description: I18n.tr("bar.obs-control.poll-interval-description")
    from: 750
    to: 10000
    stepSize: 250
    value: root.connectionConfig.pollInterval
    defaultValue: 1500
    onValueChanged: root.updateConnectionSetting("pollInterval", value)
  }

  NText {
    Layout.fillWidth: true
    text: I18n.tr(`bar.obs-control.state-${ObsControlService.effectiveState}`)
    wrapMode: Text.WordWrap
    color: ObsControlService.connected ? Color.mPrimary : Color.mOnSurfaceVariant
  }

  NButton {
    Layout.fillWidth: true
    icon: "refresh"
    text: I18n.tr("bar.obs-control.refresh")
    enabled: !ObsControlService.pollBusy
    onClicked: ObsControlService.refresh()
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.obs-control.hide-inactive-label")
    description: I18n.tr("bar.obs-control.hide-inactive-description")
    checked: root.valueHideWhenInactive
    defaultValue: widgetMetadata.hideWhenInactive
    onToggled: checked => {
                 root.valueHideWhenInactive = checked;
                 root.saveWidgetSettings();
               }
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.obs-control.show-elapsed-label")
    description: I18n.tr("bar.obs-control.show-elapsed-description")
    checked: root.valueShowElapsed
    defaultValue: widgetMetadata.showElapsed
    onToggled: checked => {
                 root.valueShowElapsed = checked;
                 root.saveWidgetSettings();
               }
  }

  NColorChoice {
    Layout.fillWidth: true
    label: I18n.tr("common.select-icon-color")
    currentKey: root.valueIconColor
    defaultValue: widgetMetadata.iconColor
    onSelected: key => {
                  root.valueIconColor = key;
                  root.saveWidgetSettings();
                }
  }
}
