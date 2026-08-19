import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.Media
DashboardCard {
  id: audioDetailsCard

  styleKey: "systemControls"
  styleRoot: true
  detailTransition: true
  detailTransitionDirection: "right"
  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIconButton {
        icon: "chevron-left"
        baseSize: Math.round(30 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("back")
        onClicked: panelRoot.activeDetailView = ""
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("audio")
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Color.mOnSurface
        elide: Text.ElideRight
      }

      NText {
        text: panelRoot.tr("live")
        pointSize: Style.fontSizeS
        font.family: Settings.data.ui.fontFixed
        color: Color.mPrimary
      }
    }

    DashboardCard {
      panelRoot: audioDetailsCard.panelRoot
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(150 * panelRoot.panelUnit)
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        ControlSlider {
          panelRoot: audioDetailsCard.panelRoot
          iconName: AudioService.muted ? "volume-off" : "volume"
          labelText: panelRoot.tr("outputVolume")
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
          panelRoot: audioDetailsCard.panelRoot
          iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
          labelText: panelRoot.tr("inputVolume")
          valueText: Math.round(AudioService.inputVolume * 100) + "%"
          value: AudioService.inputVolume
          reactiveEffect: panelRoot.microphoneSliderEffect
          reactiveActive: panelRoot.microphoneSignalActive
          reactiveLevel: panelRoot.microphoneSignalLevel
          reactiveValues: panelRoot.microphoneSpectrumValues
          enabled: AudioService.hasInput || AudioService.wpctlAvailable
          onMoved: value => AudioService.setInputVolume(value)
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      AudioDeviceTile {
        panelRoot: audioDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("outputDevice")
        valueText: panelRoot.nodeLabel(AudioService.sink)
        iconName: AudioService.muted ? "volume-off" : "volume"
        muted: AudioService.muted
        devices: panelRoot.audioDeviceOptions(AudioService.sinks)
        currentDeviceKey: panelRoot.nodeKey(AudioService.sink)
        onToggleMuted: AudioService.setOutputMuted(!AudioService.muted)
        onDeviceSelected: key => {
                            const node = panelRoot.audioNodeByKey(AudioService.sinks, key);
                            if (node)
                            AudioService.setAudioSink(node);
                          }
      }

      AudioDeviceTile {
        panelRoot: audioDetailsCard.panelRoot
        Layout.fillWidth: true
        titleText: panelRoot.tr("inputDevice")
        valueText: panelRoot.nodeLabel(AudioService.source)
        iconName: AudioService.inputMuted ? "microphone-off" : "microphone"
        muted: AudioService.inputMuted
        devices: panelRoot.audioDeviceOptions(AudioService.sources)
        currentDeviceKey: panelRoot.nodeKey(AudioService.source)
        onToggleMuted: AudioService.setInputMuted(!AudioService.inputMuted)
        onDeviceSelected: key => {
                            const node = panelRoot.audioNodeByKey(AudioService.sources, key);
                            if (node)
                            AudioService.setAudioSource(node);
                          }
      }
    }

    DashboardCard {
      panelRoot: audioDetailsCard.panelRoot
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: panelRoot.m3SurfaceContainerHigh
      radius: Style.radiusS

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            text: panelRoot.tr("applicationVolumes")
            color: Color.mOnSurface
            font.weight: Style.fontWeightSemiBold
          }

          NText {
            text: AudioService.appStreams.length
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
          }
        }

        NText {
          visible: AudioService.appStreams.length === 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          text: panelRoot.tr("noApplications")
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Flickable {
          visible: AudioService.appStreams.length > 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: appStreamsColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          ColumnLayout {
            id: appStreamsColumn
            width: parent.width
            spacing: Style.marginS

            Repeater {
              model: AudioService.appStreams

              AppVolumeRow {
                panelRoot: audioDetailsCard.panelRoot
                Layout.fillWidth: true
                streamNode: modelData
              }
            }
          }
        }
      }
    }
  }
}
