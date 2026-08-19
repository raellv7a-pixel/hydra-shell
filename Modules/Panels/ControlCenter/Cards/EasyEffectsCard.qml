import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Io
DashboardCard {
  id: easyEffectsCard

  Layout.fillWidth: true
  Layout.preferredHeight: easyEffectsLayout.implicitHeight + Style.marginM * 2
  color: panelRoot.m3SurfaceContainerHigh
  radius: Style.radiusS
  clip: true

  ColumnLayout {
    id: easyEffectsLayout
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "adjustments-horizontal"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }

      NText {
        Layout.fillWidth: true
        text: panelRoot.tr("easyEffects")
        color: Color.mOnSurface
        font.weight: Style.fontWeightSemiBold
        elide: Text.ElideRight
      }

      NIconButton {
        icon: "refresh"
        baseSize: Math.round(28 * panelRoot.panelUnit)
        tooltipText: panelRoot.tr("refresh")
        onClicked: panelRoot.refreshEasyEffects()
        colorBg: Qt.alpha(Color.mSurfaceVariant, 0.4)
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(54 * panelRoot.panelUnit)
      color: Qt.alpha(Color.mSurfaceVariant, 0.3)
      radius: Style.radiusS

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Math.round(6 * panelRoot.panelUnit)

        Repeater {
          model: 10
          Item {
            id: eqBand
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real bandLevel: panelRoot.equalizerBandLevel(index, 10)
            readonly property real barW: Math.max(4, Math.round(7 * panelRoot.panelUnit))
            readonly property color barColor: bandLevel > 0.72 ? Color.mTertiary : (bandLevel > 0.4 ? Color.mSecondary : Color.mPrimary)
            property real peakLevel: 0

            onBandLevelChanged: eqBand.peakLevel = Math.max(eqBand.peakLevel, eqBand.bandLevel)

            // Peak decays on the shared 50ms effect timer; snaps up instantly, falls slowly (VU-meter behavior)
            Connections {
              target: panelRoot
              function onSliderEffectPhaseChanged() {
                eqBand.peakLevel = Math.max(eqBand.bandLevel, eqBand.peakLevel - 0.035);
              }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: eqBand.barW
              height: Math.max(Math.round(6 * panelRoot.panelUnit), parent.height * eqBand.bandLevel)
              radius: width / 2
              color: eqBand.barColor
              opacity: panelRoot.musicActive ? 0.86 : 0.42

              Behavior on height {
                NumberAnimation {
                  duration: 90
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on color {
                ColorAnimation {
                  duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationNormal
                }
              }
              Behavior on opacity {
                NumberAnimation {
                  duration: panelRoot.dashboardPerformanceMode ? 0 : Style.animationFast
                }
              }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: parent.height - Math.max(Math.round(6 * panelRoot.panelUnit), parent.height * eqBand.peakLevel) - height
              width: eqBand.barW
              height: Math.max(2, Math.round(2 * panelRoot.panelUnit))
              radius: height / 2
              color: Color.mTertiary
              visible: panelRoot.musicActive && !panelRoot.dashboardPerformanceMode
              opacity: 0.85

              Behavior on y {
                NumberAnimation {
                  duration: 90
                  easing.type: Easing.OutCubic
                }
              }
            }
          }
        }
      }
    }

    NButton {
      id: presetButton
      Layout.fillWidth: true
      implicitHeight: Math.round(36 * panelRoot.panelUnit)
      visible: panelRoot.easyEffectsPresets.length > 0
      text: panelRoot.activeEasyEffectsPreset !== "" ? panelRoot.activeEasyEffectsPreset : panelRoot.tr("easyEffectsPreset")
      icon: "chevron-down"
      fontSize: Style.fontSizeS
      horizontalAlignment: Qt.AlignLeft
      backgroundColor: Qt.alpha(Color.mSurfaceVariant, 0.5)
      textColor: Color.mOnSurface
      onClicked: {
        var items = [];
        for (var i = 0; i < panelRoot.easyEffectsPresets.length; i++) {
          items.push({
                       "label": panelRoot.easyEffectsPresets[i],
                       "action": panelRoot.easyEffectsPresets[i],
                       "icon": panelRoot.activeEasyEffectsPreset === panelRoot.easyEffectsPresets[i] ? "circle-filled" : "circle",
                       "visible": true
                     });
        }
        presetMenu.model = items;
        presetMenu.openAtItem(presetButton, 0, presetButton.height);
      }

      NContextMenu {
        id: presetMenu
        width: presetButton.width
        onTriggered: action => panelRoot.applyEasyEffectsPreset(action)
      }
    }

    NText {
      Layout.fillWidth: true
      visible: panelRoot.easyEffectsPresets.length === 0
      text: panelRoot.easyEffectsStatus !== "" ? panelRoot.easyEffectsStatus : panelRoot.tr("easyEffectsNoPresets")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }
}
