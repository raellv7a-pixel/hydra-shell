import QtQuick
import QtQuick.Layouts
import qs.Commons

// Bounded, deferred material sample; replay never changes global preferences.
ColumnLayout {
  id: root
  Layout.fillWidth: true
  spacing: Style.marginS

  RowLayout {
    Layout.fillWidth: true
    NText {
      Layout.fillWidth: true
      text: I18n.tr("settings.content.shared.appearance-preview")
      pointSize: Style.fontSizeS
      color: HydraColor.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }
    NIconButton {
      icon: "player-play"
      tooltipText: I18n.tr("settings.content.shared.replay-motion")
      enabled: Style.animationNormal > 0
      colorBorder: "transparent"
      activeFocusOnTab: enabled
      Accessible.role: Accessible.Button
      Accessible.name: tooltipText
      Accessible.onPressAction: clicked()
      Keys.onReturnPressed: clicked()
      Keys.onSpacePressed: clicked()
      onClicked: {
        if (sample.status === Loader.Ready && sample.item)
          sample.item.replay();
      }
    }
  }

  Loader {
    id: sample
    Layout.fillWidth: true
    Layout.preferredHeight: 240 * Style.uiScaleRatio
    active: root.visible
    asynchronous: true
    sourceComponent: Item {
      id: illustration
      function replay() {
        if (Style.animationNormal > 0)
          movement.restart();
      }
      clip: true
      Accessible.ignored: true

      Rectangle {
        anchors.fill: parent
        color: HydraColor.mSurfaceContainer
        radius: Style.radiusM
      }
      Rectangle {
        width: parent.width * 0.45
        height: parent.height * 0.7
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: Style.radiusL
        color: HydraColor.mSecondaryContainer
      }
      NDropShadow {
        anchors.fill: surface
        source: surface
        autoPaddingEnabled: true
      }
      NMaterialSurface {
        id: surface
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - Style.margin2XL, 420 * Style.uiScaleRatio))
        height: form.implicitHeight + Style.margin2L
        radius: Style.radiusM
        color: HydraColor.smartAlpha(HydraColor.mSurfaceContainerHigh)
        border.color: Style.boxBorderColor
        border.width: Style.borderS
        transform: Translate {
          id: sampleOffset
        }

        ColumnLayout {
          id: form
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM
          RowLayout {
            Layout.fillWidth: true
            NColorIcon {
              icon: "settings-user-interface"
              size: 24 * Style.uiScaleRatio
            }
            NText {
              text: I18n.tr("panels.user-interface.visual-variant-" + Style.visualVariant)
              Layout.fillWidth: true
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightSemiBold
              wrapMode: Text.WordWrap
            }
          }
          NToggle {
            label: I18n.tr("panels.user-interface.tooltips-label")
            checked: true
          }
          NValueSlider {
            Layout.fillWidth: true
            label: I18n.tr("panels.user-interface.material-lighting-label")
            from: 0
            to: 1
            value: 0.65
            stepSize: 0.01
            text: Math.round(value * 100) + "%"
          }
        }
      }
      ParallelAnimation {
        id: movement
        NumberAnimation {
          target: sampleOffset
          property: "x"
          from: Style.marginXL
          to: 0
          duration: Style.animationNormal
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  NText {
    Layout.fillWidth: true
    text: I18n.tr("settings.content.shared.preview-local-description")
    pointSize: Style.fontSizeXS
    color: HydraColor.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }
}
