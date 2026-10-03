import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../../../Helpers/AudioStreamMetadata.js" as StreamMetadata
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Media
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(420 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    // Volume state (lazy-loaded with panelContent)
    property real localOutputVolume: AudioService.volume || 0
    property bool localOutputVolumeChanging: false
    property int lastSinkId: -1

    property real localInputVolume: AudioService.inputVolume || 0
    property bool localInputVolumeChanging: false
    property int lastSourceId: -1

    readonly property bool outputVolumeGuard: outputVolumeSlider.sliderActive || localOutputVolumeChanging
    readonly property bool inputVolumeGuard: inputVolumeSlider.sliderActive || localInputVolumeChanging

    // UI state (lazy-loaded with panelContent)
    property int currentTabIndex: 0

    Component.onCompleted: {
      var vol = AudioService.volume;
      localOutputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
      var inputVol = AudioService.inputVolume;
      localInputVolume = (inputVol !== undefined && !isNaN(inputVol)) ? inputVol : 0;
      if (AudioService.sink) {
        lastSinkId = AudioService.sink.id;
      }
      if (AudioService.source) {
        lastSourceId = AudioService.source.id;
      }
    }

    // Reset local volume when device changes - use current device's volume
    Connections {
      target: AudioService
      function onSinkChanged() {
        if (AudioService.sink) {
          const newSinkId = AudioService.sink.id;
          if (newSinkId !== panelContent.lastSinkId) {
            panelContent.lastSinkId = newSinkId;
            // Immediately set local volume to current device's volume
            var vol = AudioService.volume;
            panelContent.localOutputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
          }
        } else {
          panelContent.lastSinkId = -1;
          panelContent.localOutputVolume = 0;
        }
      }
    }

    Connections {
      target: AudioService
      function onSourceChanged() {
        if (AudioService.source) {
          const newSourceId = AudioService.source.id;
          if (newSourceId !== panelContent.lastSourceId) {
            panelContent.lastSourceId = newSourceId;
            // Immediately set local volume to current device's volume
            var vol = AudioService.inputVolume;
            panelContent.localInputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
          }
        } else {
          panelContent.lastSourceId = -1;
          panelContent.localInputVolume = 0;
        }
      }
    }

    // Connections to update local volumes when AudioService changes
    Connections {
      target: AudioService
      function onVolumeChanged() {
        if (!panelContent.outputVolumeGuard && !AudioService.isSettingOutputVolume && AudioService.sink && AudioService.sink.id === panelContent.lastSinkId) {
          var vol = AudioService.volume;
          panelContent.localOutputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
        }
      }
    }

    Connections {
      target: AudioService
      function onInputVolumeChanged() {
        if (!panelContent.inputVolumeGuard && !AudioService.isSettingInputVolume && AudioService.source && AudioService.source.id === panelContent.lastSourceId) {
          var vol = AudioService.inputVolume;
          panelContent.localInputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
        }
      }
    }

    Connections {
      target: outputVolumeSlider
      function onSliderActiveChanged() {
        if (!outputVolumeSlider.sliderActive && AudioService.sink && AudioService.sink.id === panelContent.lastSinkId) {
          var vol = AudioService.volume;
          panelContent.localOutputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
        }
      }
    }

    Connections {
      target: inputVolumeSlider
      function onSliderActiveChanged() {
        if (!inputVolumeSlider.sliderActive && AudioService.source && AudioService.source.id === panelContent.lastSourceId) {
          var vol = AudioService.inputVolume;
          panelContent.localInputVolume = (vol !== undefined && !isNaN(vol)) ? vol : 0;
        }
      }
    }

    // Timer to debounce volume changes
    // Only sync if the device hasn't changed (check by comparing IDs)
    Timer {
      interval: 100
      running: true
      repeat: true
      onTriggered: {
        // Only sync if sink hasn't changed
        if (AudioService.sink && AudioService.sink.id === panelContent.lastSinkId) {
          if (Math.abs(panelContent.localOutputVolume - AudioService.volume) >= 0.01) {
            AudioService.setVolume(panelContent.localOutputVolume);
          }
        }
        // Only sync if source hasn't changed
        if (AudioService.source && AudioService.source.id === panelContent.lastSourceId) {
          if (Math.abs(panelContent.localInputVolume - AudioService.inputVolume) >= 0.01) {
            AudioService.setInputVolume(panelContent.localInputVolume);
          }
        }
      }
    }

    // Find application streams that are actually playing audio (connected to default sink)
    // Use linkGroups to find nodes connected to the default audio sink
    // Note: We need to use link IDs since source/target properties require binding
    readonly property var appStreams: AudioService.appStreams

    // Use implicitHeight from content + margins to avoid binding loops
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // HEADER
      NBox {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + Style.margin2M

        ColumnLayout {
          id: header
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            NIcon {
              icon: "settings-audio"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("panels.audio.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("common.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                root.close();
              }
            }
          }

          NTabBar {
            id: tabBar
            Layout.fillWidth: true
            margins: Style.marginS
            currentIndex: panelContent.currentTabIndex
            distributeEvenly: true
            onCurrentIndexChanged: panelContent.currentTabIndex = currentIndex

            NTabButton {
              text: I18n.tr("common.volumes")
              tabIndex: 0
              checked: tabBar.currentIndex === 0
            }

            NTabButton {
              text: I18n.tr("common.devices")
              tabIndex: 1
              checked: tabBar.currentIndex === 1
            }
          }
        }
      }

      // Content Stack
      StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: panelContent.currentTabIndex

        // Applications Tab (Volume)
        NScrollView {
          id: volumeScrollView
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          contentWidth: availableWidth
          reserveScrollbarSpace: false
          gradientColor: Color.mSurface

          ColumnLayout {
            spacing: Style.marginM
            width: volumeScrollView.availableWidth

            // Output Volume
            NBox {
              Layout.fillWidth: true
              Layout.preferredHeight: outputVolumeColumn.implicitHeight + Style.margin2M

              ColumnLayout {
                id: outputVolumeColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.marginM
                spacing: Style.marginM

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: I18n.tr("common.output")
                    pointSize: Style.fontSizeM
                    color: Color.mPrimary
                  }

                  NText {
                    text: AudioService.sink ? (" - " + (AudioService.sink.description || AudioService.sink.name || "")) : ""
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginM

                  NValueSlider {
                    id: outputVolumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
                    value: localOutputVolume
                    stepSize: 0.01
                    heightRatio: 0.5
                    onMoved: function (value) {
                      localOutputVolume = value;
                    }
                    onPressedChanged: function (pressed) {
                      localOutputVolumeChanging = pressed;
                    }
                  }

                  NText {
                    text: Math.round((panelContent.outputVolumeGuard ? localOutputVolume : AudioService.volume) * 100) + "%"
                    pointSize: Style.fontSizeM
                    family: Settings.data.ui.fontFixed
                    color: Color.mOnSurface
                    opacity: enabled ? 1.0 : 0.6
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 45 * Style.uiScaleRatio
                    horizontalAlignment: Text.AlignRight
                  }

                  NIconButton {
                    icon: AudioService.getOutputIcon()
                    tooltipText: I18n.tr("tooltips.output-muted")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: {
                      AudioService.suppressOutputOSD();
                      AudioService.setOutputMuted(!AudioService.muted);
                    }
                  }
                }
              }
            }

            // Input Volume
            NBox {
              Layout.fillWidth: true
              Layout.preferredHeight: inputVolumeColumn.implicitHeight + Style.margin2M

              ColumnLayout {
                id: inputVolumeColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.marginM
                spacing: Style.marginM

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: I18n.tr("common.input")
                    pointSize: Style.fontSizeM
                    color: Color.mPrimary
                  }

                  NText {
                    text: AudioService.source ? (" - " + (AudioService.source.description || AudioService.source.name || "")) : ""
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginM

                  NValueSlider {
                    id: inputVolumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
                    value: localInputVolume
                    stepSize: 0.01
                    heightRatio: 0.5
                    onMoved: function (value) {
                      localInputVolume = value;
                    }
                    onPressedChanged: function (pressed) {
                      localInputVolumeChanging = pressed;
                    }
                  }

                  NText {
                    text: Math.round((panelContent.inputVolumeGuard ? localInputVolume : AudioService.inputVolume) * 100) + "%"
                    pointSize: Style.fontSizeM
                    family: Settings.data.ui.fontFixed
                    color: Color.mOnSurface
                    opacity: enabled ? 1.0 : 0.6
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 45 * Style.uiScaleRatio
                    horizontalAlignment: Text.AlignRight
                  }

                  NIconButton {
                    icon: AudioService.getInputIcon()
                    tooltipText: I18n.tr("tooltips.input-muted")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: {
                      AudioService.suppressInputOSD();
                      AudioService.setInputMuted(!AudioService.inputMuted);
                    }
                  }
                }
              }
            }

            // Bind all app stream nodes to access their audio properties
            PwObjectTracker {
              id: appStreamsTracker
              objects: panelContent.appStreams
            }

            Repeater {
              model: panelContent.appStreams

              NBox {
                id: appBox
                required property PwNode modelData
                Layout.fillWidth: true
                Layout.preferredHeight: appRow.implicitHeight + Style.margin2M

                // Track individual node to ensure properties are bound
                PwObjectTracker {
                  objects: modelData ? [modelData] : []
                }

                property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
                property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false


                readonly property string appName: StreamMetadata.name(modelData, ThemeIcons)
                readonly property string appStreamTitle: StreamMetadata.title(modelData, appName)
                readonly property string appIcon: StreamMetadata.icon(modelData, ThemeIcons)

                RowLayout {
                  id: appRow
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginM

                  // App Icon
                  IconImage {
                    id: appIconImage
                    Layout.preferredWidth: Style.baseWidgetSize
                    Layout.preferredHeight: Style.baseWidgetSize
                    source: appBox.appIcon
                    smooth: true
                    asynchronous: true

                    // Fallback icon if image fails to load
                    NIcon {
                      anchors.fill: parent
                      icon: "apps"
                      pointSize: Style.fontSizeXL
                      color: Color.mPrimary
                      visible: appIconImage.status === Image.Error || appIconImage.status === Image.Null || appBox.appIcon === ""
                    }
                  }

                  // App Name and Volume Slider
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                      text: appBox.appName || "Unknown App"
                      pointSize: Style.fontSizeM
                      color: Color.mOnSurface
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    NText {
                      visible: appBox.appStreamTitle !== ""
                      text: appBox.appStreamTitle
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      maximumLineCount: 1
                      Layout.fillWidth: true
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginM

                      NValueSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: Settings.data.audio.volumeOverdrive ? 1.5 : 1.0
                        value: (appBox.appVolume !== undefined) ? appBox.appVolume : 0.0
                        stepSize: 0.01
                        heightRatio: 0.5
                        enabled: !!(appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true)
                        onMoved: function (value) {
                          if (appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true) {
                            appBox.nodeAudio.volume = value;
                            AudioService.setPanelAppStreamVolume(appBox.modelData, value);
                          }
                        }
                      }

                      NText {
                        text: Math.round((appBox.appVolume !== undefined ? appBox.appVolume : 0.0) * 100) + "%"
                        pointSize: Style.fontSizeM
                        family: Settings.data.ui.fontFixed
                        color: Color.mOnSurface
                        opacity: enabled ? 1.0 : 0.6
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 45 * Style.uiScaleRatio
                        horizontalAlignment: Text.AlignRight
                        enabled: !!(appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true)
                      }

                      // Mute Button
                      NIconButton {
                        icon: (appBox.appMuted === true) ? "volume-mute" : "volume-high"
                        tooltipText: (appBox.appMuted === true) ? I18n.tr("tooltips.unmute") : I18n.tr("tooltips.mute")
                        baseSize: Style.baseWidgetSize * 0.7
                        enabled: !!(appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true)
                        onClicked: {
                          if (appBox.nodeAudio && appBox.modelData && appBox.modelData.ready === true) {
                            var newMuted = !appBox.appMuted;
                            appBox.nodeAudio.muted = newMuted;
                            AudioService.setPanelAppStreamMuted(appBox.modelData, newMuted);
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Empty state
            NText {
              visible: panelContent.appStreams.length === 0
              text: I18n.tr("panels.audio.panel-applications-empty")
              pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              Layout.topMargin: Style.marginXL
            }
          }
        }

        // Devices Tab
        NScrollView {
          id: devicesScrollView
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          contentWidth: availableWidth
          reserveScrollbarSpace: false
          gradientColor: Color.mSurface

          // AudioService Devices
          ColumnLayout {
            spacing: Style.marginM
            width: devicesScrollView.availableWidth

            // -------------------------------
            // Output Devices
            ButtonGroup {
              id: sinks
            }

            NBox {
              Layout.fillWidth: true
              Layout.preferredHeight: outputColumn.implicitHeight + Style.margin2M

              ColumnLayout {
                id: outputColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                  text: I18n.tr("panels.audio.devices-output-device-label")
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
                }

                Repeater {
                  model: AudioService.sinks
                  NRadioButton {
                    ButtonGroup.group: sinks
                    required property PwNode modelData
                    pointSize: Style.fontSizeS
                    text: modelData.description
                    checked: AudioService.sink?.id === modelData.id
                    onClicked: {
                      AudioService.setAudioSink(modelData);
                      localOutputVolume = AudioService.volume;
                    }
                    Layout.fillWidth: true
                  }
                }
              }
            }

            // -------------------------------
            // Input Devices
            ButtonGroup {
              id: sources
            }

            NBox {
              Layout.fillWidth: true
              Layout.preferredHeight: inputColumn.implicitHeight + Style.margin2M

              ColumnLayout {
                id: inputColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                  text: I18n.tr("panels.audio.devices-input-device-label")
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
                }

                Repeater {
                  model: AudioService.sources
                  NRadioButton {
                    ButtonGroup.group: sources
                    required property PwNode modelData
                    pointSize: Style.fontSizeS
                    text: modelData.description
                    checked: AudioService.source?.id === modelData.id
                    onClicked: AudioService.setAudioSource(modelData)
                    Layout.fillWidth: true
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
