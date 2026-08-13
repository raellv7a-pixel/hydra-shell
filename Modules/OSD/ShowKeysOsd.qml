import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.System
import qs.Widgets

Variants {
  id: root

  model: Quickshell.screens.filter(screen => !(ShowKeysService.disabledScreens || []).includes(screen.name))

  delegate: Loader {
    required property ShellScreen modelData

    active: ShowKeysService.osdVisible && ShowKeysService.captureEnabled
    asynchronous: false

    sourceComponent: PanelWindow {
      id: overlay

      screen: modelData
      implicitWidth: Math.min(screen.width - 40, keyRow.implicitWidth + Style.margin2L)
      implicitHeight: keyRow.implicitHeight + Style.margin2M
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "hydra-show-keys"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      anchors.top: ShowKeysService.position === "top"
      anchors.bottom: ShowKeysService.position !== "top"
      anchors.left: true
      anchors.right: true
      margins.top: ShowKeysService.position === "top" ? ShowKeysService.marginPx : 0
      margins.bottom: ShowKeysService.position !== "top" ? ShowKeysService.marginPx : 0

      Rectangle {
        anchors.fill: parent
        radius: Style.iRadiusL
        color: ShowKeysService.pillBg
        border.width: Style.borderS
        border.color: Qt.alpha(ShowKeysService.pillColor, 0.6)

        RowLayout {
          id: keyRow
          anchors.centerIn: parent
          spacing: Style.marginS

          Repeater {
            model: ShowKeysService.keyList

            Rectangle {
              required property string modelData

              Layout.preferredHeight: Math.round(34 * Style.uiScaleRatio)
              Layout.preferredWidth: keyLabel.implicitWidth + Style.margin2M
              radius: Style.iRadiusM
              color: ShowKeysService.pillColor

              NText {
                id: keyLabel
                anchors.centerIn: parent
                text: modelData
                pointSize: Style.fontSizeM
                font.family: Settings.data.ui.fontFixed
                font.weight: Style.fontWeightBold
                color: Color.mOnPrimary
              }
            }
          }
        }
      }
    }
  }
}
