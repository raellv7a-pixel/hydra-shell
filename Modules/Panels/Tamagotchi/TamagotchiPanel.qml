import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(430 * Style.uiScaleRatio)
  preferredHeight: Math.round(570 * Style.uiScaleRatio)
  panelBackgroundColor: Color.mSurface
  panelBorderColor: Qt.alpha(Color.mOutline, 0.28)

  readonly property string stateLabel: I18n.tr("tamagotchi.states." + TamagotchiService.petState)
  property string feedbackText: ""

  function showFeedback(action) {
    feedbackText = I18n.tr("tamagotchi.feedback." + action);
    feedbackTimer.restart();
  }

  Timer {
    id: feedbackTimer
    interval: 2200
    repeat: false
    onTriggered: root.feedbackText = ""
  }

  SoundEffect {
    id: eatSound
    source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Sounds/Tamagotchi/eat.wav")
    volume: Math.max(0, Math.min(1, Settings.data.tamagotchi.volume))
  }

  Connections {
    target: TamagotchiService

    function onInteractionCompleted(action) {
      root.showFeedback(action);
    }
  }

  panelContent: Item {
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M
        color: Color.mSurfaceContainerHigh
        radius: Style.radiusL

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              Layout.fillWidth: true
              text: I18n.tr("tamagotchi.panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              Layout.fillWidth: true
              text: root.stateLabel
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginS

        Repeater {
          model: [
            { "label": I18n.tr("tamagotchi.needs.hunger"), "value": TamagotchiService.hunger, "icon": "tools-kitchen-2" },
            { "label": I18n.tr("tamagotchi.needs.happiness"), "value": TamagotchiService.happiness, "icon": "mood-smile" },
            { "label": I18n.tr("tamagotchi.needs.cleanliness"), "value": TamagotchiService.cleanliness, "icon": "sparkles" },
            { "label": I18n.tr("tamagotchi.needs.energy"), "value": TamagotchiService.energy, "icon": "bolt" }
          ]

          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Style.marginXS

            RowLayout {
              Layout.fillWidth: true

              NIcon {
                icon: modelData.icon
                pointSize: Style.fontSizeM
                color: modelData.value < 20 ? Color.mError : Color.mPrimary
              }

              NText {
                Layout.fillWidth: true
                text: modelData.label
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }

              NText {
                text: Math.round(modelData.value) + "%"
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.max(5, Math.round(6 * Style.uiScaleRatio))
              radius: height / 2
              color: Color.mSurfaceContainerHighest

              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, modelData.value / 100))
                height: parent.height
                radius: parent.radius
                color: modelData.value < 20 ? Color.mError : Color.mPrimary
              }
            }
          }
        }
      }

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceContainer
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PetSprite {
              anchors.centerIn: parent
              spriteSize: Math.min(parent.width, parent.height, Math.round(210 * Style.uiScaleRatio))
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            text: root.feedbackText
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: Color.mPrimary
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginS
        rowSpacing: Style.marginS

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("tamagotchi.actions.feed")
          icon: "tools-kitchen-2"
          enabled: TamagotchiService.initialized && !TamagotchiService.sleeping && TamagotchiService.hunger < 100
          onClicked: {
            if (TamagotchiService.feed())
              eatSound.play();
          }
        }

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("tamagotchi.actions.clean")
          icon: "sparkles"
          enabled: TamagotchiService.initialized && !TamagotchiService.sleeping && TamagotchiService.cleanliness < 100
          onClicked: TamagotchiService.clean()
        }

        NButton {
          Layout.fillWidth: true
          text: I18n.tr("tamagotchi.actions.play")
          icon: "ball-football"
          enabled: TamagotchiService.initialized && !TamagotchiService.sleeping && TamagotchiService.energy >= 8 && TamagotchiService.happiness < 100
          onClicked: TamagotchiService.play()
        }

        NButton {
          Layout.fillWidth: true
          text: TamagotchiService.sleeping ? I18n.tr("tamagotchi.actions.wake") : I18n.tr("tamagotchi.actions.rest")
          icon: TamagotchiService.sleeping ? "sun" : "moon"
          enabled: TamagotchiService.initialized
          onClicked: TamagotchiService.rest()
        }
      }
    }
  }
}
