import QtQuick
import QtQuick.Layouts
import qs.Commons

// A bounded illustration, not a second set of settings or a live shell panel.
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
        if (sample.item)
          sample.item.replay();
      }
    }
  }

  Loader {
    id: sample
    Layout.fillWidth: true
    Layout.preferredHeight: 150 * Style.uiScaleRatio
    active: root.visible
    sourceComponent: Item {
      id: illustration
      function replay() {
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
      NBox {
        id: surface
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.margin2XL, 360 * Style.uiScaleRatio)
        height: form.implicitHeight + Style.margin2L
        radius: Style.radiusM
        color: HydraColor.mSurfaceContainerHigh
        border.color: Style.boxBorderColor
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
              text: "Hydra"
              Layout.fillWidth: true
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightSemiBold
            }
            Rectangle {
              implicitWidth: 32 * Style.uiScaleRatio
              implicitHeight: 18 * Style.uiScaleRatio
              radius: Math.min(Style.iRadiusS, height / 2)
              color: HydraColor.mPrimary
              Rectangle {
                width: 12 * Style.uiScaleRatio
                height: width
                anchors.right: parent.right
                anchors.rightMargin: 3 * Style.uiScaleRatio
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.min(Style.iRadiusS, height / 2)
                color: HydraColor.mOnPrimary
              }
            }
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8 * Style.uiScaleRatio
            radius: Math.min(Style.iRadiusS, height / 2)
            color: HydraColor.mSurfaceVariant
            Rectangle {
              width: parent.width * 0.55
              height: parent.height
              radius: parent.radius
              color: HydraColor.mPrimary
            }
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
        NumberAnimation {
          target: surface
          property: "opacity"
          from: 0.4
          to: 1
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
