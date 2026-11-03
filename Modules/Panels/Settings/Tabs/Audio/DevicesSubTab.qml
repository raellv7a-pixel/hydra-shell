import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services.Media
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Output Devices
  ButtonGroup {
    id: sinks
  }

  NSettingsSection {
    title: I18n.tr("panels.audio.devices-output-device-label")
    description: I18n.tr("panels.audio.devices-output-device-description")
    icon: "volume"
    NText {
      visible: outputDevices.count === 0
      text: I18n.tr("settings.content.no-audio-devices")
      Layout.fillWidth: true
      color: HydraColor.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    Repeater {
      id: outputDevices
      model: AudioService.sinks
      NRadioButton {
        ButtonGroup.group: sinks
        required property PwNode modelData
        text: modelData.description
        checked: AudioService.sink?.id === modelData.id
        onClicked: {
          AudioService.setAudioSink(modelData);
        }
        Layout.fillWidth: true
      }
    }
  }

  // Input Devices
  ButtonGroup {
    id: sources
  }

  NSettingsSection {
    title: I18n.tr("panels.audio.devices-input-device-label")
    description: I18n.tr("panels.audio.devices-input-device-description")
    icon: "microphone"
    NText {
      visible: inputDevices.count === 0
      text: I18n.tr("settings.content.no-audio-devices")
      Layout.fillWidth: true
      color: HydraColor.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    Repeater {
      id: inputDevices
      model: AudioService.sources
      NRadioButton {
        ButtonGroup.group: sources
        required property PwNode modelData
        text: modelData.description
        checked: AudioService.source?.id === modelData.id
        onClicked: AudioService.setAudioSource(modelData)
        Layout.fillWidth: true
      }
    }
  }
}
