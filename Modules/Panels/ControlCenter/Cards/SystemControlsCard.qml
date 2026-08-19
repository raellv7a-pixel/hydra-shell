import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
import qs.Services.Hardware
DashboardCard {
  id: systemControlsCard

  styleKey: "systemControls"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "left"
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginL

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("system")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: panelRoot.componentText("systemControls", true)
        elide: Text.ElideRight
      }

      SubmoduleButton {
        panelRoot: systemControlsCard.panelRoot
        targetView: "audio"
        tooltipText: panelRoot.tr("audioDetails")
      }
    }

    ControlSlider {
      panelRoot: systemControlsCard.panelRoot
      iconName: AudioService.muted ? "volume-off" : "volume"
      labelText: panelRoot.tr("volume")
      valueText: Math.round(AudioService.volume * 100) + "%"
      value: AudioService.volume
      reactiveEffect: panelRoot.audioSliderEffect
      reactiveActive: panelRoot.musicActive
      reactiveLevel: panelRoot.musicActive ? panelRoot.spectrumAverage() : 0
      reactiveValues: SpectrumService.values
      reactiveOverflow: true
      enabled: AudioService.sink !== null || AudioService.wpctlAvailable
      onMoved: value => AudioService.setVolume(value)
    }

    ControlSlider {
      panelRoot: systemControlsCard.panelRoot
      iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
      labelText: panelRoot.tr("microphone")
      valueText: Math.round(AudioService.inputVolume * 100) + "%"
      value: AudioService.inputVolume
      reactiveEffect: panelRoot.microphoneSliderEffect
      reactiveActive: panelRoot.microphoneSignalActive
      reactiveLevel: panelRoot.microphoneSignalLevel
      reactiveValues: panelRoot.microphoneSpectrumValues
      enabled: AudioService.hasInput || AudioService.wpctlAvailable
      onMoved: value => AudioService.setInputVolume(value)
    }

    ControlSlider {
      panelRoot: systemControlsCard.panelRoot
      iconName: "brightness-up"
      labelText: panelRoot.tr("brightness")
      valueText: Math.round(panelRoot.currentBrightness() * 100) + "%"
      value: panelRoot.currentBrightness()
      enabled: BrightnessService.monitors.length > 0
      onMoved: value => BrightnessService.setBrightness(value)
    }

    Item {
      Layout.fillHeight: true
    }
  }

  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: panelRoot.activeDetailView = "audio"
  }
}
