import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Widgets

Loader {
  active: Settings.data.umbriel.showSubmapIndicator && CompositorService.activeSubmap !== ""
  sourceComponent: PanelWindow {
    screen: CompositorService.getFocusedScreen()
    color: "transparent"
    implicitWidth: Math.min((screen?.width || 640) - Style.margin2XL, row.implicitWidth + Style.margin2XL)
    implicitHeight: row.implicitHeight + Style.marginL * 2
    anchors {
      top: true
    }
    margins.top: Style.margin2XL + Style.barHeight
    WlrLayershell.namespace: "hydra-submap-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    Rectangle {
      anchors.fill: parent
      radius: Style.radiusL
      color: Color.mSurfaceContainerHigh
      RowLayout {
        id: row
        anchors {
          left: parent.left
          right: parent.right
          verticalCenter: parent.verticalCenter
          margins: Style.marginXL
        }
        spacing: Style.marginM
        NIcon {
          icon: "keyboard"
          color: Color.mPrimary
          pointSize: Style.fontSizeL
        }
        NText {
          text: "Modo: " + CompositorService.activeSubmap
          color: Color.mOnSurface
          font.weight: Style.fontWeightSemiBold
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
      }
    }
  }
}
